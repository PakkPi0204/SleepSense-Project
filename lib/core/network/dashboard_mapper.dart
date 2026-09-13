import 'package:flutter/material.dart';

import '../network/api_models.dart';
import '../../features/dashboard/models/dashboard_models.dart';

/// แปลงข้อมูลจาก backend (DTO) → UI models ที่หน้าจอใช้อยู่แล้ว
/// รวมตรรกะการ format ค่า + จัดสถานะ (Optimal/Warning ฯลฯ) ไว้ที่เดียว
///
/// หมายเหตุ: ทุกฟังก์ชันที่ต้องตัดสิน Warning/Critical รับ [ThresholdSettingsDto?]
/// เข้ามาด้วยเสมอ ถ้าไม่ส่งมา (หรือ field เป็น null) จะ fallback เป็นค่า default
/// เดิมของระบบ — ค่า default พวกนี้ต้องตรงกับ ThresholdConfig.java ฝั่ง backend
class DashboardMapper {
  /// เช็คว่าข้อมูล sensor เก่าเกินไปไหม (ESP32 อาจหยุดส่ง/ออฟไลน์)
  /// ESP32 ส่งทุก 30 วิ — ถ้าเกิน 2 นาทีถือว่าน่าจะออฟไลน์
  static bool isStale(String timestamp) {
    try {
      final last = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(last);
      return diff.inSeconds > 120; // เกิน 2 นาที
    } catch (_) {
      return false; // อ่าน timestamp ไม่ได้ ไม่ตัดสินว่า stale
    }
  }

  DashboardMapper._();

  /// SensorDataDto → list ของ SensorReading (6 การ์ด)
  /// [thresholds] คือค่าที่ผู้ใช้ปรับเอง (หรือ default จาก backend) — ใช้ตัดสิน
  /// สถานะ Optimal/Warning/Critical ของแต่ละค่า
  static List<SensorReading> toSensorReadings(
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

    return [
      SensorReading(
        icon: Icons.thermostat_outlined,
        title: 'Temperature',
        value: d.temperature < 0 ? 'N/A' : '${_fmt(d.temperature)}°C',
        status: d.temperature < 0
            ? 'No sensor'
            : _tempStatus(d.temperature, tempMin, tempMax, tempCriticalMin,
                tempCriticalMax),
        level: d.temperature < 0
            ? SensorLevel.normal
            : _rangeLevel(d.temperature, tempMin, tempMax,
                criticalMin: tempCriticalMin, criticalMax: tempCriticalMax),
      ),
      SensorReading(
        icon: Icons.water_drop_outlined,
        title: 'Humidity',
        value: d.humidity < 0 ? 'N/A' : '${_fmt(d.humidity)}%',
        status: d.humidity < 0
            ? 'No sensor'
            : _rangeStatus(d.humidity, humidityMin, humidityMax),
        level: d.humidity < 0
            ? SensorLevel.normal
            : _rangeLevel(d.humidity, humidityMin, humidityMax,
                criticalMin: humidityCriticalMin,
                criticalMax: humidityCriticalMax),
      ),
      SensorReading(
        icon: Icons.air,
        title: 'CO₂',
        value: d.co2 <= 0 ? 'N/A' : '${d.co2.round()} ppm',
        status: d.co2 <= 0
            ? 'No sensor'
            : _thresholdStatus(d.co2, co2Warning, co2Critical),
        level: d.co2 <= 0
            ? SensorLevel.normal
            : _thresholdLevel(d.co2, co2Warning, co2Critical),
      ),
      SensorReading(
        icon: Icons.speed_outlined,
        title: 'PM2.5',
        value: '${_fmt(d.pm25)} μg/m³',
        status: _pm25Status(d.pm25, pm25Warning, pm25Critical),
        level: _thresholdLevel(d.pm25, pm25Warning, pm25Critical),
      ),
      SensorReading(
        icon: Icons.wb_sunny_outlined,
        title: 'Light',
        value: '${d.lightIntensity.round()} lux',
        status: d.lightIntensity > lightCritical
            ? 'Critical'
            : d.lightIntensity > lightWarning
                ? 'Bright'
                : 'Optimal',
        level: _thresholdLevel(d.lightIntensity, lightWarning, lightCritical),
      ),
      SensorReading(
        icon: Icons.volume_up_outlined,
        title: 'Sound',
        value: '${d.noiseLevel.round()} dB',
        status: _noiseStatus(d.noiseLevel, noiseWarning, noiseCritical),
        level: _thresholdLevel(d.noiseLevel, noiseWarning, noiseCritical),
      ),
      SensorReading(
        icon: Icons.directions_walk,
        title: 'Motion',
        value: d.motionDetected ? 'Detected' : 'None',
        status: d.motionDetected ? 'Movement' : 'Still',
        level: SensorLevel.normal,
      ),
    ];
  }

