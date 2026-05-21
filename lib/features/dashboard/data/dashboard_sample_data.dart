import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';

const sampleEnvironmentScore = EnvironmentScore(
  title: 'Sleep Environment Score',
  value: 82,
  maxValue: 100,
  status: 'Good',
);

const sampleSensorReadings = [
  SensorReading(
    icon: Icons.thermostat_outlined,
    title: 'Temperature',
    value: '21.5°C',
    status: 'Optimal',
  ),
  SensorReading(
    icon: Icons.water_drop_outlined,
    title: 'Humidity',
    value: '45%',
    status: 'Optimal',
  ),
  SensorReading(
    icon: Icons.air,
    title: 'CO₂',
    value: '420 ppm',
    status: 'Optimal',
  ),
  SensorReading(
    icon: Icons.speed_outlined,
    title: 'PM2.5',
    value: '12 μg/m³',
    status: 'Good',
  ),
  SensorReading(
    icon: Icons.wb_sunny_outlined,
    title: 'Light',
    value: '5 lux',
    status: 'Optimal',
  ),
  SensorReading(
    icon: Icons.volume_up_outlined,
    title: 'Sound',
    value: '32 dB',
    status: 'Quiet',
  ),
];

const samplePreSleepSuggestion = PreSleepSuggestion(
  icon: Icons.light_mode_outlined,
  title: 'Pre-Sleep Suggestion',
  message:
      'Consider dimming lights 1 hour before bed. Current light level may affect room readiness for sleep.',
);

const sampleMorningReport = MorningReport(
  title: 'Morning Report Preview',
  period: 'Last night',
  metrics: [
    ReportMetric(label: 'Optimal Time', value: '78%'),
    ReportMetric(label: 'Quiet Time', value: '7.2h'),
    ReportMetric(label: 'Avg Temp', value: '20.8°C'),
  ],
);
