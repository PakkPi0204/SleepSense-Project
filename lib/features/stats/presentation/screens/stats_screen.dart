import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/stats_sample_data.dart';
import '../widgets/co2_trend_card.dart';
import '../widgets/environment_summary_card.dart';
import '../widgets/sensor_averages_grid.dart';
import '../widgets/stats_header.dart';
import '../widgets/stats_insight_card.dart';
import '../widgets/stats_period_selector.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

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
                  StatsHeader(),
                  SizedBox(height: 32),
                  StatsPeriodSelector(),
                  SizedBox(height: 28),
                  EnvironmentSummaryCard(summary: sampleEnvironmentSummary),
                  SizedBox(height: 28),
                  Co2TrendCard(points: sampleCo2TrendPoints),
                  SizedBox(height: 28),
                  SensorAveragesGrid(averages: sampleSensorAverages),
                  SizedBox(height: 28),
                  StatsInsightCard(insight: sampleStatsInsight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
