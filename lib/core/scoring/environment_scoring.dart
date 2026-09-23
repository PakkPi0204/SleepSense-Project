import '../network/api_models.dart';

/// The single sleep-environment scoring formula, shared by Home (Sleep
/// Environment Score) and Sleep (Sleep Readiness), so the two screens cannot
/// show different numbers for the same reading.
///
/// DashboardMapper used to deduct points (start at 100, subtract a chunk per
/// warning or critical), while SleepMapper scaled linearly (100 while optimal,
/// down to 0 at critical). The two disagreed even on identical thresholds, so
/// they are merged here into the linear formula and both mappers call it.
class EnvironmentScoring {
  EnvironmentScoring._();

  /// Score for values that only get worse in one direction (CO2 / PM2.5 / Light /
  /// Noise): a full 100 while at or below the warning level, falling linearly to
  /// 0 at the critical level and staying there.
  static double upperScore(double v, double warning, double critical) {
    if (v <= warning) return 100;
    if (critical <= warning) return 0; // guards against divide-by-zero on bad config
    if (v >= critical) return 0;
    final ratio = (v - warning) / (critical - warning);
    return (100 * (1 - ratio)).clamp(0, 100);
  }

  /// Score for values with both a lower and an upper bound (Temperature /
  /// Humidity): 100 inside [min, max], falling linearly to 0 at whichever
  /// critical bound it is heading towards.
  static double rangeScore(
      double v, double min, double max, double criticalMin, double criticalMax) {
    if (v >= min && v <= max) return 100;
    if (v < min) {
      if (criticalMin >= min) return 0;
      if (v <= criticalMin) return 0;
      final ratio = (min - v) / (min - criticalMin);
      return (100 * (1 - ratio)).clamp(0, 100);
    }
    if (criticalMax <= max) return 0;
    if (v >= criticalMax) return 0;
    final ratio = (v - max) / (criticalMax - max);
    return (100 * (1 - ratio)).clamp(0, 100);
  }

  /// The four sub-scores (Room / Air / Light / Sound) plus an overall score for
  /// one reading, against the user's thresholds (or the defaults when none are
  /// supplied). Called from both DashboardMapper and SleepMapper.
  static EnvironmentFactorScores factorScores(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final tempCriticalMin = thresholds?.temperatureCriticalMin ?? 15;
    final tempCriticalMax = thresholds?.temperatureCriticalMax ?? 32;

    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final humidityCriticalMin = thresholds?.humidityCriticalMin ?? 20;
    final humidityCriticalMax = thresholds?.humidityCriticalMax ?? 70;

    final co2Warning = thresholds?.co2Warning ?? 1000;
    final co2Critical = thresholds?.co2Critical ?? 2000;
    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final pm25Critical = thresholds?.pm25Critical ?? 75;

    final lightWarning = thresholds?.lightMax ?? 50;
    final lightCritical = thresholds?.lightCritical ?? 200;
    final noiseWarning = thresholds?.noiseWarning ?? 40;
    final noiseCritical = thresholds?.noiseCritical ?? 60;

    // A disconnected sensor (negative or zero, by the backend's convention)
    // should not drag the overall score down, so it scores a full 100 instead.
    final room = ((_scoreOrFull(d.temperature,
                () => rangeScore(d.temperature, tempMin, tempMax,
                    tempCriticalMin, tempCriticalMax),
                isMissing: d.temperature < 0) +
            _scoreOrFull(d.humidity,
                () => rangeScore(d.humidity, humidityMin, humidityMax,
                    humidityCriticalMin, humidityCriticalMax),
                isMissing: d.humidity < 0)) /
        2);
    final air = ((_scoreOrFull(d.co2,
                () => upperScore(d.co2, co2Warning, co2Critical),
                isMissing: d.co2 <= 0) +
            upperScore(d.pm25, pm25Warning, pm25Critical)) /
        2);
    final light = upperScore(d.lightIntensity, lightWarning, lightCritical);
    final sound = upperScore(d.noiseLevel, noiseWarning, noiseCritical);

    final overall = ((room + air + light + sound) / 4).round().clamp(0, 100);

    return EnvironmentFactorScores(
      room: room,
      air: air,
      light: light,
      sound: sound,
      overall: overall,
    );
  }

  static double _scoreOrFull(double value, double Function() score,
      {required bool isMissing}) {
    return isMissing ? 100 : score();
  }

  /// Status text from the overall score — the same cut-offs for both Environment
  /// Score and Sleep Readiness (>=80 Good, >=50 Moderate, below that Poor).
  static String statusFor(int overall) {
    if (overall >= 80) return 'Good';
    if (overall >= 50) return 'Moderate';
    return 'Poor';
  }
}

/// The four sub-scores plus the overall, as returned by [EnvironmentScoring.factorScores].
class EnvironmentFactorScores {
  final double room;
  final double air;
  final double light;
  final double sound;
  final int overall;

  const EnvironmentFactorScores({
    required this.room,
    required this.air,
    required this.light,
    required this.sound,
    required this.overall,
  });
}
