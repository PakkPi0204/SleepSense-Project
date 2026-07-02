import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SleepHeader extends StatelessWidget {
  const SleepHeader({super.key});

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
                'Good evening',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ready for Sleep?',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 39,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
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
            Icons.nightlight_round,
            color: AppColors.secondary,
            size: 31,
          ),
        ),
      ],
    );
  }
}
