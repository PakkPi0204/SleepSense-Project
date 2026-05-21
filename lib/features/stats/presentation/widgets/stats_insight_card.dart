import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/stats_models.dart';

class StatsInsightCard extends StatelessWidget {
  final StatsInsight insight;

  const StatsInsightCard({required this.insight, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(insight.icon, color: AppColors.accent, size: 31),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  insight.message,
                  style: const TextStyle(
                    color: AppColors.neutral,
                    fontSize: 18,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
