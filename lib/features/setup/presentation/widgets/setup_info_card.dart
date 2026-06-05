import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SetupInfoCard extends StatelessWidget {
  const SetupInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.iconBox,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.34),
                width: 1.1,
              ),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: AppColors.secondary,
              size: 29,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Text.rich(
              TextSpan(
                text: 'SleepSense monitors ',
                children: [
                  TextSpan(
                    text: 'CO₂, temperature, humidity, PM2.5, light, and sound',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: ' to help you understand your sleep environment.',
                  ),
                ],
              ),
              style: TextStyle(
                color: AppColors.neutral,
                fontSize: 18,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
