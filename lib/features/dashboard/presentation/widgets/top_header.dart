import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TopHeader extends StatelessWidget {
  const TopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good evening',
              style: TextStyle(
                color: AppColors.neutral,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Bedroom',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.iconBox,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: AppColors.secondary,
            size: 34,
          ),
        ),
      ],
    );
  }
}
