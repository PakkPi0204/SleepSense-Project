import '../network/api_models.dart';

/// The acceptable range for every environmental factor, used to decide whether
/// a bedroom condition is normal, warning or critical.
///
/// The default values mirror `ThresholdConfig.java` / `application.properties`
/// on the backend. Keeping a single Dart copy means the client and the server
/// classify the same reading the same way, and it gives the Test Plan's
/// "Threshold configuration is loaded with predefined acceptable ranges"
/// prerequisite (UTC-02) something concrete to load.
class ThresholdConfig {
  final double co2Warning;
  final double co2Critical;

  final double temperatureMin;
  final double temperatureMax;
  final double temperatureCriticalMin;
  final double temperatureCriticalMax;

  final double humidityMin;
  final double humidityMax;
  final double humidityCriticalMin;
  final double humidityCriticalMax;

  final double pm25Warning;
  final double pm25Critical;

  final double lightWarning;
  final double lightCritical;

  final double noiseWarning;
  final double noiseCritical;

  const ThresholdConfig({
    this.co2Warning = 1000,
    this.co2Critical = 2000,
    this.temperatureMin = 18,
    this.temperatureMax = 26,
    this.temperatureCriticalMin = 15,
    this.temperatureCriticalMax = 32,
    this.humidityMin = 30,
    this.humidityMax = 60,
    this.humidityCriticalMin = 20,
    this.humidityCriticalMax = 70,
    this.pm25Warning = 35,
    this.pm25Critical = 75,
    this.lightWarning = 50,
    this.lightCritical = 200,
    this.noiseWarning = 40,
    this.noiseCritical = 60,
  });

  /// System defaults — used whenever the user has not customised anything.
  static const ThresholdConfig defaults = ThresholdConfig();

  /// Build a config from the per-device settings the backend returns. Any field
  /// the user has not customised comes back null and falls back to the default.
  factory ThresholdConfig.fromSettings(ThresholdSettingsDto? s) {
    const d = ThresholdConfig.defaults;
    if (s == null) return d;
    return ThresholdConfig(
      co2Warning: s.co2Warning ?? d.co2Warning,
      co2Critical: s.co2Critical ?? d.co2Critical,
      temperatureMin: s.temperatureMin ?? d.temperatureMin,
      temperatureMax: s.temperatureMax ?? d.temperatureMax,
      temperatureCriticalMin:
          s.temperatureCriticalMin ?? d.temperatureCriticalMin,
      temperatureCriticalMax:
          s.temperatureCriticalMax ?? d.temperatureCriticalMax,
      humidityMin: s.humidityMin ?? d.humidityMin,
      humidityMax: s.humidityMax ?? d.humidityMax,
      humidityCriticalMin: s.humidityCriticalMin ?? d.humidityCriticalMin,
      humidityCriticalMax: s.humidityCriticalMax ?? d.humidityCriticalMax,
      pm25Warning: s.pm25Warning ?? d.pm25Warning,
      pm25Critical: s.pm25Critical ?? d.pm25Critical,
      lightWarning: s.lightMax ?? d.lightWarning,
      lightCritical: s.lightCritical ?? d.lightCritical,
      noiseWarning: s.noiseWarning ?? d.noiseWarning,
      noiseCritical: s.noiseCritical ?? d.noiseCritical,
    );
  }
}
