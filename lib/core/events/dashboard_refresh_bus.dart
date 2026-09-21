import 'package:flutter/foundation.dart';

/// A minimal signal — no extra state-management library — telling the Home
/// screen that there is new data worth reloading right away.
///
/// The app keeps every tab alive in an IndexedStack (see SleepSenseShell), so
/// HomeDashboardScreen is never disposed on a tab switch and would otherwise
/// wait for its 30-second auto-refresh. The symptom: press "Stop Monitoring" on
/// the Sleep screen, switch straight back to Home, and the Morning Report card
/// still shows the previous night until the next refresh tick. This signal tells
/// Home to reload immediately instead.
class DashboardRefreshBus {
  DashboardRefreshBus._();
  static final DashboardRefreshBus instance = DashboardRefreshBus._();

  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  ValueListenable<int> get listenable => _tick;

  /// Call whenever there is new data Home should see at once (a morning report
  /// was just generated). Bumps the notifier to trigger every listener.
  void notifyDataChanged() {
    _tick.value++;
  }
}
