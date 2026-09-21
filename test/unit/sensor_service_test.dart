import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sleepsense_app/core/models/sensor_reading.dart';
import 'package:sleepsense_app/core/services/sensor_service.dart';

/// Test Plan Chapter 3.1 — UTC-01 getSensorData
///
/// Component: lib/core/services/sensor_service.dart -> getSensorData()
/// (the Test Plan names this `services/sensorService.js`; the project is
/// Flutter, so the Dart module of the same responsibility is under test).
void main() {
  // ── Environment Test Data ──────────────────────────────────────────────
  // TD-01: a populated reading.
  final td01 = {
    'co2': 850,
    'temperature': 27.5,
    'humidity': 65.0,
    'pm25': 12.3,
    'light': 320,
    'noise': 45.2,
    'timestamp': DateTime.utc(2026, 9, 14, 22, 30).toIso8601String(),
  };

  // TD-02: backend replied, but has no reading to give.
  const td02 = {
    'co2': null,
    'temperature': null,
    'humidity': null,
    'pm25': null,
    'light': null,
    'noise': null,
    'timestamp': null,
  };

  group('UTC-01.01 Test-getSensorData.latestReading', () {
    test('returns the latest sensor reading correctly', () async {
      // Step 1: mock HTTP GET /api/sensor/latest to return TD-01.
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/sensor/latest');
        return http.Response(jsonEncode(td01), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final service = SensorService(client: client);

      // Step 2: call getSensorData().
      final reading = await service.getSensorData();

      // Step 3: every field matches TD-01.
      expect(reading.co2, 850);
      expect(reading.temperature, 27.5);
      expect(reading.humidity, 65.0);
      expect(reading.pm25, 12.3);
      expect(reading.light, 320);
      expect(reading.noise, 45.2);
      expect(reading.timestamp, td01['timestamp']);
    });

    test('also unwraps the production { success, message, data } envelope',
        () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'success': true, 'message': 'ok', 'data': td01}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final reading = await SensorService(client: client).getSensorData();

      expect(reading.co2, 850);
      expect(reading.noise, 45.2);
    });

    test('maps the backend field names lightIntensity / noiseLevel', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'lightIntensity': 12.0, 'noiseLevel': 31.0}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final reading = await SensorService(client: client).getSensorData();

      expect(reading.light, 12.0);
      expect(reading.noise, 31.0);
    });
  });

  group('UTC-01.02 Test-getSensorData.emptyResponse', () {
    test('returns null values when no data is available, without throwing',
        () async {
      // Step 1: mock returns TD-02.
      final client = MockClient((_) async => http.Response(
            jsonEncode(td02),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final service = SensorService(client: client);

      // Steps 2-4: call, assert all fields null, assert no exception thrown.
      await expectLater(service.getSensorData(), completes);
      final SensorReading reading = await service.getSensorData();

      expect(reading.co2, isNull);
      expect(reading.temperature, isNull);
      expect(reading.humidity, isNull);
      expect(reading.pm25, isNull);
      expect(reading.light, isNull);
      expect(reading.noise, isNull);
      expect(reading.isEmpty, isTrue);
    });
  });

  group('UTC-01.03 Test-getSensorData.networkError', () {
    test('throws an error with a non-null message on network failure',
        () async {
      // Step 1: mock rejects with a network error.
      final client = MockClient(
          (_) async => throw const http.ClientException('Connection refused'));
      final service = SensorService(client: client);

      // Steps 2-3: call inside try/catch, assert the message is not null.
      Object? caught;
      try {
        await service.getSensorData();
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught, isA<SensorServiceException>());
      expect((caught as SensorServiceException).message, isNotEmpty);
    });

    test('throws when the backend answers with a non-200 status', () async {
      final client = MockClient((_) async => http.Response('boom', 500));

      expect(
        () => SensorService(client: client).getSensorData(),
        throwsA(isA<SensorServiceException>()),
      );
    });
  });
}
