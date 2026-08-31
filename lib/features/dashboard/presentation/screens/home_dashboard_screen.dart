import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/network/dashboard_mapper.dart';
import '../../../alerts/presentation/screens/alerts_screen.dart';
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

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final ApiService _api = ApiService();

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

  @override
  Timer? _autoRefresh;

  void initState() {
    super.initState();
    _loadData();
    // auto-refresh ทุก 30 วินาที (ตรงกับ ESP32)
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(silent: true),
    );
  }

  @override
  void dispose() {
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

    try {
      // ยิงพร้อมกันทั้ง 3 endpoint
      final results = await Future.wait([
        _api.fetchLatestSensor(),
        _api.fetchPreSleepSuggestions(),
        _api.fetchLatestReport(),
        _api.fetchRecentAlerts(limit: 5),
      ]);

      final sensor = results[0] as dynamic;
      final suggestions = results[1] as List<String>;
      final report = results[2] as dynamic;
      final alerts = results[3] as List<AlertDto>;

      setState(() {
        if (sensor != null) {
          _readings = DashboardMapper.toSensorReadings(sensor);
          _score = DashboardMapper.toEnvironmentScore(sensor);
          _deviceOffline = DashboardMapper.isStale(sensor.timestamp);
        }
        _suggestion = DashboardMapper.toPreSleepSuggestion(suggestions);
        if (report != null) {
          _report = DashboardMapper.toMorningReport(report);
        }
        _alerts = alerts;
        _loading = false;
      });

      // เช็ค critical alert ใหม่ แล้วเด้ง banner (ข้ามรอบแรกที่เพิ่งเปิดแอป)
      _checkNewCriticalAlerts(alerts);
    } catch (e) {
      // ต่อ backend ไม่ได้ → โชว์ sample data ต่อ + แจ้ง error เบาๆ
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  /// ตรวจ critical alert ใหม่ที่ยังไม่เคยเห็น แล้วเด้ง banner
  void _checkNewCriticalAlerts(List<AlertDto> alerts) {
    final criticals = alerts.where((a) => a.level == 'CRITICAL').toList();

    // รอบแรก (เพิ่งเปิดแอป) แค่จำ id ไว้ ไม่เด้ง — กันเด้งของเก่าทั้งกอง
    if (_firstLoad) {
      for (final a in criticals) {
        _seenCriticalIds.add(a.id);
      }
      _firstLoad = false;
      return;
    }

    // หา critical ที่ยังไม่เคยเห็น
    final newCriticals =
        criticals.where((a) => !_seenCriticalIds.contains(a.id)).toList();

    if (newCriticals.isNotEmpty && mounted) {
      for (final a in newCriticals) {
        _seenCriticalIds.add(a.id);
      }
      _showCriticalBanner(newCriticals.first);
    }
  }

  /// เด้ง banner แจ้งเตือน critical (ค้าง 6 วิ + กดปิดได้)
  void _showCriticalBanner(AlertDto alert) {
    HapticFeedback.heavyImpact(); // สั่นแจ้งเตือน (บนมือถือ)
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners(); // เคลียร์ banner เก่าก่อน
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF3A1519),
        leading: const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFE85D5D), size: 28),
        content: Text(
          '⚠️ แจ้งเตือนวิกฤต: ${alert.message}',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('ปิด',
                style: TextStyle(color: Color(0xFFE85D5D))),
          ),
        ],
      ),
    );

    // ปิดเองอัตโนมัติหลัง 6 วิ
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  Widget _alertsSection() {
    final criticalCount =
        _alerts.where((a) => a.level == 'CRITICAL').length;
    final hasAlerts = _alerts.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AlertsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAlerts
                ? (criticalCount > 0
                    ? const Color(0xFFE85D5D)
                    : AppColors.accent)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasAlerts
                    ? (criticalCount > 0
                        ? const Color(0xFFE85D5D)
                        : AppColors.accent)
                        .withOpacity(0.15)
                    : AppColors.iconBox,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasAlerts
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                color: hasAlerts
                    ? (criticalCount > 0
                        ? const Color(0xFFE85D5D)
                        : AppColors.accent)
                    : AppColors.neutral,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alerts',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAlerts
                        ? 'มี ${_alerts.length} การแจ้งเตือน'
                            '${criticalCount > 0 ? ' ($criticalCount วิกฤต)' : ''}'
                        : 'ไม่มีการแจ้งเตือน',
                    style: const TextStyle(
                        color: AppColors.neutral, fontSize: 13),
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