  // ── ระดับความรุนแรงตาม threshold (สำหรับเลือกสี) ──
  // รับช่วง min/max (+ critical min/max ถ้ามี) มาจาก ThresholdSettingsDto แทน
  // การ hardcode ค่าคงที่ไว้ในฟังก์ชัน
  static SensorLevel _rangeLevel(double v, double min, double max,
      {double? criticalMin, double? criticalMax}) {
    if (criticalMin != null && v < criticalMin) return SensorLevel.critical;
    if (criticalMax != null && v > criticalMax) return SensorLevel.critical;
    if (v < min || v > max) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  /// ใช้กับค่าที่ยิ่งสูงยิ่งแย่ทางเดียว (CO2 / PM2.5 / Light / Noise)
  static SensorLevel _thresholdLevel(
      double v, double warning, double critical) {
    if (v >= critical) return SensorLevel.critical;
    if (v >= warning) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  /// คำนวณ environment score จากค่า sensor (0-100) โดยอิงตาม threshold ของผู้ใช้
  static EnvironmentScore toEnvironmentScore(
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

    int score = 100;
    if (d.co2 > 0) {
      if (d.co2 > co2Warning) score -= 20;
      if (d.co2 > co2Critical) score -= 20; // รวม -40 เมื่อวิกฤต
    }
    if (d.temperature < tempMin || d.temperature > tempMax) score -= 15;
    if (d.temperature < tempCriticalMin || d.temperature > tempCriticalMax) {
      score -= 15; // รวม -30 เมื่อวิกฤต
    }
    if (d.humidity > 0 && (d.humidity < humidityMin || d.humidity > humidityMax)) {
      score -= 10;
    }
    if (d.humidity > 0 &&
        (d.humidity < humidityCriticalMin ||
            d.humidity > humidityCriticalMax)) {
      score -= 10; // รวม -20 เมื่อวิกฤต
    }
    if (d.pm25 > pm25Warning) score -= 15;
    if (d.pm25 > pm25Critical) score -= 15; // รวม -30 เมื่อวิกฤต
    if (d.noiseLevel > noiseWarning) score -= 10;
    if (d.noiseLevel > noiseCritical) score -= 10; // รวม -20 เมื่อวิกฤต
    if (d.lightIntensity > lightWarning) score -= 10;
    if (d.lightIntensity > lightCritical) score -= 10; // รวม -20 เมื่อวิกฤต
    if (score < 0) score = 0;

    final status = score >= 80
        ? 'Good'
        : score >= 50
            ? 'Moderate'
            : 'Poor';

    return EnvironmentScore(
      title: 'Sleep Environment Score',
      value: score,
      maxValue: 100,
      status: status,
    );
  }

  /// list ข้อความ (จาก backend) → PreSleepSuggestion แบบ "Smart Suggestion"
  /// โชว์อันแรกที่ backend ส่งมา แต่แปลงเป็นคำแนะนำเชิง action ที่กดจัดการได้เลย
  /// พร้อมแนบ [factorKey] คงที่ไว้ผูกกับสถานะปุ่ม "เปิดแล้ว" ใน local storage
  static PreSleepSuggestion toPreSleepSuggestion(List<String> suggestions) {
    if (suggestions.isEmpty) {
      return const PreSleepSuggestion(
        icon: Icons.check_circle_outline,
        title: 'Smart Suggestion',
        message:
            'สภาพแวดล้อมห้องนอนของคุณพร้อมสำหรับการนอนหลับแล้ว ✓ ไม่มีจุดที่ต้องปรับตอนนี้',
        factorKey: 'OK',
      );
    }

    final raw = suggestions.first;
    final rule = _matchSuggestionRule(raw);
    return PreSleepSuggestion(
      icon: rule.icon,
      title: 'Smart Suggestion',
      message: rule.buildMessage(raw),
      factorKey: rule.factorKey,
      actionLabel: rule.actionLabel,
      isWarning: true,
    );
  }

  /// จับคำสำคัญในข้อความที่ backend ส่งมา (ภาษาไทย) เพื่อแมปเป็น factor ที่คงที่
  /// + คำแนะนำเชิง action — ใช้การจับคำแทนการเทียบข้อความแบบเป๊ะ เพราะตัวเลข
  /// (องศา/ppm/%) ในข้อความจะเปลี่ยนไปทุกครั้งที่ sensor อัปเดตค่าใหม่
  static _SuggestionRule _matchSuggestionRule(String msg) {
    if (msg.contains('CO₂') || msg.contains('CO2')) {
      return _SuggestionRule(
        factorKey: 'CO2_HIGH',
        icon: Icons.air,
        actionLabel: 'เปิดหน้าต่างระบายอากาศ',
        intro: 'อากาศในห้องเริ่มอับ ระบายอากาศก่อนเข้านอนจะช่วยให้หลับสบายขึ้น',
      );
    }
    if (msg.contains('อุณหภูมิสูง')) {
      return _SuggestionRule(
        factorKey: 'TEMP_HIGH',
        icon: Icons.thermostat_outlined,
        actionLabel: 'เปิดพัดลม/แอร์',
        intro: 'ห้องร้อนเกินช่วงที่เหมาะกับการนอน ลดอุณหภูมิลงก่อนเข้านอนดีกว่า',
      );
    }
    if (msg.contains('อุณหภูมิต่ำ')) {
      return _SuggestionRule(
        factorKey: 'TEMP_LOW',
        icon: Icons.thermostat_outlined,
        actionLabel: 'เพิ่มความอบอุ่นในห้อง',
        intro: 'ห้องเย็นเกินไป เพิ่มความอบอุ่นสักหน่อยจะนอนหลับได้เต็มอิ่มกว่า',
      );
    }
    if (msg.contains('ความชื้นสูง')) {
      return _SuggestionRule(
        factorKey: 'HUMIDITY_HIGH',
        icon: Icons.water_drop_outlined,
        actionLabel: 'เปิดเครื่องลดความชื้น',
        intro: 'ความชื้นสูงเกินไป เสี่ยงอับชื้นและนอนไม่สบายตัว',
      );
    }
    if (msg.contains('ความชื้นต่ำ')) {
      return _SuggestionRule(
        factorKey: 'HUMIDITY_LOW',
        icon: Icons.water_drop_outlined,
        actionLabel: 'เปิดเครื่องเพิ่มความชื้น',
        intro: 'อากาศแห้งเกินไป อาจทำให้ระคายคอระหว่างนอน',
      );
    }
    if (msg.contains('PM2.5') || msg.contains('ฝุ่น')) {
      return _SuggestionRule(
        factorKey: 'PM25_HIGH',
        icon: Icons.speed_outlined,
        actionLabel: 'เปิดเครื่องฟอกอากาศ',
        intro: 'ฝุ่น PM2.5 สูงเกินค่าที่ปลอดภัย ควรฟอกอากาศก่อนนอน',
      );
    }
    if (msg.contains('แสงสว่าง')) {
      return _SuggestionRule(
        factorKey: 'LIGHT_HIGH',
        icon: Icons.wb_sunny_outlined,
        actionLabel: 'ปิดไฟ/ปิดม่าน',
        intro: 'ห้องยังสว่างเกินไปสำหรับการนอนหลับที่มีคุณภาพ',
      );
    }
    if (msg.contains('เสียง')) {
      return _SuggestionRule(
        factorKey: 'NOISE_HIGH',
        icon: Icons.volume_up_outlined,
        actionLabel: 'ลดเสียงรบกวน',
        intro: 'มีเสียงรบกวนเกินระดับที่เหมาะกับการนอน',
      );
    }
    // ไม่เข้าเงื่อนไขที่รู้จัก — ใช้ข้อความเดิมจาก backend ตรงๆ แต่ยังให้กด
    // "รับทราบ" ได้เพื่อคงพฤติกรรม smart-suggestion แบบเดียวกัน
    return _SuggestionRule(
      factorKey: 'OTHER',
      icon: Icons.light_mode_outlined,
      actionLabel: 'รับทราบ',
      intro: null,
    );
  }

  /// MorningReportDto → MorningReport (UI)
  static MorningReport toMorningReport(MorningReportDto d) {
    return MorningReport(
      title: 'Morning Report',
      period: 'Last night · ${d.environmentCluster}',
      metrics: [
        ReportMetric(label: 'Avg Temp', value: '${_fmt(d.avgTemperature)}°C'),
        ReportMetric(label: 'Avg CO₂', value: '${d.avgCo2.round()} ppm'),
        ReportMetric(label: 'Motion', value: '${d.motionEventCount}x'),
      ],
    );
  }

  // ── format & status helpers ──
  static String _fmt(double v) => v.toStringAsFixed(1);

  static String _tempStatus(double t, double min, double max,
      double criticalMin, double criticalMax) {
    if (t < criticalMin || t > criticalMax) return 'Critical';
    // "Optimal" คือช่วงกลางของ comfort range (ให้ผลใกล้เคียงของเดิมที่เคย
    // hardcode 20-24 ไว้ แต่ปรับตามช่วงที่ผู้ใช้ตั้งจริง)
    final mid = (min + max) / 2;
    final tightLo = mid - (max - min) / 6;
    final tightHi = mid + (max - min) / 6;
    if (t >= tightLo && t <= tightHi) return 'Optimal';
    if (t >= min && t <= max) return 'Good';
    return 'Warning';
  }

  static String _rangeStatus(double v, double min, double max) {
    if (v >= min && v <= max) return 'Optimal';
    return 'Warning';
  }

  /// ใช้กับค่าที่ยิ่งสูงยิ่งแย่ทางเดียว (CO2) — คืนข้อความสถานะ
  static String _thresholdStatus(double v, double warning, double critical) {
    if (v < warning) return 'Optimal';
    if (v < critical) return 'Warning';
    return 'Critical';
  }

  static String _pm25Status(double p, double warning, double critical) {
    if (p < warning) return 'Good';
    if (p < critical) return 'Warning';
    return 'Critical';
  }

  static String _noiseStatus(double n, double warning, double critical) {
    if (n < warning) return 'Quiet';
    if (n < critical) return 'Warning';
    return 'Loud';
  }

  /// เช็คว่า factor นี้ (จาก AlertDto.factor เช่น "TEMPERATURE", "CO2") ยัง
  /// วิกฤตอยู่จริงหรือไม่ เทียบกับค่า sensor + threshold "ปัจจุบัน" — ไม่ใช่ค่า
  /// value/threshold ที่บันทึกแช่แข็งไว้ตอนสร้าง alert แถวนั้น
  ///
  /// backend เก็บ alert เป็น log ประวัติศาสตร์ล้วนๆ (ไม่มีสถานะ
  /// resolved/active — ดู AlertRepository.findRecentByDevice) ดังนั้นถ้าผู้ใช้
  /// เพิ่งปรับ threshold ใหม่ให้กว้างขึ้น alert แถวเก่าที่เคยวิกฤตภายใต้
  /// threshold เดิมก็จะยังถูกส่งกลับมาใน "recent alerts" อยู่ดี ทั้งที่ค่า
  /// ปัจจุบันไม่วิกฤตแล้วภายใต้ threshold ใหม่ — ฟังก์ชันนี้ใช้กรองแถวแบบนั้น
  /// ออกก่อนจะบังคับเด้ง popup ซ้ำ
  static bool isFactorCritical(
    String factor,
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempCriticalMin = thresholds?.temperatureCriticalMin ?? 15;
    final tempCriticalMax = thresholds?.temperatureCriticalMax ?? 32;
    final humidityCriticalMin = thresholds?.humidityCriticalMin ?? 20;
    final humidityCriticalMax = thresholds?.humidityCriticalMax ?? 70;
    final co2Critical = thresholds?.co2Critical ?? 2000;
    final pm25Critical = thresholds?.pm25Critical ?? 75;
    final lightCritical = thresholds?.lightCritical ?? 200;
    final noiseCritical = thresholds?.noiseCritical ?? 60;

    switch (factor.toUpperCase()) {
      case 'TEMPERATURE':
        return d.temperature < tempCriticalMin ||
            d.temperature > tempCriticalMax;
      case 'HUMIDITY':
        return d.humidity > 0 &&
            (d.humidity < humidityCriticalMin ||
                d.humidity > humidityCriticalMax);
      case 'CO2':
        return d.co2 >= co2Critical;
      case 'PM25':
        return d.pm25 >= pm25Critical;
      case 'LIGHT':
        return d.lightIntensity >= lightCritical;
      case 'NOISE':
        return d.noiseLevel >= noiseCritical;
      default:
        // factor ที่ไม่รู้จัก — ไม่มีข้อมูลพอจะเช็คซ้ำ เชื่อ backend ไปก่อน
        return true;
    }
  }

  /// เหมือน [isFactorCritical] แต่รองรับ WARNING ด้วย — ใช้เฉพาะตอน fallback
  /// (backend เก่ายังไม่มี endpoint /active) ตอนกรอง /recent ฝั่ง client เอง
  /// factor ระดับ CRITICAL เช็คกับ critical bound, ระดับ WARNING เช็คกับ
  /// warning bound (เกณฑ์เดียวกับ toSensorReadings)
  static bool isFactorStillFlagged(
    String factor,
    String level,
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    if (level.toUpperCase() == 'CRITICAL') {
      return isFactorCritical(factor, d, thresholds: thresholds);
    }

    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final co2Warning = thresholds?.co2Warning ?? 1000;
    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final lightWarning = thresholds?.lightMax ?? 50;
    final noiseWarning = thresholds?.noiseWarning ?? 40;

    switch (factor.toUpperCase()) {
      case 'TEMPERATURE':
        return d.temperature < tempMin || d.temperature > tempMax;
      case 'HUMIDITY':
        return d.humidity > 0 &&
            (d.humidity < humidityMin || d.humidity > humidityMax);
      case 'CO2':
        return d.co2 >= co2Warning;
      case 'PM25':
        return d.pm25 >= pm25Warning;
      case 'LIGHT':
        return d.lightIntensity >= lightWarning;
      case 'NOISE':
        return d.noiseLevel >= noiseWarning;
      default:
        return true;
    }
  }
}

/// กติกาแปลงข้อความ suggestion ดิบจาก backend → smart suggestion 1 factor
/// (ไอคอน, factor key คงที่, action label, ประโยคแนะนำแบบอ่านง่าย)
class _SuggestionRule {
  final String factorKey;
  final IconData icon;
  final String actionLabel;
  final String? intro;

  const _SuggestionRule({
    required this.factorKey,
    required this.icon,
    required this.actionLabel,
    required this.intro,
  });

  /// ประกอบข้อความสุดท้าย: ประโยคแนะนำแบบอ่านง่าย (ถ้ามี) + ค่าที่วัดได้จริงจาก
  /// backend ต่อท้าย เพื่อให้เห็นทั้ง "ทำไมต้องทำ" และ "ตัวเลขจริงตอนนี้"
  String buildMessage(String raw) {
    if (intro == null) return raw;
    return '$intro\n$raw';
  }
}