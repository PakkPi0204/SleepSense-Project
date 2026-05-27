import 'package:flutter/material.dart';

import '../models/settings_models.dart';

const settingsSections = [
  SettingsSection(
    title: 'ROOM',
    rows: [
      SettingsRowData(
        icon: Icons.bed_outlined,
        title: 'Room Name',
        value: 'Bedroom',
        type: SettingsRowType.navigation,
      ),
      SettingsRowData(
        icon: Icons.schedule_rounded,
        title: 'Sleep Schedule',
        value: '10:30 PM - 7:00 AM',
        type: SettingsRowType.navigation,
      ),
    ],
  ),
  SettingsSection(
    title: 'DEVICE',
    rows: [
      SettingsRowData(
        icon: Icons.memory_rounded,
        title: 'Device ID',
        value: 'SS-1024',
        type: SettingsRowType.value,
      ),
      SettingsRowData(
        icon: Icons.wifi_rounded,
        title: 'Connection',
        value: 'Connected',
        type: SettingsRowType.value,
      ),
      SettingsRowData(
        icon: Icons.sync_rounded,
        title: 'Last Sync',
        value: '1 min ago',
        type: SettingsRowType.value,
      ),
    ],
  ),
  SettingsSection(
    title: 'NOTIFICATIONS',
    rows: [
      SettingsRowData(
        icon: Icons.notifications_none_rounded,
        title: 'Critical Alerts',
        type: SettingsRowType.toggle,
        enabled: true,
      ),
      SettingsRowData(
        icon: Icons.alarm_rounded,
        title: 'Pre-Sleep Reminder',
        type: SettingsRowType.toggle,
        enabled: true,
      ),
      SettingsRowData(
        icon: Icons.description_outlined,
        title: 'Morning Report',
        type: SettingsRowType.toggle,
        enabled: true,
      ),
    ],
  ),
  SettingsSection(
    title: 'THRESHOLDS',
    rows: [
      SettingsRowData(
        icon: Icons.air_rounded,
        title: 'CO₂ Limit',
        value: '900 ppm',
        type: SettingsRowType.navigation,
      ),
      SettingsRowData(
        icon: Icons.thermostat_outlined,
        title: 'Temperature Range',
        value: '18 - 24 °C',
        type: SettingsRowType.navigation,
      ),
      SettingsRowData(
        icon: Icons.water_drop_outlined,
        title: 'Humidity Range',
        value: '40 - 60 %',
        type: SettingsRowType.navigation,
      ),
      SettingsRowData(
        icon: Icons.bolt_outlined,
        title: 'PM2.5 Limit',
        value: '25 μg/m³',
        type: SettingsRowType.navigation,
      ),
    ],
  ),
  SettingsSection(
    title: 'ABOUT',
    rows: [
      SettingsRowData(
        icon: Icons.info_outline_rounded,
        title: 'About SleepSense',
        type: SettingsRowType.navigation,
      ),
      SettingsRowData(
        icon: Icons.sell_outlined,
        title: 'App Version',
        value: '1.0.0',
        type: SettingsRowType.value,
      ),
    ],
  ),
];
