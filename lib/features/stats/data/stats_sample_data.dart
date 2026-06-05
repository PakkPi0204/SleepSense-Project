import 'package:flutter/material.dart';

import '../models/stats_models.dart';

const sampleEnvironmentSummary = EnvironmentSummary(
  percentage: 78,
  status: 'Mostly Comfortable',
  message: 'Your room stayed within a good range for most of the night.',
  metrics: [
    SummaryMetric(label: 'Avg Temp', value: '20.8 °C'),
    SummaryMetric(label: 'Avg CO₂', value: '620 ppm'),
    SummaryMetric(label: 'Avg Sound', value: '35 dB'),
  ],
);

const sampleCo2TrendPoints = [
  TrendPoint(label: '12AM', value: 450),
  TrendPoint(label: '1AM', value: 480),
  TrendPoint(label: '2AM', value: 520),
  TrendPoint(label: '3AM', value: 630),
  TrendPoint(label: '4AM', value: 680),
  TrendPoint(label: '5AM', value: 650),
  TrendPoint(label: '6AM', value: 610),
  TrendPoint(label: '7AM', value: 565),
];

const sampleSensorAverages = [
  SensorAverage(
    icon: Icons.thermostat_outlined,
    title: 'Temperature',
    value: '20.8 °C',
    status: 'Optimal',
  ),
  SensorAverage(
    icon: Icons.water_drop_outlined,
    title: 'Humidity',
    value: '48 %',
    status: 'Optimal',
  ),
  SensorAverage(
    icon: Icons.air,
    title: 'CO₂',
    value: '620 ppm',
    status: 'Good',
  ),
  SensorAverage(
    icon: Icons.bolt_outlined,
    title: 'PM2.5',
    value: '14 μg/m³',
    status: 'Good',
  ),
  SensorAverage(
    icon: Icons.wb_sunny_outlined,
    title: 'Light',
    value: '4 lux',
    status: 'Optimal',
  ),
  SensorAverage(
    icon: Icons.volume_up_outlined,
    title: 'Sound',
    value: '35 dB',
    status: 'Quiet',
  ),
];

const sampleStatsInsight = StatsInsight(
  icon: Icons.lightbulb_outline_rounded,
  title: 'Insight',
  message:
      'CO₂ increased after 2:00 AM. Try improving ventilation before sleep.',
);
