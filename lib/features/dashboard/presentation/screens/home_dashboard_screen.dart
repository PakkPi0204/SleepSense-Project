import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/network/dashboard_mapper.dart';
import '../../../../core/debug/debug_flags.dart';
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
  // เก็บ id ของ critical alert ที่เคยเห็นแล้ว (กันเด้ง banner ซ้ำ)
  final Set<String> _seenCriticalIds = {};
  bool _firstLoad = true;
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoRefresh?.cancel();
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
    final sensorFuture = _safeCall(() => _api.fetchLatestSensor());
    final thresholdsFuture =
        _safeCall(() => _api.fetchThresholds(deviceId: ApiConfig.deviceId));
    final suggestionsFuture = _safeCall(() => _api.fetchPreSleepSuggestions());
    final reportFuture = _safeCall(() => _api.fetchLatestReport());
    final alertsFuture = _safeCall(() => _api.fetchRecentAlerts(limit: 5));

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

    // เช็ค critical alert ใหม่ แล้วเด้ง popup (ข้ามรอบแรกที่เพิ่งเปิดแอป)
    if (alertsResult.value != null) {
      _checkNewCriticalAlerts(alertsResult.value!);
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

  /// ตรวจ critical alert ใหม่ที่ยังไม่เคยเห็น แล้วเด้ง popup
  void _checkNewCriticalAlerts(List<AlertDto> alerts) {
    final criticals = alerts.where((a) => a.level == 'CRITICAL').toList();

    // รอบแรก (เพิ่งเปิดแอป): ปกติแค่จำ id ไว้ ไม่เด้ง — กันเด้งของเก่าทั้งกอง
    // ยกเว้นเปิดโหมดทดสอบไว้ (DebugFlags.alwaysShowCriticalOnLoad) จะเด้งให้ทุกตัวเลย
    if (_firstLoad) {
      _firstLoad = false;
      for (final a in criticals) {
        _seenCriticalIds.add(a.id);
      }
      if (DebugFlags.alwaysShowCriticalOnLoad &&
          criticals.isNotEmpty &&
          mounted) {
        _showCriticalAlertQueue(criticals);
      }
      return;
    }

    // หา critical ที่ยังไม่เคยเห็น
    final newCriticals =
        criticals.where((a) => !_seenCriticalIds.contains(a.id)).toList();

    if (newCriticals.isNotEmpty && mounted) {
      for (final a in newCriticals) {
        _seenCriticalIds.add(a.id);
      }
      _showCriticalAlertQueue(newCriticals);
    }
  }

  /// เด้ง popup แจ้งเตือน critical ทีละอัน (ถ้ามีหลายอันเข้าคิวต่อกัน)
  /// ผู้ใช้ต้องกด "Got it" หรือ "View Room Status" เพื่อปิด — ไม่ปิดเองอัตโนมัติ
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