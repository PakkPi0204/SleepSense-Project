import 'package:flutter/material.dart';

class SleepReadiness {
  final int score;
  final int maxScore;
  final String status;
  final String message;
  final List<ReadinessFactor> factors;

  const SleepReadiness({
    required this.score,
    required this.maxScore,
    required this.status,
    required this.message,
    required this.factors,
  });
}

class ReadinessFactor {
  final String label;
  final int percent;
  final Color color;

  const ReadinessFactor({
    required this.label,
    required this.percent,
    required this.color,
  });
}

class EnvironmentCheckItem {
  final IconData icon;
  final String title;
  final String value;
  final String status;
  final bool warning;

  const EnvironmentCheckItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    this.warning = false,
  });
}

class PreSleepAdvice {
  final IconData icon;
  final String title;
  final String message;

  const PreSleepAdvice({
    required this.icon,
    required this.title,
    required this.message,
  });
}
