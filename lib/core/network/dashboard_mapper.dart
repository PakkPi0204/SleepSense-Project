import 'package:flutter/material.dart';

import '../network/api_models.dart';
import '../../features/dashboard/models/dashboard_models.dart';

/// แปลงข้อมูลจาก backend (DTO) → UI models ที่หน้าจอใช้อยู่แล้ว
/// รวมตรรกะการ format ค่า + จัดสถานะ (Optimal/Warning ฯลฯ) ไว้ที่เดียว
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
  static List<SensorReading> toSensorReadings(SensorDataDto d) {
    return [
      SensorReading(
        icon: Icons.thermostat_outlined,
        title: 'Temperature',
        value: d.temperature < 0 ? 'N/A' : '${_fmt(d.temperature)}°C',
        status: d.temperature < 0 ? 'No sensor' : _tempStatus(d.temperature),
        level: d.temperature < 0 ? SensorLevel.normal : _tempLevel(d.temperature),
      ),
      SensorReading(
        icon: Icons.water_drop_outlined,
        title: 'Humidity',
        value: d.humidity < 0 ? 'N/A' : '${_fmt(d.humidity)}%',
        status: d.humidity < 0 ? 'No sensor' : _rangeStatus(d.humidity, 30, 60),
        level: d.humidity < 0
            ? SensorLevel.normal
            : _rangeLevel(d.humidity, 30, 60),
      ),
      SensorReading(
        icon: Icons.air,
        title: 'CO₂',
        value: d.co2 <= 0 ? 'N/A' : '${d.co2.round()} ppm',
        status: d.co2 <= 0 ? 'No sensor' : _co2Status(d.co2),
        level: d.co2 <= 0 ? SensorLevel.normal : _co2Level(d.co2),
      ),
      SensorReading(
        icon: Icons.speed_outlined,
        title: 'PM2.5',
        value: '${_fmt(d.pm25)} μg/m³',
        status: _pm25Status(d.pm25),
        level: _pm25Level(d.pm25),
      ),
      SensorReading(
        icon: Icons.wb_sunny_outlined,
        title: 'Light',
        value: '${d.lightIntensity.round()} lux',
        status: d.lightIntensity <= 50 ? 'Optimal' : 'Bright',
        level: d.lightIntensity <= 50
            ? SensorLevel.normal
            : SensorLevel.warning,
      ),
      SensorReading(
        icon: Icons.volume_up_outlined,
        title: 'Sound',
        value: '${d.noiseLevel.round()} dB',
        status: _noiseStatus(d.noiseLevel),
        level: _noiseLevel(d.noiseLevel),
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
  static SensorLevel _tempLevel(double t) {
    if (t < 18 || t > 26) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  static SensorLevel _rangeLevel(double v, double min, double max) {
    if (v < min || v > max) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  static SensorLevel _co2Level(double c) {
    if (c >= 2000) return SensorLevel.critical;
    if (c >= 1000) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  static SensorLevel _pm25Level(double p) {
    if (p >= 75) return SensorLevel.critical;
    if (p >= 35) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  static SensorLevel _noiseLevel(double n) {
    if (n >= 60) return SensorLevel.critical;
    if (n >= 35) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  /// คำนวณ environment score จากค่า sensor (0-100)
  static EnvironmentScore toEnvironmentScore(SensorDataDto d) {
    int score = 100;
    if (d.co2 > 0) {
      if (d.co2 > 1000) score -= 20;
      if (d.co2 > 2000) score -= 20;
    }
    if (d.temperature < 18 || d.temperature > 26) score -= 15;
    if (d.pm25 > 35) score -= 15;
    if (d.pm25 > 75) score -= 15;
    if (d.noiseLevel > 35) score -= 10;
    if (d.lightIntensity > 50) score -= 10;
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

  /// list ข้อความ → PreSleepSuggestion (โชว์อันแรก)
  static PreSleepSuggestion toPreSleepSuggestion(List<String> suggestions) {
    final msg = suggestions.isNotEmpty
        ? suggestions.first
        : 'สภาพแวดล้อมห้องนอนเหมาะสมสำหรับการนอนหลับ';
    return PreSleepSuggestion(
      icon: Icons.light_mode_outlined,
      title: 'Pre-Sleep Suggestion',
      message: msg,
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

  static String _tempStatus(double t) {
    if (t >= 20 && t <= 24) return 'Optimal';
    if (t >= 18 && t <= 26) return 'Good';
    return 'Warning';
  }

  static String _rangeStatus(double v, double min, double max) {
    if (v >= min && v <= max) return 'Optimal';
    return 'Warning';
  }

  static String _co2Status(double c) {
    if (c < 1000) return 'Optimal';
    if (c < 2000) return 'Warning';
    return 'Critical';
  }

  static String _pm25Status(double p) {
    if (p < 35) return 'Good';
    if (p < 75) return 'Warning';
    return 'Critical';
  }

  static String _noiseStatus(double n) {
    if (n < 35) return 'Quiet';
    if (n < 60) return 'Warning';
    return 'Loud';
  }
}
