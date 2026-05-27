import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

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
                'SleepSense',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Manage your room, device, and sleep preferences',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 18,
                  height: 1.45,
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
            Icons.settings_outlined,
            color: AppColors.secondary,
            size: 32,
          ),
        ),
      ],
    );
  }
}
