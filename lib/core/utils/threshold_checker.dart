import '../models/sensor_reading.dart';
import '../models/threshold_config.dart';

/// Canonical factor keys. These are the same strings the backend uses in
/// `Alert.factor`, so a factor can be matched across client and server.
abstract final class Factors {
  static const co2 = 'co2';
  static const temperature = 'temperature';
  static const humidity = 'humidity';
  static const pm25 = 'pm25';
  static const light = 'light';
  static const noise = 'noise';

  /// The six environmental factors, in the order the Test Plan lists them.
  static const all = [co2, temperature, humidity, pm25, light, noise];
}

/// Status strings used throughout the app and asserted on by the unit tests
/// (Test Plan UTC-02 expects `status == 'normal' | 'warning' | 'critical'`).
abstract final class FactorStatus {
  static const normal = 'normal';
  static const warning = 'warning';
  static const critical = 'critical';
}

/// The verdict for one factor.
class FactorResult {
  final String factor;
  final String status;

  /// The measured value, or null when that sensor reported nothing.
  final double? value;

  /// The threshold the value was compared against — null while normal.
  final double? threshold;

  const FactorResult({
    required this.factor,
    required this.status,
    this.value,
    this.threshold,
  });

  bool get isNormal => status == FactorStatus.normal;
  bool get isWarning => status == FactorStatus.warning;
  bool get isCritical => status == FactorStatus.critical;

  @override
  String toString() => '$factor: $status (value: $value)';
}

/// The result of evaluating a whole [SensorReading] against a
/// [ThresholdConfig]. Returned by [checkThreshold].
class ThresholdResult {
  /// One entry per factor, keyed by the constants in [Factors].
  final Map<String, FactorResult> factors;

  const ThresholdResult(this.factors);

  FactorResult? operator [](String factor) => factors[factor];

  /// Convenience accessors so tests and UI can read `result.co2.status`.
  FactorResult get co2 => factors[Factors.co2]!;
  FactorResult get temperature => factors[Factors.temperature]!;
  FactorResult get humidity => factors[Factors.humidity]!;
  FactorResult get pm25 => factors[Factors.pm25]!;
  FactorResult get light => factors[Factors.light]!;
  FactorResult get noise => factors[Factors.noise]!;

  /// True when at least one factor crossed its critical threshold.
  bool get isCritical => factors.values.any((f) => f.isCritical);

  /// True when at least one factor is in the warning band (but none critical).
  bool get hasWarning => factors.values.any((f) => f.isWarning);

  /// Every factor that is not normal, worst first. Empty when the whole room is
  /// within range (Test Plan UTC-02.01: "no warnings or alerts").
  List<FactorResult> get alertFactors {
    final flagged = factors.values.where((f) => !f.isNormal).toList();
    flagged.sort((a, b) {
      if (a.isCritical == b.isCritical) return 0;
      return a.isCritical ? -1 : 1;
    });
    return flagged;
  }

  /// Just the critical factors — one push notification is sent per entry
  /// (Test Plan STC-05 TC-03 expects separate alerts per factor).
  List<FactorResult> get criticalFactors =>
      factors.values.where((f) => f.isCritical).toList();

  @override
  String toString() => 'ThresholdResult(${factors.values.join(', ')})';
}

/// Compare one sensor reading against the configured thresholds and classify
/// every factor as normal, warning or critical.
///
/// Test Plan reference: UTC-02 (`utils/thresholdChecker.js -> checkThreshold()`).
///
/// A factor whose value is null (no sensor connected, or the backend returned
/// an empty reading) is reported as `normal` rather than being treated as an
/// alert — a missing sensor is not evidence of a bad bedroom.
ThresholdResult checkThreshold(
  SensorReading reading, {
  ThresholdConfig config = ThresholdConfig.defaults,
}) {
  return ThresholdResult({
    Factors.co2: _checkUpperBound(
      Factors.co2,
      reading.co2,
      warning: config.co2Warning,
      critical: config.co2Critical,
    ),
    Factors.temperature: _checkRange(
      Factors.temperature,
      reading.temperature,
      min: config.temperatureMin,
      max: config.temperatureMax,
      criticalMin: config.temperatureCriticalMin,
      criticalMax: config.temperatureCriticalMax,
    ),
    Factors.humidity: _checkRange(
      Factors.humidity,
      reading.humidity,
      min: config.humidityMin,
      max: config.humidityMax,
      criticalMin: config.humidityCriticalMin,
      criticalMax: config.humidityCriticalMax,
    ),
    Factors.pm25: _checkUpperBound(
      Factors.pm25,
      reading.pm25,
      warning: config.pm25Warning,
      critical: config.pm25Critical,
    ),
    Factors.light: _checkUpperBound(
      Factors.light,
      reading.light,
      warning: config.lightWarning,
      critical: config.lightCritical,
    ),
    Factors.noise: _checkUpperBound(
      Factors.noise,
      reading.noise,
      warning: config.noiseWarning,
      critical: config.noiseCritical,
    ),
  });
}

/// Factors that only get worse in one direction: CO2, PM2.5, light, noise.
FactorResult _checkUpperBound(
  String factor,
  double? value, {
  required double warning,
  required double critical,
}) {
  if (value == null) {
    return FactorResult(factor: factor, status: FactorStatus.normal);
  }
  if (value >= critical) {
    return FactorResult(
      factor: factor,
      status: FactorStatus.critical,
      value: value,
      threshold: critical,
    );
  }
  if (value >= warning) {
    return FactorResult(
      factor: factor,
      status: FactorStatus.warning,
      value: value,
      threshold: warning,
    );
  }
  return FactorResult(
      factor: factor, status: FactorStatus.normal, value: value);
}

/// Factors with both a lower and an upper bound: temperature and humidity.
FactorResult _checkRange(
  String factor,
  double? value, {
  required double min,
  required double max,
  required double criticalMin,
  required double criticalMax,
}) {
  if (value == null) {
    return FactorResult(factor: factor, status: FactorStatus.normal);
  }
  if (value > criticalMax) {
    return FactorResult(
      factor: factor,
      status: FactorStatus.critical,
      value: value,
      threshold: criticalMax,
    );
  }
  if (value < criticalMin) {
    return FactorResult(
      factor: factor,
      status: FactorStatus.critical,
      value: value,
      threshold: criticalMin,
    );
  }
  if (value > max) {
    return FactorResult(
      factor: factor,
      status: FactorStatus.warning,
      value: value,
      threshold: max,
    );
  }
  if (value < min) {
    return FactorResult(
      factor: factor,
      status: FactorStatus.warning,
      value: value,
      threshold: min,
    );
  }
  return FactorResult(
      factor: factor, status: FactorStatus.normal, value: value);
}
