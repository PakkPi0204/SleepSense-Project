/// Models mirroring the backend responses, parsed from JSON.
/// Kept separate from the UI models in dashboard_models.dart, which hold
/// already-formatted strings for display.

/// Mirrors SensorData on the backend.
class SensorDataDto {
  final String id;
  final String deviceId;
  final double temperature;
  final double humidity;
  final double co2;
  final double pm25;
  final double lightIntensity;
  final double noiseLevel;
  final bool motionDetected;
  final String timestamp;

  const SensorDataDto({
    required this.id,
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    required this.co2,
    required this.pm25,
    required this.lightIntensity,
    required this.noiseLevel,
    required this.motionDetected,
    required this.timestamp,
  });

  factory SensorDataDto.fromJson(Map<String, dynamic> json) {
    return SensorDataDto(
      id: (json['id'] ?? '') as String,
      deviceId: (json['deviceId'] ?? '') as String,
      temperature: _toDouble(json['temperature']),
      humidity: _toDouble(json['humidity']),
      co2: _toDouble(json['co2']),
      pm25: _toDouble(json['pm25']),
      lightIntensity: _toDouble(json['lightIntensity']),
      noiseLevel: _toDouble(json['noiseLevel']),
      motionDetected: (json['motionDetected'] ?? false) as bool,
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }
}

/// Mirrors Alert on the backend.
class AlertDto {
  final String id;
  final String deviceId;
  final String level;   // WARNING | CRITICAL
  final String factor;  // CO2 | TEMPERATURE | ...
  final String message;
  final double value;
  final double threshold;
  final DateTime? timestamp;
  // True once the backend considers this problem resolved. Rows written by an
  // older backend have no such field and are treated as false (still active).
  final bool resolved;

  const AlertDto({
    required this.id,
    required this.deviceId,
    required this.level,
    required this.factor,
    required this.message,
    required this.value,
    required this.threshold,
    this.timestamp,
    this.resolved = false,
  });

  bool get isCritical => level == 'CRITICAL';

  factory AlertDto.fromJson(Map<String, dynamic> json) {
    return AlertDto(
      id: (json['id'] ?? '') as String,
      deviceId: (json['deviceId'] ?? '') as String,
      level: (json['level'] ?? '') as String,
      factor: (json['factor'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      value: _toDouble(json['value']),
      threshold: _toDouble(json['threshold']),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()),
      resolved: json['resolved'] == true,
    );
  }
}

/// Mirrors MorningReport on the backend.
class MorningReportDto {
  final String id;
  final String deviceId;
  final String sleepStart;
  final String sleepEnd;
  final String generatedAt;
  final double avgTemperature;
  final double avgHumidity;
  final double avgCo2;
  final double avgPm25;
  final double avgLight;
  final double avgNoise;
  final double maxTemperature;
  final double maxCo2;
  final double maxPm25;
  final double maxNoise;
  final int motionEventCount;
  final String motionPattern;        // LOW | MODERATE | HIGH
  final String environmentCluster;   // GOOD | MODERATE | POOR
  final int dataCompleteness;         // % of expected samples that arrived
  final List<String> anomalies;
  final List<String> suggestions;

  const MorningReportDto({
    required this.id,
    required this.deviceId,
    required this.sleepStart,
    required this.sleepEnd,
    required this.generatedAt,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgCo2,
    required this.avgPm25,
    required this.avgLight,
    required this.avgNoise,
    required this.maxTemperature,
    required this.maxCo2,
    required this.maxPm25,
    required this.maxNoise,
    required this.motionEventCount,
    required this.motionPattern,
    required this.environmentCluster,
    this.dataCompleteness = 100,
    required this.anomalies,
    required this.suggestions,
  });

  factory MorningReportDto.fromJson(Map<String, dynamic> json) {
    return MorningReportDto(
      id: (json['id'] ?? '') as String,
      deviceId: (json['deviceId'] ?? '') as String,
      sleepStart: (json['sleepStart'] ?? '').toString(),
      sleepEnd: (json['sleepEnd'] ?? '').toString(),
      generatedAt: (json['generatedAt'] ?? '').toString(),
      avgTemperature: _toDouble(json['avgTemperature']),
      avgHumidity: _toDouble(json['avgHumidity']),
      avgCo2: _toDouble(json['avgCo2']),
      avgPm25: _toDouble(json['avgPm25']),
      avgLight: _toDouble(json['avgLight']),
      avgNoise: _toDouble(json['avgNoise']),
      maxTemperature: _toDouble(json['maxTemperature']),
      maxCo2: _toDouble(json['maxCo2']),
      maxPm25: _toDouble(json['maxPm25']),
      maxNoise: _toDouble(json['maxNoise']),
      motionEventCount: (json['motionEventCount'] ?? 0) as int,
      motionPattern: (json['motionPattern'] ?? '') as String,
      environmentCluster: (json['environmentCluster'] ?? '') as String,
      dataCompleteness: (json['dataCompleteness'] as num?)?.toInt() ?? 100,
      anomalies: _toStringList(json['anomalies']),
      suggestions: _toStringList(json['suggestions']),
    );
  }
}

/// Mirrors ThresholdSettings on the backend — the thresholds a user can tune.
/// Every field is nullable: null means "not customised", and the backend uses
/// its default instead.
class ThresholdSettingsDto {
  final String deviceId;
  final double? co2Warning;
  final double? co2Critical;
  final double? temperatureMin;
  final double? temperatureMax;
  final double? temperatureCriticalMin;
  final double? temperatureCriticalMax;
  final double? humidityMin;
  final double? humidityMax;
  final double? humidityCriticalMin;
  final double? humidityCriticalMax;
  final double? pm25Warning;
  final double? pm25Critical;
  final double? lightMax;
  final double? lightCritical;
  final double? noiseWarning;
  final double? noiseCritical;
  final bool customized;

