import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/dashboard_sample_data.dart';
import '../widgets/environment_score_card.dart';
import '../widgets/morning_report_card.dart';
import '../widgets/pre_sleep_suggestion_card.dart';
import '../widgets/sensor_grid.dart';
import '../widgets/top_header.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: const SafeArea(
            bottom: false,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TopHeader(),
                      SizedBox(height: 36),
                      EnvironmentScoreCard(score: sampleEnvironmentScore),
                      SizedBox(height: 28),
                      SensorGrid(readings: sampleSensorReadings),
                      SizedBox(height: 28),
                      PreSleepSuggestionCard(
                        suggestion: samplePreSleepSuggestion,
                      ),
                      SizedBox(height: 24),
                      MorningReportCard(report: sampleMorningReport),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
