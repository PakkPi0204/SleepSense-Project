import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import 'report_detail_screen.dart';

/// Morning Reports, one entry per night.
///
/// This used to be the Stats tab. It now lives on its own and is reached by
/// tapping the Morning Report card at the bottom of the dashboard, which frees
/// the Stats tab up for the multi-night Smart Suggestion analysis (STC-04).
///
/// Test Plan reference: STC-03, including TC-03 — the empty state when no
/// overnight data exists.
class MorningReportHistoryScreen extends StatefulWidget {
  const MorningReportHistoryScreen({super.key});

  @override
  State<MorningReportHistoryScreen> createState() =>
      _MorningReportHistoryScreenState();
}

class _MorningReportHistoryScreenState
    extends State<MorningReportHistoryScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<MorningReportDto> _reports = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _api.fetchReportHistory(limit: 30);
      if (!mounted) return;
      setState(() {
        _reports = List.of(reports);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Morning Reports'),
      ),
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'One summary per night · long-press to delete',
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
              child:
                  Icon(Icons.nightlight_round, color: clusterColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatNightDate(r.sleepStart),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Avg ${r.avgTemperature.toStringAsFixed(1)}°C · '
                    '${r.avgCo2.round()} ppm CO₂',
                    style:
                        const TextStyle(color: AppColors.neutral, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const Icon(Icons.chevron_right, color: AppColors.neutral, size: 22),
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
          const Expanded(
            child: Text(
              'Could not load reports — the backend is unreachable\n'
              '(pull to retry)',
              style: TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// STC-03 TC-03: no overnight data in the database.
  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.bedtime_outlined, color: AppColors.neutral, size: 48),
          SizedBox(height: 12),
          Text(
            'No overnight data found.\n'
            'Make sure the device is active while you sleep — a report is '
            'created each time you stop monitoring.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppColors.neutral, fontSize: 14, height: 1.5),
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
        title:
            const Text('Delete report', style: TextStyle(color: AppColors.white)),
        content: Text(
          'Delete the report for ${formatNightDate(r.sleepStart)}?',
          style: const TextStyle(color: AppColors.neutral),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.neutral)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
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
          const SnackBar(content: Text('Report deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Please try again.')),
        );
      }
    }
  }
}

/// "Night of 14 Sep 2026", or a fallback when the timestamp will not parse.
String formatNightDate(String iso) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  try {
    final d = DateTime.parse(iso).toLocal();
    return 'Night of ${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) {
    return 'Date unknown';
  }
}
