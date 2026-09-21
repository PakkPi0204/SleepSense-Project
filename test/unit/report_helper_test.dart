import 'package:flutter_test/flutter_test.dart';

import 'package:sleepsense_app/core/models/sensor_reading.dart';
import 'package:sleepsense_app/core/utils/report_helper.dart';

/// Test Plan Chapter 3.3 — UTC-03 calculateDailyAverage
///
/// Component: lib/core/utils/report_helper.dart -> calculateDailyAverage()
void main() {
  // ── Environment Test Data ──────────────────────────────────────────────
  // TD-01: three readings.
  const td01 = <SensorReading>[
    SensorReading(
        co2: 800,
        temperature: 26.0,
        humidity: 60.0,
        pm25: 10.0,
        light: 300,
        noise: 40.0),
    SensorReading(
        co2: 900,
        temperature: 28.0,
        humidity: 70.0,
        pm25: 14.0,
        light: 340,
        noise: 50.0),
    SensorReading(
        co2: 1000,
        temperature: 30.0,
        humidity: 80.0,
        pm25: 18.0,
        light: 380,
        noise: 60.0),
  ];

  // TD-02: empty array — no readings.
  const td02 = <SensorReading>[];

  group('UTC-03.01 Test-calculateDailyAverage.normalData', () {
    test('returns the correct avg/min/max from 3 readings', () {
      // Step 1: call calculateDailyAverage() with TD-01.
      final report = calculateDailyAverage(td01);

      // Step 2: every factor's avg, min and max match the expected values.
      expect(report, isNotNull);

      expect(report!.co2.avg, closeTo(900, 0.001));
      expect(report.co2.min, 800);
      expect(report.co2.max, 1000);

      expect(report.temperature.avg, closeTo(28.0, 0.001));
      expect(report.temperature.min, 26.0);
      expect(report.temperature.max, 30.0);

      expect(report.humidity.avg, closeTo(70.0, 0.001));
      expect(report.humidity.min, 60.0);
      expect(report.humidity.max, 80.0);

      expect(report.pm25.avg, closeTo(14.0, 0.001));
      expect(report.pm25.min, 10.0);
      expect(report.pm25.max, 18.0);

      expect(report.light.avg, closeTo(340, 0.001));
      expect(report.light.min, 300);
      expect(report.light.max, 380);

      expect(report.noise.avg, closeTo(50.0, 0.001));
      expect(report.noise.min, 40.0);
      expect(report.noise.max, 60.0);

      expect(report.sampleCount, 3);
    });

    test('a single reading averages to itself', () {
      final report = calculateDailyAverage(const [SensorReading(co2: 742)]);

      expect(report!.co2.avg, 742);
      expect(report.co2.min, 742);
      expect(report.co2.max, 742);
    });

    test('null values are skipped rather than counted as zero', () {
      final report = calculateDailyAverage(const [
        SensorReading(co2: 800),
        SensorReading(co2: null), // sensor dropped out for this sample
        SensorReading(co2: 1000),
      ]);

      expect(report!.co2.avg, closeTo(900, 0.001));
      expect(report.co2.min, 800);
      expect(report.co2.max, 1000);
    });

    test('a factor with no values anywhere summarises to all nulls', () {
      final report = calculateDailyAverage(const [SensorReading(co2: 800)]);

      expect(report!.noise.avg, isNull);
      expect(report.noise.min, isNull);
      expect(report.noise.max, isNull);
    });

    test('motion events are counted and classified', () {
      final report = calculateDailyAverage(const [
        SensorReading(motionDetected: true),
        SensorReading(motionDetected: true),
        SensorReading(motionDetected: false),
      ]);

      expect(report!.motionEventCount, 2);
      expect(report.motionPattern, 'LOW');
    });
  });

  group('UTC-03.02 Test-calculateDailyAverage.emptyArray', () {
    test('handles empty input gracefully and throws nothing', () {
      // Steps 1-3: call with TD-02, assert the result is null, assert no throw.
      expect(() => calculateDailyAverage(td02), returnsNormally);

      final report = calculateDailyAverage(td02);
      expect(report, isNull);
    });
  });
}