  const ThresholdSettingsDto({
    required this.deviceId,
    this.co2Warning,
    this.co2Critical,
    this.temperatureMin,
    this.temperatureMax,
    this.temperatureCriticalMin,
    this.temperatureCriticalMax,
    this.humidityMin,
    this.humidityMax,
    this.humidityCriticalMin,
    this.humidityCriticalMax,
    this.pm25Warning,
    this.pm25Critical,
    this.lightMax,
    this.lightCritical,
    this.noiseWarning,
    this.noiseCritical,
    this.customized = false,
  });

  factory ThresholdSettingsDto.fromJson(Map<String, dynamic> json) {
    return ThresholdSettingsDto(
      deviceId: (json['deviceId'] ?? '') as String,
      co2Warning: _toDoubleOrNull(json['co2Warning']),
      co2Critical: _toDoubleOrNull(json['co2Critical']),
      temperatureMin: _toDoubleOrNull(json['temperatureMin']),
      temperatureMax: _toDoubleOrNull(json['temperatureMax']),
      temperatureCriticalMin: _toDoubleOrNull(json['temperatureCriticalMin']),
      temperatureCriticalMax: _toDoubleOrNull(json['temperatureCriticalMax']),
      humidityMin: _toDoubleOrNull(json['humidityMin']),
      humidityMax: _toDoubleOrNull(json['humidityMax']),
      humidityCriticalMin: _toDoubleOrNull(json['humidityCriticalMin']),
      humidityCriticalMax: _toDoubleOrNull(json['humidityCriticalMax']),
      pm25Warning: _toDoubleOrNull(json['pm25Warning']),
      pm25Critical: _toDoubleOrNull(json['pm25Critical']),
      lightMax: _toDoubleOrNull(json['lightMax']),
      lightCritical: _toDoubleOrNull(json['lightCritical']),
      noiseWarning: _toDoubleOrNull(json['noiseWarning']),
      noiseCritical: _toDoubleOrNull(json['noiseCritical']),
      customized: (json['customized'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'co2Warning': co2Warning,
        'co2Critical': co2Critical,
        'temperatureMin': temperatureMin,
        'temperatureMax': temperatureMax,
        'temperatureCriticalMin': temperatureCriticalMin,
        'temperatureCriticalMax': temperatureCriticalMax,
        'humidityMin': humidityMin,
        'humidityMax': humidityMax,
        'humidityCriticalMin': humidityCriticalMin,
        'humidityCriticalMax': humidityCriticalMax,
        'pm25Warning': pm25Warning,
        'pm25Critical': pm25Critical,
        'lightMax': lightMax,
        'lightCritical': lightCritical,
        'noiseWarning': noiseWarning,
        'noiseCritical': noiseCritical,
      };

  ThresholdSettingsDto copyWith({
    double? co2Warning,
    double? co2Critical,
    double? temperatureMin,
    double? temperatureMax,
    double? temperatureCriticalMin,
    double? temperatureCriticalMax,
    double? humidityMin,
    double? humidityMax,
    double? humidityCriticalMin,
    double? humidityCriticalMax,
    double? pm25Warning,
    double? pm25Critical,
    double? lightMax,
    double? lightCritical,
    double? noiseWarning,
    double? noiseCritical,
  }) {
    return ThresholdSettingsDto(
      deviceId: deviceId,
      co2Warning: co2Warning ?? this.co2Warning,
      co2Critical: co2Critical ?? this.co2Critical,
      temperatureMin: temperatureMin ?? this.temperatureMin,
      temperatureMax: temperatureMax ?? this.temperatureMax,
      temperatureCriticalMin: temperatureCriticalMin ?? this.temperatureCriticalMin,
      temperatureCriticalMax: temperatureCriticalMax ?? this.temperatureCriticalMax,
      humidityMin: humidityMin ?? this.humidityMin,
      humidityMax: humidityMax ?? this.humidityMax,
      humidityCriticalMin: humidityCriticalMin ?? this.humidityCriticalMin,
      humidityCriticalMax: humidityCriticalMax ?? this.humidityCriticalMax,
      pm25Warning: pm25Warning ?? this.pm25Warning,
      pm25Critical: pm25Critical ?? this.pm25Critical,
      lightMax: lightMax ?? this.lightMax,
      lightCritical: lightCritical ?? this.lightCritical,
      noiseWarning: noiseWarning ?? this.noiseWarning,
      noiseCritical: noiseCritical ?? this.noiseCritical,
      customized: customized,
    );
  }
}

// ── helpers ──
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

List<String> _toStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}
