import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'api_models.dart';
import '../scoring/environment_scoring.dart';
import '../../features/sleep/models/sleep_models.dart';

/// Maps SensorDataDto onto the Sleep screen models.
///
/// This file used to hardcode its thresholds (18-26°C, 30-60% and so on),
/// separately from the ones DashboardMapper reads out of [ThresholdSettingsDto],
/// so Sleep and Home could disagree about the same value. Every function below
/// now takes a [ThresholdSettingsDto?] like DashboardMapper does, and falls back
/// to exactly the same defaults, so the whole app agrees on a reading's status
/// no matter which screen you look at.
///
/// A second problem sat on top of that one, in the Sleep Readiness score itself:
/// this screen and the Sleep Environment Score on Home used different formulas
/// (Home deducted points per warning or critical; this screen scaled linearly),
/// so one reading produced two different numbers even once the thresholds
/// matched. The formula now lives in one place, [EnvironmentScoring], and both
/// screens call it (see DashboardMapper.toEnvironmentScore).
class SleepMapper {
  SleepMapper._();

  /// Sleep Readiness from a sensor reading, against the user's thresholds when
  /// present — same formula as Home's Sleep Environment Score, via [EnvironmentScoring].
  static SleepReadiness toReadiness(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final scores = EnvironmentScoring.factorScores(d, thresholds: thresholds);
    final overall = scores.overall;
    final status = EnvironmentScoring.statusFor(overall);
    final message = overall >= 80
        ? 'Your bedroom is mostly ready for sleep.'
        : overall >= 50
            ? 'Your bedroom needs a few adjustments.'
            : 'Your bedroom needs attention before sleep.';

    return SleepReadiness(
      score: overall,
      maxScore: 100,
      status: status,
      message: message,
      factors: [
        ReadinessFactor(
          label: 'Room',
          percent: scores.room.round(),
          color: scores.room >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Air',
          percent: scores.air.round(),
          color: scores.air >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Light',
          percent: scores.light.round(),
          color: scores.light >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Sound',
          percent: scores.sound.round(),
          color: scores.sound >= 70 ? AppColors.secondary : AppColors.accent,
        ),
      ],
    );
  }

  /// The six-item Environment Checklist, against the user's thresholds when
  /// present — exactly the criteria DashboardMapper.toSensorReadings uses.
  static List<EnvironmentCheckItem> toChecklist(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final co2Warning = thresholds?.co2Warning ?? 1000;
    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final lightWarning = thresholds?.lightMax ?? 50;
    final noiseWarning = thresholds?.noiseWarning ?? 40;

    return [
      _item(Icons.thermostat_outlined, 'Temperature',
          '${d.temperature.toStringAsFixed(1)} °C',
          d.temperature >= tempMin && d.temperature <= tempMax, 'Optimal',
          'Adjust temp'),
      _item(Icons.water_drop_outlined, 'Humidity',
          '${d.humidity.toStringAsFixed(0)} %',
          d.humidity >= humidityMin && d.humidity <= humidityMax, 'Optimal',
          'Check humidity'),
      _item(Icons.air, 'CO₂', '${d.co2.round()} ppm',
          d.co2 < co2Warning, 'Optimal', 'Ventilate'),
      _item(Icons.bolt_outlined, 'PM2.5', '${d.pm25.toStringAsFixed(0)} μg/m³',
          d.pm25 < pm25Warning, 'Good', 'Air purifier'),
      _item(Icons.wb_sunny_outlined, 'Light', '${d.lightIntensity.round()} lux',
          d.lightIntensity <= lightWarning, 'Optimal', 'Needs dimming'),
      _item(Icons.volume_up_outlined, 'Sound', '${d.noiseLevel.round()} dB',
          d.noiseLevel < noiseWarning, 'Quiet', 'Reduce noise'),
    ];
  }

  static EnvironmentCheckItem _item(IconData icon, String title, String value,
      bool ok, String okStatus, String warnStatus) {
    return EnvironmentCheckItem(
      icon: icon,
      title: title,
      value: value,
      status: ok ? okStatus : warnStatus,
      warning: !ok,
    );
  }
}
