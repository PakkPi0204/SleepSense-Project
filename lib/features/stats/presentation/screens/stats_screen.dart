import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import 'report_detail_screen.dart';

/// หน้า Stats — ประวัติ Morning Report ย้อนหลังแต่ละคืน
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<MorningReportDto> _reports = const [];

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final reports = await _api.fetchReportHistory(limit: 30);
      setState(() {
        _reports = List.of(reports);
        _loading = false;
      });
    } catch (e) {
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
              onRefresh: _load,
              color: AppColors.secondary,
              backgroundColor: AppColors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep Statistics',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'สถิติสภาพแวดล้อมย้อนหลังแต่ละคืน · แตะค้างเพื่อลบ',
                      style: TextStyle(color: AppColors.neutral, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary),
                        ),
                      ),
                    if (_error != null && !_loading) _errorBox(),
                    if (!_loading && _error == null && _reports.isEmpty)
                      _emptyBox(),
                    if (!_loading && _error == null)
                      ..._reports.map(_reportCard),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reportCard(MorningReportDto r) {
    final cluster = r.environmentCluster;
    final clusterColor = cluster == 'GOOD'
        ? AppColors.secondary
        : cluster == 'MODERATE'
            ? AppColors.accent
            : const Color(0xFFE85D5D);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReportDetailScreen(report: r)),
        );
      },
      onLongPress: () => _confirmDelete(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: clusterColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.nightlight_round, color: clusterColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(r.sleepStart),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Avg ${r.avgTemperature.toStringAsFixed(1)}°C · ${r.avgCo2.round()} ppm CO₂',
                    style: const TextStyle(
                        color: AppColors.neutral, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: clusterColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                cluster,
                style: TextStyle(
                  color: clusterColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: AppColors.neutral, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              'โหลดสถิติไม่ได้ — เชื่อมต่อ backend ไม่สำเร็จ\n(ดึงลงเพื่อลองใหม่)',
              style: const TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.bedtime_outlined, color: AppColors.neutral, size: 48),
          SizedBox(height: 12),
          Text(
            'ยังไม่มีรายงานย้อนหลัง\nรายงานจะสร้างขึ้นหลังการนอนแต่ละคืน',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.neutral, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(MorningReportDto r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('ลบรายงาน',
            style: TextStyle(color: AppColors.white)),
        content: Text(
          'ต้องการลบรายงาน${_formatDate(r.sleepStart)} ใช่ไหม?',
          style: const TextStyle(color: AppColors.neutral),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก',
                style: TextStyle(color: AppColors.neutral)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบ',
                style: TextStyle(color: Color(0xFFE85D5D))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await _api.deleteReport(r.id);
      if (!mounted) return;
      if (ok) {
        setState(() => _reports.removeWhere((x) => x.id == r.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบรายงานแล้ว')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = [
        'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
      ];
      return 'คืนวันที่ ${d.day} ${months[d.month - 1]} ${d.year + 543}';
    } catch (_) {
      return 'ไม่ทราบวันที่';
    }
  }
}
