import 'package:flutter/material.dart';

class EnvironmentScore {
  final String title;
  final int value;
  final int maxValue;
  final String status;

  const EnvironmentScore({
    required this.title,
    required this.value,
    required this.maxValue,
    required this.status,
  });
}

/// ระดับสถานะของค่า sensor (ใช้เลือกสีตอนแสดงผล)
enum SensorLevel { normal, warning, critical }

class SensorReading {
  final IconData icon;
  final String title;
  final String value;
  final String status;
  final SensorLevel level;

  const SensorReading({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    this.level = SensorLevel.normal,
  });
}

class PreSleepSuggestion {
  final IconData icon;
  final String title;
  final String message;

  const PreSleepSuggestion({
    required this.icon,
    required this.title,
    required this.message,
  });
}

class MorningReport {
  final String title;
  final String period;
  final List<ReportMetric> metrics;

  const MorningReport({
    required this.title,
    required this.period,
    required this.metrics,
  });
}

class ReportMetric {
  final String label;
  final String value;

  const ReportMetric({required this.label, required this.value});
}
