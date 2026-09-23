import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';
import '../network/api_config.dart';

/// Thrown when the latest reading cannot be retrieved. The message is never
/// null or empty, which UTC-01.03 asserts on.
class SensorServiceException implements Exception {
  final String message;
  SensorServiceException(this.message);

  @override
  String toString() => message;
}

/// Retrieves sensor readings from the backend.
///
/// Test Plan reference: UTC-01 (`services/sensorService.js -> getSensorData()`).
/// The `http.Client` is injected so the unit tests can supply a `MockClient`
/// instead of hitting a real server.
class SensorService {
  final http.Client _client;
  final Duration timeout;
  final String? deviceId;

  SensorService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    this.deviceId,
  }) : _client = client ?? http.Client();

  /// Fetch the most recent reading for this device.
  ///
  /// - A populated response is parsed into a [SensorReading] (UTC-01.01).
  /// - A response whose fields are all null returns a reading with all null
  ///   fields and does not throw (UTC-01.02).
  /// - A network failure throws [SensorServiceException] with a non-empty
  ///   message (UTC-01.03).
  Future<SensorReading> getSensorData() async {
    final id = deviceId ?? ApiConfig.deviceId;
    final url = Uri.parse(ApiConfig.sensorLatest(id));

    late final http.Response response;
    try {
      response = await _client.get(url).timeout(timeout);
    } catch (e) {
      throw SensorServiceException('Could not reach the backend: $e');
    }

    if (response.statusCode != 200) {
      throw SensorServiceException(
          'Request failed with HTTP ${response.statusCode}');
    }

    final dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw SensorServiceException('Malformed response from backend: $e');
    }

    final payload = _unwrap(body);
    if (payload == null) return const SensorReading();
    return SensorReading.fromJson(payload);
  }

  /// Production endpoints wrap their payload in `{ success, message, data }`,
  /// while the mocked responses in the unit tests return the reading directly.
  /// Accept both shapes so one implementation covers the real API and the mock.
  Map<String, dynamic>? _unwrap(dynamic body) {
    if (body is! Map<String, dynamic>) return null;

    if (body.containsKey('success') && body.containsKey('data')) {
      if (body['success'] != true) {
        throw SensorServiceException(
            (body['message'] ?? 'Backend reported a failure').toString());
      }
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    }
    return body;
  }

  void dispose() => _client.close();
}
