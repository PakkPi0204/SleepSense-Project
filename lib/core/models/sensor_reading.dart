/// A single point-in-time reading of all six environmental factors.
///
/// This is the `SensorReading` type referenced by the Test Plan
/// (UTC-01 / UTC-02 / UTC-03 / ITC-01). Every factor is nullable because the
/// backend legitimately returns nulls when no sensor data is available yet
/// (Test Plan TD-02 for UTC-01.02) — parsing such a response must not throw.
///
/// Field names follow the Test Plan wire format (`light`, `noise`) while the
/// production backend uses `lightIntensity` / `noiseLevel`. [fromJson] accepts
/// both spellings so the same model works against the real API and against the
/// mocked responses used in the unit tests.
class SensorReading {
  final double? co2;
  final double? temperature;
  final double? humidity;
  final double? pm25;
  final double? light;
  final double? noise;
  final bool? motionDetected;
  final String? timestamp;

  const SensorReading({
    this.co2,
    this.temperature,
    this.humidity,
    this.pm25,
    this.light,
    this.noise,
    this.motionDetected,
    this.timestamp,
  });

  /// True when every environmental factor is null — i.e. the backend replied
  /// but had no reading to give (Test Plan TD-02).
  bool get isEmpty =>
      co2 == null &&
      temperature == null &&
      humidity == null &&
      pm25 == null &&
      light == null &&
      noise == null;

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      co2: _toDoubleOrNull(json['co2']),
      temperature: _toDoubleOrNull(json['temperature']),
      humidity: _toDoubleOrNull(json['humidity']),
      pm25: _toDoubleOrNull(json['pm25']),
      light: _toDoubleOrNull(json['light'] ?? json['lightIntensity']),
      noise: _toDoubleOrNull(json['noise'] ?? json['noiseLevel']),
      motionDetected: json['motionDetected'] as bool?,
      timestamp: json['timestamp']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'co2': co2,
        'temperature': temperature,
        'humidity': humidity,
        'pm25': pm25,
        'light': light,
        'noise': noise,
        'motionDetected': motionDetected,
        'timestamp': timestamp,
      };

  @override
  String toString() =>
      'SensorReading(co2: $co2, temperature: $temperature, humidity: $humidity, '
      'pm25: $pm25, light: $light, noise: $noise, timestamp: $timestamp)';
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
