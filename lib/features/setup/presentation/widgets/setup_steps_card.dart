import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SetupStepsCard extends StatelessWidget {
  const SetupStepsCard({super.key});

  static const _steps = [
    _SetupStepData(
      title: 'Connect Device',
      description: 'Enter the Device ID shown on your SleepSense device.',
    ),
    _SetupStepData(
      title: 'Set Up Room',
      description: 'Add your room name and usual sleep schedule.',
    ),
    _SetupStepData(
      title: 'Start Monitoring',
      description: 'View real-time data and sleep environment insights.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bed_outlined, color: AppColors.secondary, size: 25),
              SizedBox(width: 12),
              Text(
                "What you'll set up",
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          for (var index = 0; index < _steps.length; index++)
            _SetupStep(
              number: index + 1,
              data: _steps[index],
              showConnector: index != _steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final int number;
  final _SetupStepData data;
  final bool showConnector;

  const _SetupStep({
    required this.number,
    required this.data,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.iconBox,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.48),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    number.toString(),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 1.2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: AppColors.secondary.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 26 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 21,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.description,
                    style: const TextStyle(
                      color: AppColors.neutral,
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStepData {
  final String title;
  final String description;

  const _SetupStepData({required this.title, required this.description});
}
