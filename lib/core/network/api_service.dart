import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_models.dart';

/// ชั้นเรียก backend API ทั้งหมด
///
/// ทุก endpoint ของ backend ห่อ response ด้วย { success, message, data }
/// service นี้จะ unwrap ให้ แล้วคืนเฉพาะ data (หรือ throw ถ้า success=false)
class ApiService {
  final http.Client _client;
  final Duration timeout;

  ApiService({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  /// ค่า sensor ล่าสุด
  Future<SensorDataDto?> fetchLatestSensor({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.sensorLatest(id));
    if (data == null) return null;
    return SensorDataDto.fromJson(data as Map<String, dynamic>);
  }

  /// คำแนะนำก่อนนอน (list ของข้อความ)
  Future<List<String>> fetchPreSleepSuggestions({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.preSleep(id));
    if (data is List) return data.map((e) => e.toString()).toList();
    return const [];
  }

  /// alert ล่าสุด
  Future<List<AlertDto>> fetchRecentAlerts({String? deviceId, int limit = 20}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.alertsRecent(id, limit: limit));
    if (data is List) {
      return data
          .map((e) => AlertDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  /// morning report ล่าสุด
  Future<MorningReportDto?> fetchLatestReport({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.reportLatest(id));
    if (data == null) return null;
    return MorningReportDto.fromJson(data as Map<String, dynamic>);
  }

  /// morning report ย้อนหลังหลายคืน (หน้า Stats)
  Future<List<MorningReportDto>> fetchReportHistory(
      {String? deviceId, int limit = 30}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.reportHistory(id, limit: limit));
    if (data is List) {
      return data
          .map((e) => MorningReportDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  // ──────────────────────────────────────────────
  /// ยิง GET แล้ว unwrap { success, message, data }
  Future<dynamic> _getData(String url) async {
    late final http.Response res;
    try {
      res = await _client.get(Uri.parse(url)).timeout(timeout);
    } catch (e) {
      throw ApiException('เชื่อมต่อ backend ไม่ได้: $e');
    }

    if (res.statusCode != 200) {
      throw ApiException('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final success = body['success'] == true;
    if (!success) {
      throw ApiException((body['message'] ?? 'Unknown error').toString());
    }
    return body['data'];
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
