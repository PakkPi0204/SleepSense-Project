import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

/// Last night's summary at the bottom of the dashboard.
///
/// Tapping it opens the full Morning Report history. That entry point matters:
/// Morning Reports used to occupy the Stats tab, which now holds the multi-night
/// Smart Suggestion analysis instead, so this card is how the user reaches their
/// per-night reports.
class MorningReportCard extends StatelessWidget {
  final MorningReport report;
  final VoidCallback? onTap;

  const MorningReportCard({required this.report, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                report.period,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: report.metrics.map(ReportMetricView.new).toList(),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 22),
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 14),
            const Row(
              children: [
                Text(
                  'View all morning reports',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right,
                    color: AppColors.secondary, size: 22),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: card,
    );
  }
}

class ReportMetricView extends StatelessWidget {
  final ReportMetric metric;

  const ReportMetricView(this.metric, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          style: const TextStyle(
            color: AppColors.neutral,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          metric.value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
