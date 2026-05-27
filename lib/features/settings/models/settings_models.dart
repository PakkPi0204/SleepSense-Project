import 'package:flutter/material.dart';

enum SettingsRowType { navigation, value, toggle }

class SettingsSection {
  final String title;
  final List<SettingsRowData> rows;

  const SettingsSection({required this.title, required this.rows});
}

class SettingsRowData {
  final IconData icon;
  final String title;
  final String? value;
  final SettingsRowType type;
  final bool enabled;

  const SettingsRowData({
    required this.icon,
    required this.title,
    required this.type,
    this.value,
    this.enabled = false,
  });
}
