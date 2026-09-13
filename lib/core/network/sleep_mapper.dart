import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'api_models.dart';
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
/// threshold ไม่ตรงกันด้านบน): สูตรคะแนนของ Light/Sound เป็นแบบ "ขั้นบันได"
/// (เช่น Light จะได้ 60% เสมอตราบใดที่ยังไม่ต่ำกว่า 5 lux แม้จะอยู่ในเกณฑ์
/// Optimal อยู่แล้วก็ตาม) และคะแนนรวมก็ไม่เคยเอาอุณหภูมิ/ความชื้นมาคิดด้วยเลย
/// (มีแค่ Air/Light/Sound) ผลคือถึงจะแก้ threshold ให้ตรงกันแล้ว การ์ด Sleep
/// Readiness ก็ยังโชว์ 83/100 อยู่ดี ทั้งที่ Sleep Environment Score หน้า Home
/// ขึ้น 100/100 — จึงปรับคะแนนทุกด้านให้เป็นสเกลต่อเนื่อง (100 เมื่ออยู่ในช่วง
/// optimal ไล่ลงเป็นเส้นตรงจนถึง 0 ที่ค่า critical) และเพิ่มอุณหภูมิ/ความชื้น
/// เข้ามาเป็นอีกหนึ่ง factor ("Room") ในคะแนนรวมด้วย ให้ตรรกะเดียวกับ
/// DashboardMapper.toEnvironmentScore เป๊ะๆ (อยู่ในช่วง optimal ทุกตัว = 100)
class SleepMapper {
  SleepMapper._();

  /// คำนวณ Sleep Readiness จากค่า sensor โดยอิงตาม threshold ของผู้ใช้ (ถ้ามี)
  static SleepReadiness toReadiness(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final tempCriticalMin = thresholds?.temperatureCriticalMin ?? 15;
    final tempCriticalMax = thresholds?.temperatureCriticalMax ?? 32;

    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final humidityCriticalMin = thresholds?.humidityCriticalMin ?? 20;
    final humidityCriticalMax = thresholds?.humidityCriticalMax ?? 70;

    final co2Warning = thresholds?.co2Warning ?? 1000;
    final co2Critical = thresholds?.co2Critical ?? 2000;
    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final pm25Critical = thresholds?.pm25Critical ?? 75;

    final lightWarning = thresholds?.lightMax ?? 50;
    final lightCritical = thresholds?.lightCritical ?? 200;
    final noiseWarning = thresholds?.noiseWarning ?? 40;
    final noiseCritical = thresholds?.noiseCritical ?? 60;

    // คะแนนแต่ละด้าน (0-100) แบบต่อเนื่อง: 100 เต็มเมื่ออยู่ในช่วง optimal,
    // ไล่ลงเป็นเส้นตรงจนถึง 0 ที่ค่า critical — ตรงกับเกณฑ์ที่ Environment
    // Checklist ใช้ตัดสิน Optimal/Warning ด้านล่างเป๊ะๆ ไม่มีจุดที่ยัง
    // "Optimal" อยู่แต่คะแนนถูกตรึงไว้ต่ำกว่า 100 เหมือนสูตรเดิม
    final room = ((_rangeScore(d.temperature, tempMin, tempMax,
                tempCriticalMin, tempCriticalMax) +
            _rangeScore(d.humidity, humidityMin, humidityMax,
                humidityCriticalMin, humidityCriticalMax)) /
        2);
    final air = ((_upperScore(d.co2, co2Warning, co2Critical) +
            _upperScore(d.pm25, pm25Warning, pm25Critical)) /
        2);
    final light = _upperScore(d.lightIntensity, lightWarning, lightCritical);
    final sound = _upperScore(d.noiseLevel, noiseWarning, noiseCritical);

    final overall = ((room + air + light + sound) / 4).round();
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
          label: 'Room',
          percent: room.round(),
          color: room >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Air',
          percent: air.round(),
          color: air >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Light',
          percent: light.round(),
          color: light >= 70 ? AppColors.secondary : AppColors.accent,
        ),
        ReadinessFactor(
          label: 'Sound',
          percent: sound.round(),
          color: sound >= 70 ? AppColors.secondary : AppColors.accent,
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

  /// คะแนนของค่าที่ "ยิ่งสูงยิ่งแย่ทางเดียว" (CO2 / PM2.5 / Light / Noise)
  /// อยู่ในช่วง optimal (<= warning) = 100 เต็ม ไล่ลงเป็นเส้นตรงจนถึง 0 ที่
  /// ค่า critical แล้วค้างที่ 0 ต่อจากนั้น
  static double _upperScore(double v, double warning, double critical) {
    if (v <= warning) return 100;
    if (critical <= warning) return 0; // กัน config ผิดพลาดหารด้วย 0
    if (v >= critical) return 0;
    final ratio = (v - warning) / (critical - warning);
    return (100 * (1 - ratio)).clamp(0, 100);
  }

  /// คะแนนของค่าที่มีทั้งขอบล่าง-บน (Temperature / Humidity) — อยู่ในช่วง
  /// [min, max] = 100 เต็ม ไล่ลงเป็นเส้นตรงจนถึง 0 ที่ขอบ critical ฝั่งนั้นๆ
  static double _rangeScore(
      double v, double min, double max, double criticalMin, double criticalMax) {
    if (v >= min && v <= max) return 100;
    if (v < min) {
      if (criticalMin >= min) return 0;
      if (v <= criticalMin) return 0;
      final ratio = (min - v) / (min - criticalMin);
      return (100 * (1 - ratio)).clamp(0, 100);
    }
    if (criticalMax <= max) return 0;
    if (v >= criticalMax) return 0;
    final ratio = (v - max) / (criticalMax - max);
    return (100 * (1 - ratio)).clamp(0, 100);
  }
}
