import 'package:shared_preferences/shared_preferences.dart';

/// Flags for development and testing.
///
/// [alwaysShowCriticalOnLoad] used to be a plain in-memory static bool, so the
/// Settings > Developer toggle reset to false every time the app was force-killed
/// and reopened. It now persists through SharedPreferences, which means [load]
/// must be called once at startup (in main(), before runApp).
abstract final class DebugFlags {
  static bool alwaysShowCriticalOnLoad = false;

  static const _kAlwaysShowCriticalKey = 'debug_always_show_critical';

  /// Load the saved value from storage. Call once at startup.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    alwaysShowCriticalOnLoad = prefs.getBool(_kAlwaysShowCriticalKey) ?? false;
  }

  /// Normal (false): the critical alert popup appears only for a problem that has
  /// not yet been acknowledged (checked against SuggestionAckStore, which
  /// persists across restarts). Once the action button has been pressed it will
  /// not reappear until that problem clears and recurs.
  ///
  /// Test mode (true): show the popup for every critical alert found, ignoring
  /// any stored acknowledgement. Handy for checking the popup renders correctly
  /// without clearing local storage by hand.
  ///
  /// Use this rather than assigning [alwaysShowCriticalOnLoad] directly from the
  /// UI, so the choice is written to storage and not just held in memory.
  static Future<void> setAlwaysShowCriticalOnLoad(bool value) async {
    alwaysShowCriticalOnLoad = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlwaysShowCriticalKey, value);
  }
}
