import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
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
      final sensor = await _api.fetchLatestSensor();
      setState(() {
        if (sensor != null) {
          _readiness = SleepMapper.toReadiness(sensor);
          _checklist = SleepMapper.toChecklist(sensor);
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
