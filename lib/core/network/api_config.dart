import 'package:flutter/foundation.dart';

/// การตั้งค่าการเชื่อมต่อ backend
///
/// เปลี่ยน baseUrl ตามที่รันทดสอบ:
/// - Android emulator : http://10.0.2.2:8080
/// - มือถือจริง       : http://<IP เครื่อง backend>:8080  (WiFi เดียวกัน)
/// - เว็บ / เดสก์ท็อป  : http://localhost:8080
class ApiConfig {
  ApiConfig._();

  /// device id ที่ใช้คู่กับ ESP32 (ต้องตรงกับที่ ESP32 ส่งมา)
  static const String deviceId = 'test-device-01';

  /// ⚠️ แก้ค่านี้เมื่อทดสอบบนมือถือจริง ให้เป็น IP ของเครื่องที่รัน backend
  /// เช่น 'http://192.168.1.42:8080'
  static const String _manualOverride = '';

  /// เลือก baseUrl อัตโนมัติตาม platform
  static String get baseUrl {
    if (_manualOverride.isNotEmpty) return _manualOverride;

    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // Android emulator ใช้ 10.0.2.2 แทน localhost ของเครื่อง host
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
  static String reportLatest(String id) => '$baseUrl/api/report/latest?deviceId=$id';
  static String reportHistory(String id, {int limit = 30}) =>
      '$baseUrl/api/report/history?deviceId=$id&limit=$limit';
  static String reportDelete(String reportId) => '$baseUrl/api/report/$reportId';
  static String reportGenerate(String id, int sleepStart, int sleepEnd) =>
      '$baseUrl/api/report/generate?deviceId=$id&sleepStart=$sleepStart&sleepEnd=$sleepEnd';
}
