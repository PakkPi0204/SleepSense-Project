import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/sleep_sample_data.dart';
import '../widgets/environment_checklist.dart';
import '../widgets/pre_sleep_advice_card.dart';
import '../widgets/sleep_header.dart';
import '../widgets/sleep_monitoring_button.dart';
import '../widgets/sleep_readiness_card.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: const SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SleepHeader(),
                  SizedBox(height: 36),
                  SleepReadinessCard(readiness: sampleSleepReadiness),
                  SizedBox(height: 28),
                  EnvironmentChecklist(items: sampleEnvironmentChecklist),
                  SizedBox(height: 28),
                  PreSleepAdviceCard(advice: samplePreSleepAdvice),
                  SizedBox(height: 32),
                  SleepMonitoringButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
