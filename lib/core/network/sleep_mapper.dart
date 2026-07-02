import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'api_models.dart';
import '../../features/sleep/models/sleep_models.dart';

/// แปลง SensorDataDto → models ของหน้า Sleep
class SleepMapper {
  SleepMapper._();

  /// คำนวณ Sleep Readiness จากค่า sensor
  static SleepReadiness toReadiness(SensorDataDto d) {
    // คะแนนแต่ละด้าน (0-100)
    final air = _airScore(d);
    final light = _lightScore(d.lightIntensity);
    final sound = _soundScore(d.noiseLevel);

    final overall = ((air + light + sound) / 3).round();
    final status = overall >= 80
        ? 'Good'
        : overall >= 50
            ? 'Moderate'
            : 'Poor';
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
          label: 'Air',
          percent: air,
          color: air >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Light',
          percent: light,
          color: light >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Sound',
          percent: sound,
          color: sound >= 70 ? AppColors.secondary : AppColors.accent,
        ),
      ],
    );
  }

  /// แปลงเป็น Environment Checklist (6 รายการ)
  static List<EnvironmentCheckItem> toChecklist(SensorDataDto d) {
    return [
      _item(Icons.thermostat_outlined, 'Temperature',
          '${d.temperature.toStringAsFixed(1)} °C',
          d.temperature >= 18 && d.temperature <= 26, 'Optimal', 'Adjust temp'),
      _item(Icons.water_drop_outlined, 'Humidity',
          '${d.humidity.toStringAsFixed(0)} %',
          d.humidity >= 40 && d.humidity <= 60, 'Optimal', 'Check humidity'),
      _item(Icons.air, 'CO₂', '${d.co2.round()} ppm',
          d.co2 < 1000, 'Optimal', 'Ventilate'),
      _item(Icons.bolt_outlined, 'PM2.5', '${d.pm25.toStringAsFixed(0)} μg/m³',
          d.pm25 < 35, 'Good', 'Air purifier'),
      _item(Icons.wb_sunny_outlined, 'Light', '${d.lightIntensity.round()} lux',
          d.lightIntensity <= 50, 'Optimal', 'Needs dimming'),
      _item(Icons.volume_up_outlined, 'Sound', '${d.noiseLevel.round()} dB',
          d.noiseLevel < 40, 'Quiet', 'Reduce noise'),
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

  // ── factor scores ──
  static int _airScore(SensorDataDto d) {
    int s = 100;
    if (d.co2 > 1000) s -= 30;
    if (d.co2 > 2000) s -= 30;
    if (d.pm25 > 35) s -= 20;
    if (d.pm25 > 75) s -= 20;
    return s.clamp(0, 100);
  }

  static int _lightScore(double lux) {
    if (lux <= 5) return 100;
    if (lux <= 50) return 60;
    return 25;
  }

  static int _soundScore(double db) {
    if (db < 30) return 100;
    if (db < 40) return 88;
    if (db < 60) return 45;
    return 20;
  }
}
