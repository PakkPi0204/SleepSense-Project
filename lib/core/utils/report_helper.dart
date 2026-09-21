import '../models/sensor_reading.dart';
import 'threshold_checker.dart';

/// Average / minimum / maximum for a single environmental factor over a set of
/// readings. All three are null when no reading carried a value for it.
class FactorSummary {
  final double? avg;
  final double? min;
  final double? max;

  const FactorSummary({this.avg, this.min, this.max});

  static const empty = FactorSummary();

  @override
  String toString() => '{avg: $avg, min: $min, max: $max}';
}

/// The aggregate of one night's readings, returned by [calculateDailyAverage].
///
/// Test Plan reference: UTC-03 (`utils/reportHelper.js -> calculateDailyAverage()`).
class DailyReport {
  final FactorSummary co2;
  final FactorSummary temperature;
  final FactorSummary humidity;
  final FactorSummary pm25;
  final FactorSummary light;
  final FactorSummary noise;

  /// How many readings went into this report.
  final int sampleCount;

  /// How many of those readings detected motion.
  final int motionEventCount;

  const DailyReport({
    required this.co2,
    required this.temperature,
    required this.humidity,
    required this.pm25,
    required this.light,
    required this.noise,
    required this.sampleCount,
    required this.motionEventCount,
  });

  /// Look a factor up by the keys in [Factors].
  FactorSummary operator [](String factor) {
    switch (factor) {
      case Factors.co2:
        return co2;
      case Factors.temperature:
        return temperature;
      case Factors.humidity:
        return humidity;
      case Factors.pm25:
        return pm25;
      case Factors.light:
        return light;
      case Factors.noise:
        return noise;
      default:
        return FactorSummary.empty;
    }
  }

  /// LOW / MODERATE / HIGH, using the same cut-offs as the backend generator.
  String get motionPattern {
    if (motionEventCount < 5) return 'LOW';
    if (motionEventCount < 15) return 'MODERATE';
    return 'HIGH';
  }
}

/// Aggregate a night's worth of readings into per-factor avg / min / max.
///
/// Returns null when [readings] is empty, which is what UTC-03.02 asks for
/// ("Returns null or ... for all factors. No exception is thrown"). Null
/// entries inside individual readings are skipped rather than counted as zero,
/// so one dropped sensor does not drag the whole average down.
DailyReport? calculateDailyAverage(List<SensorReading> readings) {
  if (readings.isEmpty) return null;

  return DailyReport(
    co2: _summarise(readings, (r) => r.co2),
    temperature: _summarise(readings, (r) => r.temperature),
    humidity: _summarise(readings, (r) => r.humidity),
    pm25: _summarise(readings, (r) => r.pm25),
    light: _summarise(readings, (r) => r.light),
    noise: _summarise(readings, (r) => r.noise),
    sampleCount: readings.length,
    motionEventCount:
        readings.where((r) => r.motionDetected == true).length,
  );
}

FactorSummary _summarise(
  List<SensorReading> readings,
  double? Function(SensorReading) pick,
) {
  final values = <double>[];
  for (final reading in readings) {
    final value = pick(reading);
    if (value != null) values.add(value);
  }
  if (values.isEmpty) return FactorSummary.empty;

  var min = values.first;
  var max = values.first;
  var sum = 0.0;
  for (final value in values) {
    if (value < min) min = value;
    if (value > max) max = value;
    sum += value;
  }
  return FactorSummary(avg: sum / values.length, min: min, max: max);
}
