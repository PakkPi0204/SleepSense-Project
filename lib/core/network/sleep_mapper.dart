import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'api_models.dart';
import '../scoring/environment_scoring.dart';
import '../../features/sleep/models/sleep_models.dart';

/// แปลง SensorDataDto → models ของหน้า Sleep
///
/// หมายเหตุ: เดิมไฟล์นี้ hardcode ค่า threshold ไว้ตรงๆ (18-26°C, 30-60% ฯลฯ)
/// แยกจากค่าที่ DashboardMapper ใช้ (ซึ่งดึงจาก [ThresholdSettingsDto] ที่ผู้ใช้
/// ปรับเองผ่านหน้า Settings) — ทำให้หน้า Sleep กับหน้า Home ตัดสิน
/// Optimal/Warning ของค่าเดียวกันไม่ตรงกัน ทุกฟังก์ชันด้านล่างนี้จึงรับ
/// [ThresholdSettingsDto?] เข้ามาเช่นเดียวกับ DashboardMapper และ fallback ไป
/// ใช้ default ชุดเดียวกันเป๊ะๆ เมื่อไม่ได้ส่งมา เพื่อให้ทั้งแอปตัดสินสถานะของ
/// sensor ตัวเดียวกันตรงกันเสมอไม่ว่าจะดูจากหน้าไหน
///
/// เดิมยังมีอีกปัญหาซ้อนอยู่ในคะแนน "Sleep Readiness" เอง (แยกจากปัญหา
/// threshold ไม่ตรงกันด้านบน): คะแนนรวมของหน้านี้กับ "Sleep Environment
/// Score" หน้า Home คำนวณคนละสูตร (หน้า Home ใช้สูตร "หัก" ทีละก้อนตาม
/// warning/critical, หน้านี้ใช้สูตร "ไล่เชิงเส้น") ทำให้ sensor ชุดเดียวกัน
/// ได้คะแนนไม่ตรงกันแม้ threshold จะตรงกันแล้วก็ตาม จึงย้ายสูตรคำนวณไปไว้ที่
/// เดียวใน [EnvironmentScoring] แล้วให้ทั้งสองหน้าเรียกใช้ร่วมกัน
/// (ดู DashboardMapper.toEnvironmentScore) เพื่อการันตีว่าตัวเลขตรงกันเสมอ
class SleepMapper {
  SleepMapper._();

  /// คำนวณ Sleep Readiness จากค่า sensor โดยอิงตาม threshold ของผู้ใช้ (ถ้ามี)
  /// — ใช้สูตรเดียวกับ Sleep Environment Score หน้า Home ผ่าน [EnvironmentScoring]
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

  /// แปลงเป็น Environment Checklist (6 รายการ) โดยอิงตาม threshold ของผู้ใช้
  /// (ถ้ามี) — ใช้เกณฑ์เดียวกันกับ DashboardMapper.toSensorReadings เป๊ะๆ
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
