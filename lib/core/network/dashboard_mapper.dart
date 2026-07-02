import 'package:flutter/material.dart';

import '../network/api_models.dart';
import '../../features/dashboard/models/dashboard_models.dart';

/// แปลงข้อมูลจาก backend (DTO) → UI models ที่หน้าจอใช้อยู่แล้ว
/// รวมตรรกะการ format ค่า + จัดสถานะ (Optimal/Warning ฯลฯ) ไว้ที่เดียว
class DashboardMapper {
  DashboardMapper._();

  /// SensorDataDto → list ของ SensorReading (6 การ์ด)
  static List<SensorReading> toSensorReadings(SensorDataDto d) {
    return [
      SensorReading(
        icon: Icons.thermostat_outlined,
        title: 'Temperature',
        value: '${_fmt(d.temperature)}°C',
        status: _tempStatus(d.temperature),
      ),
      SensorReading(
        icon: Icons.water_drop_outlined,
        title: 'Humidity',
        value: '${_fmt(d.humidity)}%',
        status: _rangeStatus(d.humidity, 40, 60),
      ),
      SensorReading(
        icon: Icons.air,
        title: 'CO₂',
        value: '${d.co2.round()} ppm',
        status: _co2Status(d.co2),
      ),
      SensorReading(
        icon: Icons.speed_outlined,
        title: 'PM2.5',
        value: '${_fmt(d.pm25)} μg/m³',
        status: _pm25Status(d.pm25),
      ),
      SensorReading(
        icon: Icons.wb_sunny_outlined,
        title: 'Light',
        value: '${d.lightIntensity.round()} lux',
        status: d.lightIntensity <= 50 ? 'Optimal' : 'Bright',
      ),
      SensorReading(
        icon: Icons.volume_up_outlined,
        title: 'Sound',
        value: '${d.noiseLevel.round()} dB',
        status: _noiseStatus(d.noiseLevel),
      ),
    ];
  }

  /// คำนวณ environment score จากค่า sensor (0-100)
  static EnvironmentScore toEnvironmentScore(SensorDataDto d) {
    int score = 100;
    if (d.co2 > 1000) score -= 20;
    if (d.co2 > 2000) score -= 20;
    if (d.temperature < 18 || d.temperature > 26) score -= 15;
    if (d.pm25 > 35) score -= 15;
    if (d.pm25 > 75) score -= 15;
    if (d.noiseLevel > 40) score -= 10;
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
    if (n < 40) return 'Quiet';
    if (n < 60) return 'Warning';
    return 'Loud';
  }
}
