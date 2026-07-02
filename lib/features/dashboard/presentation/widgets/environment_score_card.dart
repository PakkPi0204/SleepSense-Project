import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/dashboard_models.dart';

class EnvironmentScoreCard extends StatelessWidget {
  final EnvironmentScore score;

  const EnvironmentScoreCard({required this.score, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
      decoration: BoxDecoration(
        color: AppColors.scoreCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.trending_up,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score.title,
                style: const TextStyle(
                  color: AppColors.neutral,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score.value.toString(),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 76,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '/${score.maxValue}',
                      style: const TextStyle(
                        color: AppColors.neutral,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                score.status,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
