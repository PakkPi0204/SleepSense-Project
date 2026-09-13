import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/network/sleep_mapper.dart';
import '../../data/sleep_sample_data.dart';
import '../../models/sleep_models.dart';
import '../widgets/environment_checklist.dart';
import '../widgets/sleep_header.dart';
import '../widgets/sleep_monitoring_button.dart';
import '../widgets/sleep_readiness_card.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _connected = false;

  SleepReadiness _readiness = sampleSleepReadiness;
  List<EnvironmentCheckItem> _checklist = sampleEnvironmentChecklist;

  @override
  Timer? _autoRefresh;

  void initState() {
    super.initState();
    _loadData();
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
    if (!silent) setState(() => _loading = true);
    try {
      // ดึง threshold ของผู้ใช้มาด้วยเสมอ (เช่นเดียวกับหน้า Home) เพื่อให้หน้า
      // Sleep ตัดสิน Optimal/Warning ของค่า sensor เดียวกันตรงกับหน้าอื่นๆ ใน
      // แอป แทนที่จะใช้เกณฑ์ hardcode ของตัวเองแยกต่างหาก — ยิงคู่กันแบบไม่พึ่ง
      // กัน ถ้า threshold endpoint พังรอบนี้ SleepMapper จะ fallback เป็นค่า
      // default เอง ไม่ทำให้ sensor reading หายไปด้วย
      final sensorFuture = _api.fetchLatestSensor();
      final thresholdsFuture = _safeThresholds();

      final sensor = await sensorFuture;
      final thresholds = await thresholdsFuture;

      setState(() {
        if (sensor != null) {
          _readiness = SleepMapper.toReadiness(sensor, thresholds: thresholds);
          _checklist = SleepMapper.toChecklist(sensor, thresholds: thresholds);
          _connected = true;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _connected = false;
        _loading = false;
      });
    }
  }

  /// ห่อ fetchThresholds ไม่ให้ error ของ endpoint นี้ไปบล็อก sensor reading —
  /// ถ้าพังรอบนี้ ให้ถือว่าไม่มี threshold ที่ผู้ใช้ปรับเอง (SleepMapper จะใช้
  /// ค่า default แทน) แทนที่จะทำให้ทั้งหน้าล้มเหลวไปด้วย
  Future<ThresholdSettingsDto?> _safeThresholds() async {
    try {
      return await _api.fetchThresholds(deviceId: ApiConfig.deviceId);
    } catch (_) {
      return null;
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
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SleepHeader(),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary),
                        ),
                      ),
                    if (!_connected && !_loading) _offlineBanner(),
                    const SizedBox(height: 16),
                    SleepReadinessCard(readiness: _readiness),
                    const SizedBox(height: 28),
                    EnvironmentChecklist(items: _checklist),
                    const SizedBox(height: 32),
                    SleepMonitoringButton(items: _checklist),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offlineBanner() {
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
              'ยังไม่ได้เชื่อมต่อ backend — กำลังแสดงข้อมูลตัวอย่าง (ดึงลงเพื่อลองใหม่)',
              style: const TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
