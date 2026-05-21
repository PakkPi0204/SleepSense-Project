import 'package:flutter/material.dart';

class EnvironmentSummary {
  final int percentage;
  final String status;
  final String message;
  final List<SummaryMetric> metrics;

  const EnvironmentSummary({
    required this.percentage,
    required this.status,
    required this.message,
    required this.metrics,
  });
}

class SummaryMetric {
  final String label;
  final String value;

  const SummaryMetric({required this.label, required this.value});
}

class TrendPoint {
  final String label;
  final double value;

  const TrendPoint({required this.label, required this.value});
}

class SensorAverage {
  final IconData icon;
  final String title;
  final String value;
  final String status;

  const SensorAverage({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
  });
}

class StatsInsight {
  final IconData icon;
  final String title;
  final String message;

  const StatsInsight({
    required this.icon,
    required this.title,
    required this.message,
  });
}
