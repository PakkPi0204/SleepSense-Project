/// Models ที่ตรงกับ response ของ backend (parse จาก JSON)
/// แยกจาก UI models (dashboard_models.dart) ที่เก็บค่าเป็น String สำหรับแสดงผล

/// ตรงกับ SensorData ฝั่ง backend
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

/// ตรงกับ Alert ฝั่ง backend
class AlertDto {
  final String id;
  final String deviceId;
  final String level;   // WARNING | CRITICAL
  final String factor;  // CO2 | TEMPERATURE | ...
  final String message;
  final double value;
  final double threshold;

  const AlertDto({
    required this.id,
    required this.deviceId,
    required this.level,
    required this.factor,
    required this.message,
    required this.value,
    required this.threshold,
  });

  factory AlertDto.fromJson(Map<String, dynamic> json) {
    return AlertDto(
      id: (json['id'] ?? '') as String,
      deviceId: (json['deviceId'] ?? '') as String,
      level: (json['level'] ?? '') as String,
      factor: (json['factor'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      value: _toDouble(json['value']),
      threshold: _toDouble(json['threshold']),
    );
  }
}

/// ตรงกับ MorningReport ฝั่ง backend
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
      anomalies: _toStringList(json['anomalies']),
      suggestions: _toStringList(json['suggestions']),
    );
  }
}

// ── helpers ──
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

List<String> _toStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}
