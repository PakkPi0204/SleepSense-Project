import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SleepMonitoringButton extends StatelessWidget {
  const SleepMonitoringButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.play_arrow_rounded, size: 34),
        label: const Text('Start Night Monitoring'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.primary,
          elevation: 16,
          shadowColor: AppColors.secondary.withValues(alpha: 0.48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
