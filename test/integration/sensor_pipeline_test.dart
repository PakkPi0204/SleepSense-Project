import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sleepsense_app/core/models/sensor_reading.dart';
import 'package:sleepsense_app/core/pipeline/sensor_pipeline.dart';
import 'package:sleepsense_app/core/services/alert_service.dart';
import 'package:sleepsense_app/core/services/sensor_service.dart';
import 'package:sleepsense_app/core/utils/threshold_checker.dart';

/// Test Plan Chapter 4 — ITC-01 Test-SensorPipeline
///
/// Component: getSensorData() -> checkThreshold() -> sendAlert()
///
/// The FCM delivery step is mocked by [_RecordingAlertDispatcher], which counts
/// how many times sendAlert() was invoked and what it produced.
class _RecordingAlertDispatcher implements AlertDispatcher {
  int callCount = 0;
  final List<AlertNotification> sent = [];

  final AlertDispatcher _real = const FcmAlertDispatcher();

  @override
  Future<List<AlertNotification>> sendAlert(
    SensorReading reading,
    ThresholdResult result,
  ) async {
    callCount++;
    final notifications = await _real.sendAlert(reading, result);
    sent.addAll(notifications);
    return notifications;
  }
}

void main() {
  // ── Environment Test Data ──────────────────────────────────────────────
  final td01 = {
    'co2': 850,
    'temperature': 22.0,
    'humidity': 50.0,
    'pm25': 12.3,
    'light': 12,
    'noise': 32.0,
    'timestamp': DateTime.utc(2026, 9, 14, 23, 0).toIso8601String(),
  };

  final td02 = {
    'co2': 2100,
    'temperature': 36.0,
    'humidity': 85.0,
    'pm25': 75.0,
    'light': 950,
    'noise': 90.0,
    'timestamp': DateTime.utc(2026, 9, 14, 23, 30).toIso8601String(),
  };

  SensorPipeline buildPipeline(
    Map<String, dynamic> payload,
    _RecordingAlertDispatcher dispatcher,
  ) {
    // Step 1: mock HTTP GET /api/sensor/latest.
    final client = MockClient((_) async => http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    return SensorPipeline(
      sensorService: SensorService(client: client),
      // Step 2: mock FCM sendAlert().
      alertDispatcher: dispatcher,
    );
  }

  test('ITC-01 TC-01: normal data flows through without triggering an alert',
      () async {
    // Step 3: configure the mock to return TD-01 and run the pipeline.
    final dispatcher = _RecordingAlertDispatcher();
    final outcome = await buildPipeline(td01, dispatcher).run();

    // checkThreshold result: status == 'normal' on every factor.
    for (final factor in Factors.all) {
      expect(outcome.result[factor]!.status, FactorStatus.normal,
          reason: '$factor should be normal');
    }
    expect(outcome.result.isCritical, isFalse);

    // sendAlert is NOT called.
    expect(dispatcher.callCount, 0);
    expect(outcome.alertSent, isFalse);
    expect(outcome.notifications, isEmpty);
  });

  test('ITC-01 TC-02: critical data flows through and triggers an alert',
      () async {
    // Step 4: configure the mock to return TD-02 and run the pipeline.
    final dispatcher = _RecordingAlertDispatcher();
    final outcome = await buildPipeline(td02, dispatcher).run();

    // checkThreshold result: isCritical == true.
    expect(outcome.result.isCritical, isTrue);

    // sendAlert IS called — the FCM mock is invoked exactly once.
    expect(dispatcher.callCount, 1);
    expect(outcome.alertSent, isTrue);
  });

  test(
      'STC-05 TC-03 at pipeline level: one notification per critical factor, '
      'naming the factor and its recorded value', () async {
    final dispatcher = _RecordingAlertDispatcher();
    // Only CO2 and noise are critical here.
    final outcome = await buildPipeline({
      'co2': 2150,
      'temperature': 22.0,
      'humidity': 50.0,
      'pm25': 10.0,
      'light': 8,
      'noise': 88.0,
    }, dispatcher)
        .run();

    // sendAlert is still invoked once for the run...
    expect(dispatcher.callCount, 1);
    // ...but it emits a separate notification per affected factor.
    expect(outcome.notifications.length, 2);

    final factors = outcome.notifications.map((n) => n.factor).toSet();
    expect(factors, {Factors.co2, Factors.noise});

    final co2Message = outcome.notifications
        .firstWhere((n) => n.factor == Factors.co2)
        .message;
    expect(co2Message, contains('CO2'));
    expect(co2Message, contains('2150'));
  });

  test('a pipeline run surfaces backend failures instead of swallowing them',
      () async {
    final client = MockClient(
        (_) async => throw const http.ClientException('Connection refused'));
    final pipeline = SensorPipeline(
      sensorService: SensorService(client: client),
      alertDispatcher: _RecordingAlertDispatcher(),
    );

    expect(pipeline.run(), throwsA(isA<SensorServiceException>()));
  });
}
