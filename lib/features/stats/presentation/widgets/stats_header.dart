import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bedroom',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Stats',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              Text(
                "Last night's environment overview",
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder, width: 1.3),
          ),
          child: const Icon(
            Icons.trending_up_rounded,
            color: AppColors.secondary,
            size: 32,
          ),
        ),
      ],
    );
  }
}
