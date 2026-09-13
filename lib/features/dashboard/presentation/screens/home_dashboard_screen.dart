import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/network/dashboard_mapper.dart';
import '../../../../core/debug/debug_flags.dart';
import '../../../../core/storage/suggestion_ack_store.dart';
import '../../../../core/events/dashboard_refresh_bus.dart';
import '../../../alerts/presentation/screens/alerts_screen.dart';
import '../../../alerts/presentation/widgets/critical_alert_dialog.dart';
import '../../data/dashboard_sample_data.dart';
import '../../models/dashboard_models.dart';
import '../widgets/environment_score_card.dart';
import '../widgets/morning_report_card.dart';
import '../widgets/pre_sleep_suggestion_card.dart';
import '../widgets/sensor_grid.dart';
import '../widgets/top_header.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final AnimationController _pulseController;

  bool _loading = true;
  String? _error;

  // เริ่มด้วย sample data — ถ้าโหลด API สำเร็จจะถูกแทนที่
  EnvironmentScore _score = sampleEnvironmentScore;
  List<SensorReading> _readings = sampleSensorReadings;
  PreSleepSuggestion _suggestion = samplePreSleepSuggestion;
  MorningReport _report = sampleMorningReport;
  List<AlertDto> _alerts = const [];
  // เก็บ "factor" ของ critical alert ที่เด้ง popup ให้ดูแล้วใน session นี้ —
  // กันไม่ให้เด้งซ้ำทุก 30 วิระหว่างที่ยังเปิดแอปอยู่ (ไม่ persist ข้าม session
  // โดยตั้งใจ: สถานะที่ "persist ข้ามการปิด-เปิดแอป" จริงๆ คือสถานะ acknowledge
  // ใน SuggestionAckStore ที่ผูกกับปุ่มใน dialog แทน)
  final Set<String> _shownThisSessionFactors = {};
  bool _deviceOffline = false;

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadData();
    // auto-refresh ทุก 30 วินาที (ตรงกับ ESP32)
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(silent: true),
    );
    // ฟัง signal จากหน้าอื่น (เช่น กด Stop Monitoring ที่หน้า Sleep แล้วสร้าง
    // morning report ใหม่สำเร็จ) เพื่อโหลดข้อมูลใหม่ทันที ไม่ต้องรอ
    // auto-refresh รอบถัดไป (นานสุด 30 วิ) — จำเป็นเพราะ IndexedStack ทำให้
    // หน้านี้ไม่ถูก dispose/initState ใหม่ตอนสลับแท็บ
    DashboardRefreshBus.instance.listenable.addListener(_onExternalDataChanged);
  }

  void _onExternalDataChanged() {
    _loadData(silent: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoRefresh?.cancel();
    DashboardRefreshBus.instance.listenable
        .removeListener(_onExternalDataChanged);
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    // ยิงแต่ละ endpoint แยกกัน (ไม่ใช้ Future.wait ตรงๆ) — เดิมถ้า endpoint
    // ไหน endpoint หนึ่ง throw (เช่น เน็ตสะดุดตอนดึง alerts พอดี) จะทำให้ทั้งชุด
    // ไม่ถูกอัปเดตเลยแม้ endpoint อื่นจะสำเร็จ รวมถึง sensor/threshold ด้วย —
    // นี่คือสาเหตุที่ dashboard ค้างค่า/threshold เก่า และดูเหมือนต้องปิดเปิด
    // แอปใหม่ถึงจะ "บังเอิญ" เจอรอบที่ทุก endpoint สำเร็จพร้อมกันพอดี ตอนนี้
    // แยกยิงเพื่อให้ endpoint ที่สำเร็จอัปเดตผลได้เสมอ ไม่ขึ้นกับ endpoint อื่น
    // เริ่มยิงทั้ง 5 ตัวพร้อมกัน (ไม่ await ทีละตัว ไม่งั้นจะกลายเป็นยิงเรียง
    // ต่อกันทีละ endpoint ช้าลง 5 เท่า) แล้วค่อย await ผลลัพธ์แต่ละตัวทีหลัง
    // เก็บ future ดิบของ sensor/thresholds ไว้แยกจาก _safeCall เพื่อส่งต่อให้
    // _fetchAlertsForHome ใช้ตอน fallback (ดูคอมเมนต์ด้านล่าง) — เรียก .then/
    // await future ตัวเดิมซ้ำได้โดยไม่ยิง request ซ้ำ
    final rawSensorFuture = _api.fetchLatestSensor();
    final rawThresholdsFuture =
        _api.fetchThresholds(deviceId: ApiConfig.deviceId);

    final sensorFuture = _safeCall(() => rawSensorFuture);
    final thresholdsFuture = _safeCall(() => rawThresholdsFuture);
    final suggestionsFuture = _safeCall(() => _api.fetchPreSleepSuggestions());
    final reportFuture = _safeCall(() => _api.fetchLatestReport());
    // ใช้ /active แทน /recent สำหรับ badge หน้า Home + critical popup — คืน
    // เฉพาะ alert ที่ backend เห็นว่ายัง active อยู่จริง (ยังไม่ resolved) ไม่ใช่
    // ประวัติทั้งหมดที่รวมของเก่าที่ปัญหาหายไปแล้วด้วย ถ้า backend ยังเป็น
    // เวอร์ชันเก่าที่ยังไม่มี endpoint นี้ (ยังไม่ได้ deploy) จะ 404/error แล้ว
    // _fetchAlertsForHome จะ fallback ไปใช้ /recent + กรองเองฝั่ง client แทน
    // โดยอัตโนมัติ ไม่ต้องรอ deploy backend ก็ demo ได้ตามปกติ พอ deploy เสร็จ
    // เมื่อไหร่ก็จะสลับไปใช้ /active ที่แม่นกว่าเองทันทีโดยไม่ต้องแก้โค้ด
    final alertsFuture = _safeCall(
        () => _fetchAlertsForHome(rawSensorFuture, rawThresholdsFuture));

    final sensorResult = await sensorFuture;
    final thresholdsResult = await thresholdsFuture;
    final suggestionsResult = await suggestionsFuture;
    final reportResult = await reportFuture;
    final alertsResult = await alertsFuture;

    if (!mounted) return;

    final allFailed = sensorResult.error != null &&
        thresholdsResult.error != null &&
        suggestionsResult.error != null &&
        reportResult.error != null &&
        alertsResult.error != null;

    // จำ factor ของ suggestion เดิมไว้ก่อน setState ทับค่า — ใช้เช็คว่า
    // สภาพแวดล้อมเพิ่ง "กลับมาปกติ" รอบนี้หรือเปล่า (จากมีปัญหา -> OK)
    final previousSuggestionFactor = _suggestion.factorKey;

    setState(() {
      final sensor = sensorResult.value;
      if (sensor != null) {
        // thresholds อาจเป็น null ถ้า endpoint นี้พังพอดีรอบนี้ — mapper จะ
        // fallback ไปใช้ค่า default เอง ไม่ทำให้ sensor reading หายไปด้วย
        _readings = DashboardMapper.toSensorReadings(sensor,
            thresholds: thresholdsResult.value);
        _score = DashboardMapper.toEnvironmentScore(sensor,
            thresholds: thresholdsResult.value);
        _deviceOffline = DashboardMapper.isStale(sensor.timestamp);
      }
      if (suggestionsResult.value != null) {
        _suggestion = DashboardMapper.toPreSleepSuggestion(suggestionsResult.value!);
      }
      if (reportResult.value != null) {
        _report = DashboardMapper.toMorningReport(reportResult.value!);
      }
      if (alertsResult.value != null) {
        _alerts = alertsResult.value!;
      }
      // โชว์ error banner ก็ต่อเมื่อทุก endpoint พังพร้อมกัน (backend ล่ม/ไม่ได้
      // เชื่อมต่อจริงๆ) ถ้ามีอย่างน้อย 1 endpoint สำเร็จ ถือว่าอัปเดตได้ปกติ
      _error = allFailed
          ? (sensorResult.error ?? thresholdsResult.error ?? 'เชื่อมต่อ backend ไม่ได้')
          : null;
      _loading = false;
    });

    // สภาพแวดล้อมเพิ่งกลับมาปกติรอบนี้ (จากมีปัญหา -> OK) — เคลียร์สถานะ
    // "จัดการแล้ว" ที่เคยบันทึกไว้ทั้งหมด เพื่อให้รอบหน้าที่ปัญหาเดิมเกิดซ้ำ
    // ปุ่ม/popup จะกลับมาเตือนใหม่ตามปกติ แทนที่จะค้างสถานะ "เปิดแล้ว" ไปตลอด
    if (previousSuggestionFactor != 'OK' && _suggestion.factorKey == 'OK') {
      SuggestionAckStore.instance.clearAll();
    }

    // เช็ค critical alert ที่ยังไม่เคยถูก "รับทราบว่าจัดการแล้ว" แล้วบังคับเด้ง
    // popup ให้ทุกครั้ง (รวมถึงตอนเพิ่งเปิดแอปใหม่ด้วย) — จะไม่เด้งซ้ำก็ต่อเมื่อ
    // ผู้ใช้เคยกดปุ่ม action ใน dialog มาก่อนแล้วเท่านั้น (persist ข้ามการปิด-
    // เปิดแอป ผ่าน SuggestionAckStore) ไม่ใช่แค่เคยเห็นแอปแล้วรอบหนึ่ง
    if (alertsResult.value != null) {
      await _checkCriticalAlerts(
        alertsResult.value!,
        sensor: sensorResult.value,
        thresholds: thresholdsResult.value,
      );
    }
  }

  /// ห่อ future ทีละตัวไม่ให้ error ของ endpoint หนึ่งไปบล็อกผลของ endpoint อื่น
  Future<_Result<T>> _safeCall<T>(Future<T> Function() call) async {
    try {
      return _Result<T>(value: await call());
    } catch (e) {
      return _Result<T>(error: e.toString());
    }
  }

  /// ดึง alert สำหรับหน้า Home — ลอง endpoint /active (backend เวอร์ชันใหม่)
  /// ก่อน ถ้าพัง (404/error เพราะ backend ยังเป็นเวอร์ชันเก่าที่ยังไม่ได้
  /// deploy โค้ด resolved) จะ fallback ไปดึง /recent (ประวัติทั้งหมด) มาแทน
  /// แล้วกรองเองฝั่ง client: เอาแค่แถวล่าสุดของแต่ละ factor (recent เรียงใหม่
  /// สุดก่อนอยู่แล้ว) แล้วเช็คว่ายังจริงอยู่ไหมกับ sensor/threshold ปัจจุบัน —
  /// ให้ demo/ใช้งานได้ตามปกติแม้ backend ยังไม่ได้ redeploy
  Future<List<AlertDto>> _fetchAlertsForHome(
    Future<SensorDataDto?> sensorFuture,
    Future<ThresholdSettingsDto> thresholdsFuture,
  ) async {
    try {
      return await _api.fetchActiveAlerts();
    } catch (_) {
      List<AlertDto> recent;
      try {
        recent = await _api.fetchRecentAlerts(limit: 20);
      } catch (_) {
        return const [];
      }

      SensorDataDto? sensor;
      ThresholdSettingsDto? thresholds;
      try {
        sensor = await sensorFuture;
      } catch (_) {
        sensor = null;
      }
      try {
        thresholds = await thresholdsFuture;
      } catch (_) {
        thresholds = null;
      }

      final seenFactors = <String>{};
      final result = <AlertDto>[];
      for (final a in recent) {
        final key = a.factor.toUpperCase();
        if (seenFactors.contains(key)) {
          continue; // เอาแค่แถวล่าสุดของแต่ละ factor
        }
        seenFactors.add(key);
        if (sensor != null &&
            !DashboardMapper.isFactorStillFlagged(a.factor, a.level, sensor,
                thresholds: thresholds)) {
          continue;
        }
        result.add(a);
      }
      return result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.secondary,
              backgroundColor: AppColors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TopHeader(),
                    const SizedBox(height: 20),
                    if (_loading) _buildLoading(),
                    if (_error != null && !_loading) _buildErrorBanner(),
                    if (_error == null && _deviceOffline && !_loading)
                      _buildOfflineBanner(),
                    const SizedBox(height: 16),
                    EnvironmentScoreCard(score: _score),
                    const SizedBox(height: 28),
                    SensorGrid(readings: _readings),
                    const SizedBox(height: 28),
                    PreSleepSuggestionCard(suggestion: _suggestion),
                    const SizedBox(height: 24),
                    _alertsSection(),
                    const SizedBox(height: 24),
                    MorningReportCard(report: _report),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ตรวจ critical alert ทุกตัวที่ยังไม่ถูก "รับทราบว่าจัดการแล้ว" (ผูกกับ
  /// factor เดิม ไม่ใช่ alert.id ที่เปลี่ยนใหม่ทุกรอบ sensor อัปเดต) แล้วบังคับ
  /// เด้ง popup — ทำงานทุกครั้งที่โหลดข้อมูล รวมถึงตอนเพิ่งเปิดแอปใหม่ด้วย
  ///
  /// [sensor]/[thresholds] คือค่า "ปัจจุบัน" ของรอบโหลดนี้ — ใช้เช็คซ้ำว่า
  /// alert แต่ละแถวยังวิกฤตอยู่จริงไหมก่อนบังคับเด้ง เพราะ backend เก็บ alert
  /// เป็น log ประวัติศาสตร์ล้วนๆ ไม่มีสถานะ resolved/active (ดู
  /// AlertRepository.findRecentByDevice ฝั่ง backend) ถ้าผู้ใช้เพิ่งปรับ
  /// threshold ให้กว้างขึ้น แถวเก่าที่เคยวิกฤตภายใต้ threshold เดิมก็จะยังโผล่
  /// มาใน "recent alerts" อยู่ดี ทั้งที่ค่าปัจจุบันไม่วิกฤตแล้ว
  Future<void> _checkCriticalAlerts(
    List<AlertDto> alerts, {
    required SensorDataDto? sensor,
    required ThresholdSettingsDto? thresholds,
  }) async {
    final criticals = alerts.where((a) => a.level == 'CRITICAL').toList();
    if (criticals.isEmpty) return;

    final toShow = <AlertDto>[];
    for (final a in criticals) {
      // ถ้ามีค่า sensor ของรอบนี้ ให้เช็คซ้ำกับ threshold ปัจจุบันก่อน — ถ้า
      // ไม่วิกฤตแล้ว (เช่น ผู้ใช้เพิ่งปรับ threshold ให้กว้างขึ้น) ข้ามแถวนี้ไป
      // เลย ไม่ต้องบังคับเด้ง popup ของปัญหาที่ไม่ใช่ปัญหาอีกต่อไป ถ้าไม่มีค่า
      // sensor รอบนี้ (endpoint พังพอดี) ให้เชื่อ backend ไปก่อนเหมือนเดิม
      if (sensor != null &&
          !DashboardMapper.isFactorCritical(a.factor, sensor,
              thresholds: thresholds)) {
        continue;
      }

      final factorKey = 'CRITICAL_${a.factor.toUpperCase()}';
      // เด้งซ้ำได้ตามโหมดทดสอบเสมอ ไม่งั้นเช็คสถานะ acknowledge ที่ persist ไว้
      final forceDebug = DebugFlags.alwaysShowCriticalOnLoad;
      final alreadyAcked =
          !forceDebug && await SuggestionAckStore.instance.isAcknowledged(factorKey);
      final alreadyShownThisSession =
          !forceDebug && _shownThisSessionFactors.contains(factorKey);
      if (!alreadyAcked && !alreadyShownThisSession) {
        toShow.add(a);
        _shownThisSessionFactors.add(factorKey);
      }
    }

    if (toShow.isNotEmpty && mounted) {
      _showCriticalAlertQueue(toShow);
    }
  }

  /// เด้ง popup แจ้งเตือน critical ทีละอัน (ถ้ามีหลายอันเข้าคิวต่อกัน)
  /// ผู้ใช้ต้องกดปุ่มใดปุ่มหนึ่งใน dialog เพื่อปิด — ไม่ปิดเองอัตโนมัติ (บังคับ
  /// ให้เห็นจริงๆ ก่อนจะกลับไปใช้แอปต่อได้)
  Future<void> _showCriticalAlertQueue(List<AlertDto> alerts) async {
    for (final alert in alerts) {
      if (!mounted) return;
      HapticFeedback.heavyImpact(); // สั่นแจ้งเตือน (บนมือถือ)
      await CriticalAlertDialog.show(
        context,
        alert,
        onViewRoomStatus: () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlertsScreen()),
          );
        },
      );
    }
  }

  Widget _alertsSection() {
    final criticalCount =
        _alerts.where((a) => a.level == 'CRITICAL').length;
    final hasAlerts = _alerts.isNotEmpty;
    const criticalColor = Color(0xFFE85D5D);
    final accentColor =
        criticalCount > 0 ? criticalColor : AppColors.accent;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AlertsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          // มี critical: เติมพื้นหลังสีแดงจางๆ ทั้งการ์ดให้เด่นชัดกว่าแค่กรอบ
          color: criticalCount > 0
              ? criticalColor.withOpacity(0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAlerts ? accentColor : AppColors.cardBorder,
            width: criticalCount > 0 ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasAlerts
                    ? accentColor.withOpacity(0.15)
                    : AppColors.iconBox,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasAlerts
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                color: hasAlerts ? accentColor : AppColors.neutral,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Alerts',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (criticalCount > 0) ...[
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final opacity =
                                0.4 + (_pulseController.value * 0.6);
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: criticalColor.withOpacity(opacity),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        criticalColor.withOpacity(opacity * 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAlerts
                        ? 'มี ${_alerts.length} การแจ้งเตือน'
                            '${criticalCount > 0 ? ' ($criticalCount วิกฤต)' : ''}'
                        : 'ไม่มีการแจ้งเตือน',
                    style: TextStyle(
                      color: criticalCount > 0
                          ? criticalColor
                          : AppColors.neutral,
                      fontSize: 13,
                      fontWeight:
                          criticalCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.neutral, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors_off, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'อุปกรณ์อาจออฟไลน์ — ไม่ได้รับข้อมูลใหม่เกิน 2 นาที\nค่าที่แสดงอาจไม่ใช่ค่าปัจจุบัน',
              style: const TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ยังไม่ได้เชื่อมต่อ backend — กำลังแสดงข้อมูลตัวอย่าง\n(ดึงลงเพื่อลองใหม่)',
              style: const TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// ผลลัพธ์ของการยิง endpoint หนึ่งตัวแบบ isolated — ใส่ error ไว้แยกจาก value
/// เพื่อไม่ให้ endpoint หนึ่งพังแล้วดึงอีก endpoint ที่สำเร็จตกไปด้วย
class _Result<T> {
  final T? value;
  final String? error;

  _Result({this.value, this.error});
}