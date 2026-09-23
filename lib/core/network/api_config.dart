import 'package:flutter/foundation.dart';

/// Backend connection settings.
///
/// Set baseUrl to match where you are running:
/// - Android emulator : http://10.0.2.2:8080
/// - Physical phone   : http://<backend machine IP>:8080  (same Wi-Fi)
/// - Web / desktop    : http://localhost:8080
class ApiConfig {
  ApiConfig._();

  /// Device id paired with the ESP32 — must match what the ESP32 sends.
  static const String deviceId = 'test-device-01';

  /// Set this when testing on a physical phone: the IP of the machine running
  /// the backend, e.g. 'http://192.168.1.42:8080'.
  static const String _manualOverride = '';

  /// Picks a baseUrl automatically based on the platform.
  static String get baseUrl {
    if (_manualOverride.isNotEmpty) return _manualOverride;

    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // The Android emulator reaches the host machine at 10.0.2.2, not localhost.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
        return 'http://localhost:8080';
      default:
        return 'http://localhost:8080';
    }
  }

  // Endpoints
  static String sensorLatest(String id) => '$baseUrl/api/sensor/latest?deviceId=$id';
  static String preSleep(String id) => '$baseUrl/api/sensor/presleep?deviceId=$id';
  static String alertsRecent(String id, {int limit = 20}) =>
      '$baseUrl/api/alerts/recent?deviceId=$id&limit=$limit';
  static String alertsActive(String id) =>
      '$baseUrl/api/alerts/active?deviceId=$id';
  static String reportLatest(String id) => '$baseUrl/api/report/latest?deviceId=$id';
  static String reportHistory(String id, {int limit = 30}) =>
      '$baseUrl/api/report/history?deviceId=$id&limit=$limit';
  static String reportDelete(String reportId) => '$baseUrl/api/report/$reportId';
  static String reportGenerate(String id, int sleepStart, int sleepEnd) =>
      '$baseUrl/api/report/generate?deviceId=$id&sleepStart=$sleepStart&sleepEnd=$sleepEnd';
  static String thresholds(String id) => '$baseUrl/api/thresholds?deviceId=$id';
  static String smartSuggestions(String id, {int nights = 14}) =>
      '$baseUrl/api/suggestions/smart?deviceId=$id&nights=$nights';
}
