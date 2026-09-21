import 'package:flutter/material.dart';

import 'app/sleepsense_app.dart';
import 'core/debug/debug_flags.dart';

void main() async {
  // Required before touching shared_preferences (or any plugin) while no
  // widget has been built yet.
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the developer toggle ("Always show critical popup") before the
  // first build, otherwise it resets to false on every launch.
  await DebugFlags.load();
  runApp(const SleepSenseApp());
}
