import 'package:flutter_test/flutter_test.dart';

import 'package:sleepsense_app/core/models/sensor_reading.dart';
import 'package:sleepsense_app/core/models/threshold_config.dart';
import 'package:sleepsense_app/core/utils/threshold_checker.dart';

/// Test Plan Chapter 3.2 — UTC-02 checkThreshold
///
/// Component: lib/core/utils/threshold_checker.dart -> checkThreshold()
///
/// ── Note on the threshold configuration ────────────────────────────────────
/// UTC-02's prerequisite is "Threshold configuration is loaded with predefined
/// acceptable ranges", but the Test Plan never states the numbers. The TD
/// values below only classify the way the Test Plan says they do under a
/// configuration more permissive than the bedroom defaults SleepSense ships
/// (e.g. TD-01 calls light 320 lux and noise 45.2 dB "normal", while the
/// shipped defaults warn above 50 lux and 40 dB).
///
/// So the cases below are run twice:
///   * against [testPlanConfig], reconstructed from the TD data, to verify the
///     behaviour the Test Plan specifies; and
///   * against [ThresholdConfig.defaults], to verify the behaviour the app
///     actually ships.
/// The pairing keeps the Test Plan satisfied without silently loosening the
/// production thresholds. See the handover note about revising TD-01/TD-03.
const testPlanConfig = ThresholdConfig(
  co2Warning: 1000,
  co2Critical: 2000,
  temperatureMin: 18,
  temperatureMax: 28,
  temperatureCriticalMin: 15,
  temperatureCriticalMax: 32,
  humidityMin: 30,
  humidityMax: 70,
  humidityCriticalMin: 20,
  humidityCriticalMax: 80,
  pm25Warning: 35,
  pm25Critical: 75,
  lightWarning: 400,
  lightCritical: 800,
  noiseWarning: 50,
  noiseCritical: 85,
);

void main() {
  // ── Environment Test Data ──────────────────────────────────────────────
  // TD-01: all within normal range.
  const td01 = SensorReading(
    co2: 850,
    temperature: 27.5,
    humidity: 65.0,
    pm25: 12.3,
    light: 320,
    noise: 45.2,
  );

  // TD-02: all exceed the critical threshold.
  const td02 = SensorReading(
    co2: 2100,
    temperature: 36.0,
    humidity: 85.0,
    pm25: 75.0,
    light: 950,
    noise: 90.0,
  );

  // TD-03: CO2 in the warning range only.
  const td03 = SensorReading(
    co2: 1600,
    temperature: 27.5,
    humidity: 65.0,
    pm25: 12.3,
    light: 320,
    noise: 45.2,
  );

  group('UTC-02.01 Test-checkThreshold.allNormal', () {
    test('every factor is normal when all values are within range', () {
      // Step 1: call checkThreshold() with TD-01.
      final result = checkThreshold(td01, config: testPlanConfig);

      // Step 2: every factor's status equals 'normal'.
      for (final factor in Factors.all) {
        expect(result[factor]!.status, FactorStatus.normal,
            reason: '$factor should be normal');
      }

      // Step 3: isCritical is false, and there are no warnings or alerts.
      expect(result.isCritical, isFalse);
      expect(result.hasWarning, isFalse);
      expect(result.alertFactors, isEmpty);
    });
  });

  group('UTC-02.02 Test-checkThreshold.allCritical', () {
    test('every factor is critical when all values exceed critical limits', () {
      // Step 1: call checkThreshold() with TD-02.
      final result = checkThreshold(td02, config: testPlanConfig);

      // Step 2: every factor's status equals 'critical'.
      for (final factor in Factors.all) {
        expect(result[factor]!.status, FactorStatus.critical,
            reason: '$factor should be critical');
      }

      // Steps 3-4: isCritical is true and alertFactors contains all 6 factors.
      expect(result.isCritical, isTrue);
      expect(result.alertFactors.length, 6);
      expect(result.criticalFactors.length, 6);
    });

    test('TD-02 is also critical on every factor under the shipped defaults',
        () {
      final result = checkThreshold(td02);

      for (final factor in Factors.all) {
        expect(result[factor]!.status, FactorStatus.critical,
            reason: '$factor should be critical');
      }
      expect(result.alertFactors.length, 6);
    });
  });

  group('UTC-02.03 Test-checkThreshold.partialWarning', () {
    test('only co2 is warning when only its value is in the warning range', () {
      // Step 1: call checkThreshold() with TD-03.
      final result = checkThreshold(td03, config: testPlanConfig);

      // Step 2: co2 status equals 'warning'.
      expect(result.co2.status, FactorStatus.warning);
      expect(result.co2.threshold, testPlanConfig.co2Warning);

      // Step 3: all other factors are normal.
      for (final factor in Factors.all.where((f) => f != Factors.co2)) {
        expect(result[factor]!.status, FactorStatus.normal,
            reason: '$factor should be normal');
      }

      // Step 4: isCritical is false.
      expect(result.isCritical, isFalse);
      expect(result.alertFactors.length, 1);
      expect(result.alertFactors.single.factor, Factors.co2);
    });

    test('co2 1600 ppm is a warning under the shipped defaults too', () {
      final result = checkThreshold(const SensorReading(co2: 1600));

      expect(result.co2.status, FactorStatus.warning);
      expect(result.isCritical, isFalse);
    });
  });

  group('boundary and missing-sensor behaviour', () {
    test('a value exactly on the warning threshold counts as warning', () {
      final result = checkThreshold(const SensorReading(co2: 1000));
      expect(result.co2.status, FactorStatus.warning);
    });

    test('a value exactly on the critical threshold counts as critical', () {
      final result = checkThreshold(const SensorReading(co2: 2000));
      expect(result.co2.status, FactorStatus.critical);
    });

    test('temperature below the critical minimum is critical', () {
      final result = checkThreshold(const SensorReading(temperature: 12));
      expect(result.temperature.status, FactorStatus.critical);
      expect(result.temperature.threshold,
          ThresholdConfig.defaults.temperatureCriticalMin);
    });

    test('humidity below the comfort minimum is a warning, not critical', () {
      final result = checkThreshold(const SensorReading(humidity: 25));
      expect(result.humidity.status, FactorStatus.warning);
      expect(result.isCritical, isFalse);
    });

    test('a null factor is reported normal rather than raising an alert', () {
      final result = checkThreshold(const SensorReading());

      for (final factor in Factors.all) {
        expect(result[factor]!.status, FactorStatus.normal);
        expect(result[factor]!.value, isNull);
      }
      expect(result.alertFactors, isEmpty);
    });

    test('custom thresholds from the user override the defaults', () {
      const strict = ThresholdConfig(co2Warning: 600, co2Critical: 900);
      final result = checkThreshold(const SensorReading(co2: 850),
          config: strict);

      expect(result.co2.status, FactorStatus.warning);
    });
  });
}
