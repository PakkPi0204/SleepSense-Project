import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/sleep_models.dart';

const sampleSleepReadiness = SleepReadiness(
  score: 82,
  maxScore: 100,
  status: 'Good',
  message: 'Your bedroom is mostly ready for sleep.',
  factors: [
    ReadinessFactor(label: 'Air', percent: 94, color: AppColors.secondary),
    ReadinessFactor(label: 'Light', percent: 60, color: AppColors.accent),
    ReadinessFactor(label: 'Sound', percent: 88, color: AppColors.secondary),
  ],
);

const sampleEnvironmentChecklist = [
  EnvironmentCheckItem(
    icon: Icons.thermostat_outlined,
    title: 'Temperature',
    value: '21.5 °C',
    status: 'Optimal',
  ),
  EnvironmentCheckItem(
    icon: Icons.water_drop_outlined,
    title: 'Humidity',
    value: '45 %',
    status: 'Optimal',
  ),
  EnvironmentCheckItem(
    icon: Icons.air,
    title: 'CO₂',
    value: '420 ppm',
    status: 'Optimal',
  ),
  EnvironmentCheckItem(
    icon: Icons.bolt_outlined,
    title: 'PM2.5',
    value: '12 μg/m³',
    status: 'Good',
  ),
  EnvironmentCheckItem(
    icon: Icons.wb_sunny_outlined,
    title: 'Light',
    value: '5 lux',
    status: 'Needs dimming',
    warning: true,
  ),
  EnvironmentCheckItem(
    icon: Icons.volume_up_outlined,
    title: 'Sound',
    value: '32 dB',
    status: 'Quiet',
  ),
];

const samplePreSleepAdvice = PreSleepAdvice(
  icon: Icons.wb_sunny_outlined,
  title: 'Before you sleep',
  message:
      'Try dimming the lights 1 hour before bed to support a better sleep environment.',
);
