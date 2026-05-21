import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'navigation/sleepsense_shell.dart';

class SleepSenseApp extends StatelessWidget {
  const SleepSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SleepSenseShell(),
    );
  }
}
