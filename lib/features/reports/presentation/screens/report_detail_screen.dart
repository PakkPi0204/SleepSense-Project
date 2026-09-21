import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_models.dart';
import '../../../../shared/utils/text_format.dart';

/// Detail view of one night's Morning Report.
///
/// Test Plan reference: STC-03 TC-01/TC-02 — avg, min and max for each factor
/// plus the notable events detected overnight.
class ReportDetailScreen extends StatelessWidget {
  final MorningReportDto report;

  const ReportDetailScreen({required this.report, super.key});

  @override
  Widget build(BuildContext context) {
    final cluster = report.environmentCluster;
    final clusterColor = cluster == 'GOOD'
        ? AppColors.secondary
        : cluster == 'MODERATE'
            ? AppColors.accent
            : const Color(0xFFE85D5D);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Morning Report'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cluster / overall quality ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.scoreCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: clusterColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Environment Quality',
                        style:
                            TextStyle(color: AppColors.neutral, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        cluster,
                        style: TextStyle(
                          color: clusterColor,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _dateRange(),
                        style: const TextStyle(
                            color: AppColors.neutral, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // ── Warn when the data is patchy (device offline part of the night) ──
                if (report.dataCompleteness < 80) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sensors_off,
                            color: AppColors.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This report covers ${report.dataCompleteness}% of the '
                            'period — the device may have been offline for part of '
                            'the night, so it may not reflect the whole night.',
                            style: const TextStyle(
                                color: AppColors.neutral,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // ── Averages ──
                const Text('Averages through the night',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                _metricGrid([
                  _M('Temperature',
                      '${report.avgTemperature.toStringAsFixed(1)}°C'),
                  _M('Humidity', '${report.avgHumidity.toStringAsFixed(0)}%'),
                  _M('CO₂', '${report.avgCo2.round()} ppm'),
                  _M('PM2.5', '${report.avgPm25.toStringAsFixed(0)} μg/m³'),
                  _M('Light', '${report.avgLight.round()} lux'),
                  _M('Sound', '${report.avgNoise.round()} dB'),
                ]),
                const SizedBox(height: 24),

                // ── Peaks ──
                const Text('Highest readings recorded',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                _metricGrid([
                  _M('Max Temp',
                      '${report.maxTemperature.toStringAsFixed(1)}°C'),
                  _M('Max CO₂', '${report.maxCo2.round()} ppm'),
                  _M('Max PM2.5',
                      '${report.maxPm25.toStringAsFixed(0)} μg/m³'),
                  _M('Max Sound', '${report.maxNoise.round()} dB'),
                ]),
                const SizedBox(height: 24),

                // ── Motion ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          color: AppColors.secondary, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Movement: ${report.motionEventCount} times '
                        '(${report.motionPattern})',
                        style: const TextStyle(
                            color: AppColors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // ── Notable events ──
                if (report.anomalies.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text('Notable events',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  ...report.anomalies.map((a) => _bullet(
                      roundDecimalsInText(a),
                      AppColors.accent,
                      Icons.warning_amber_rounded)),
                ],

                // ── Suggestions ──
                if (report.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text('Suggestions',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  ...report.suggestions.map((s) => _bullet(
                      roundDecimalsInText(s),
                      AppColors.secondary,
                      Icons.lightbulb_outline)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricGrid(List<_M> metrics) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: metrics.map((m) {
        return SizedBox(
          width: (430 - 48 - 14) / 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label,
                    style: const TextStyle(
                        color: AppColors.neutral, fontSize: 13)),
                const SizedBox(height: 6),
                Text(m.value,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bullet(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.white, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }

  String _dateRange() {
    try {
      final s = DateTime.parse(report.sleepStart).toLocal();
      final e = DateTime.parse(report.sleepEnd).toLocal();
      return '${_hhmm(s)} - ${_hhmm(e)}';
    } catch (_) {
      return '';
    }
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _M {
  final String label;
  final String value;
  _M(this.label, this.value);
}
