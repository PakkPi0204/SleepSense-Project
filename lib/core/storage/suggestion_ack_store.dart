import 'package:shared_preferences/shared_preferences.dart';

/// Stores the "handled" state of each suggestion and critical alert, per factor,
/// in local storage (SharedPreferences) rather than only in widget memory. That
/// way the "done" button keeps its state even after the app is force-killed and
/// reopened.
///
/// The key is the problem's factor (TEMP_HIGH, CRITICAL_CO2), not the id of a
/// sensor or alert row that changes every 30 seconds — we want to remember that
/// this problem was handled, not merely that a record was seen.
class SuggestionAckStore {
  SuggestionAckStore._();
  static final SuggestionAckStore instance = SuggestionAckStore._();

  static const _prefix = 'sleepsense_ack_';

  Future<bool> isAcknowledged(String factorKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$factorKey') ?? false;
  }

  Future<void> acknowledge(String factorKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$factorKey', true);
  }

  Future<void> clear(String factorKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$factorKey');
  }

  /// Clear every stored acknowledgement. Called once conditions are back to
  /// normal with nothing outstanding, so that if the same problem recurs the
  /// user is warned again instead of the old "done" state lingering forever.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
