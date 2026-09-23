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

/// Severity of a sensor value, used to pick its display colour.
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

  /// A stable key for this problem (TEMP_HIGH, HUMIDITY_LOW, OK). Used when
  /// reading and writing the "handled" flag in local storage. It is deliberately
  /// not tied to the numbers, which change on every sensor update, so the button
  /// state survives for as long as it is the same problem.
  final String factorKey;

  /// Label for the suggested action ("Turn on the fan"). Null when there is
  /// nothing to do because conditions are already fine.
  final String? actionLabel;

  /// True when this suggestion is a problem worth highlighting, as opposed to an
  /// ordinary or all-clear message.
  final bool isWarning;

  const PreSleepSuggestion({
    required this.icon,
    required this.title,
    required this.message,
    this.factorKey = 'OK',
    this.actionLabel,
    this.isWarning = false,
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
