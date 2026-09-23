import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_models.dart';
import '../../features/patterns/models/pattern_models.dart';

/// Outcome of asking the backend to build a morning report.
enum ReportResult {
  success, // built, and there was data behind it
  noData, // built, but no sensor data existed for that window
  failed, // could not reach the backend, or it errored
}

/// Every backend call lives here.
///
/// All endpoints wrap their payload in `{ success, message, data }`. This
/// service unwraps that and returns only `data`, or throws when `success` is
/// false.
class ApiService {
  final http.Client _client;
  final Duration timeout;

  ApiService({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  /// The latest sensor reading.
  Future<SensorDataDto?> fetchLatestSensor({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.sensorLatest(id));
    if (data == null) return null;
    return SensorDataDto.fromJson(data as Map<String, dynamic>);
  }

  /// Pre-sleep advice, as a list of sentences.
  Future<List<String>> fetchPreSleepSuggestions({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.preSleep(id));
    if (data is List) return data.map((e) => e.toString()).toList();
    return const [];
  }

  /// Recent alerts — the full history including resolved ones, for the Alerts log.
  Future<List<AlertDto>> fetchRecentAlerts(
      {String? deviceId, int limit = 20}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.alertsRecent(id, limit: limit));
    if (data is List) {
      return data
          .map((e) => AlertDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  /// Alerts that are genuinely still active (not yet resolved). Used for the
  /// Home badge and for deciding whether to force the critical popup, instead of
  /// [fetchRecentAlerts], which is pure history and includes problems that have
  /// since cleared.
  Future<List<AlertDto>> fetchActiveAlerts({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.alertsActive(id));
    if (data is List) {
      return data
          .map((e) => AlertDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  /// The most recent morning report.
  Future<MorningReportDto?> fetchLatestReport({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.reportLatest(id));
    if (data == null) return null;
    return MorningReportDto.fromJson(data as Map<String, dynamic>);
  }

  /// Several nights of morning reports, for the Morning Report history screen.
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

  /// The multi-night pattern analysis behind the Sleep Patterns screen.
  ///
  /// Test Plan reference: STC-04. The response carries the clustered nights and
  /// the detected patterns as well as the advice, so the screen can show the
  /// evidence for each recommendation.
  Future<PatternAnalysis> fetchSmartSuggestions({
    String? deviceId,
    int nights = 14,
  }) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.smartSuggestions(id, nights: nights));
    if (data is Map<String, dynamic>) return PatternAnalysis.fromJson(data);
    return PatternAnalysis.empty;
  }

  /// Ask the backend to build a report for a sleep window.
  Future<ReportResult> generateReport({
    String? deviceId,
    required int sleepStart,
    required int sleepEnd,
  }) async {
    final id = deviceId ?? ApiConfig.deviceId;
    try {
      final res = await _client
          .post(Uri.parse(ApiConfig.reportGenerate(id, sleepStart, sleepEnd)))
          .timeout(timeout);
      if (res.statusCode != 200) return ReportResult.failed;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (body['success'] != true) return ReportResult.failed;
      // Was there any sensor data in that window? A cluster of UNKNOWN means no.
      final data = body['data'];
      if (data is Map && data['environmentCluster'] == 'UNKNOWN') {
        return ReportResult.noData;
      }
      return ReportResult.success;
    } catch (e) {
      return ReportResult.failed;
    }
  }

  /// Delete a single morning report.
  Future<bool> deleteReport(String reportId) async {
    try {
      final res = await _client
          .delete(Uri.parse(ApiConfig.reportDelete(reportId)))
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// This device's current thresholds — custom if any, otherwise the defaults.
  Future<ThresholdSettingsDto> fetchThresholds({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    final data = await _getData(ApiConfig.thresholds(id));
    return ThresholdSettingsDto.fromJson(data as Map<String, dynamic>);
  }

  /// Save the user's custom thresholds. Throws [ApiException] when the values
  /// do not make sense (warning above critical, for instance) — the backend
  /// sends an explanatory message back.
  Future<ThresholdSettingsDto> updateThresholds(
      ThresholdSettingsDto settings) async {
    late final http.Response res;
    try {
      res = await _client
          .put(
            Uri.parse(ApiConfig.thresholds(settings.deviceId)),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(settings.toJson()),
          )
          .timeout(timeout);
    } catch (e) {
      throw ApiException('Could not reach the backend: $e');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException((body['message'] ?? 'Could not save').toString());
    }
    return ThresholdSettingsDto.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Reset this device's thresholds back to the system defaults.
  Future<ThresholdSettingsDto> resetThresholds({String? deviceId}) async {
    final id = deviceId ?? ApiConfig.deviceId;
    late final http.Response res;
    try {
      res = await _client
          .delete(Uri.parse(ApiConfig.thresholds(id)))
          .timeout(timeout);
    } catch (e) {
      throw ApiException('Could not reach the backend: $e');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException((body['message'] ?? 'Could not reset').toString());
    }
    return ThresholdSettingsDto.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  /// GET the URL and unwrap `{ success, message, data }`.
  Future<dynamic> _getData(String url) async {
    late final http.Response res;
    try {
      res = await _client.get(Uri.parse(url)).timeout(timeout);
    } catch (e) {
      throw ApiException('Could not reach the backend: $e');
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
