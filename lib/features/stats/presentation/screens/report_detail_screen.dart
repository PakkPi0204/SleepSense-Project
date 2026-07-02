import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_models.dart';

/// หน้ารายละเอียด Morning Report ของคืนหนึ่ง
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
        title: const Text('รายงานคืนที่ผ่านมา'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cluster / คะแนนรวม ──
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
                        style: TextStyle(
                            color: AppColors.neutral, fontSize: 14),
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
                const SizedBox(height: 28),

                // ── ค่าเฉลี่ย ──
                const Text('ค่าเฉลี่ยตลอดคืน',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                _metricGrid([
                  _M('Temperature', '${report.avgTemperature.toStringAsFixed(1)}°C'),
                  _M('Humidity', '${report.avgHumidity.toStringAsFixed(0)}%'),
                  _M('CO₂', '${report.avgCo2.round()} ppm'),
                  _M('PM2.5', '${report.avgPm25.toStringAsFixed(0)} μg/m³'),
                  _M('Light', '${report.avgLight.round()} lux'),
                  _M('Sound', '${report.avgNoise.round()} dB'),
                ]),
                const SizedBox(height: 24),

                // ── ค่าสูงสุด ──
                const Text('ค่าสูงสุดที่ตรวจพบ',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                _metricGrid([
                  _M('Max Temp', '${report.maxTemperature.toStringAsFixed(1)}°C'),
                  _M('Max CO₂', '${report.maxCo2.round()} ppm'),
                  _M('Max PM2.5', '${report.maxPm25.toStringAsFixed(0)} μg/m³'),
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
                        'การเคลื่อนไหว: ${report.motionEventCount} ครั้ง (${report.motionPattern})',
                        style: const TextStyle(
                            color: AppColors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // ── Anomalies ──
                if (report.anomalies.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text('สิ่งผิดปกติที่ตรวจพบ',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  ...report.anomalies.map((a) => _bullet(a, AppColors.accent,
                      Icons.warning_amber_rounded)),
                ],

                // ── Suggestions ──
                if (report.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text('คำแนะนำ',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  ...report.suggestions.map((s) => _bullet(s,
                      AppColors.secondary, Icons.lightbulb_outline)),
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
