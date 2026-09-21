import '../models/sensor_reading.dart';
import '../utils/threshold_checker.dart';

/// One push notification about one critical factor.
class AlertNotification {
  final String factor;
  final double? value;
  final double? threshold;
  final String message;

  const AlertNotification({
    required this.factor,
    required this.message,
    this.value,
    this.threshold,
  });

  @override
  String toString() => message;
}

/// Delivers critical-room alerts to the user's device.
///
/// Test Plan reference: `sendAlert()` in ITC-01 and STC-05. Declared as an
/// interface so the integration test can substitute a recording fake and assert
/// on how many times it was invoked.
abstract interface class AlertDispatcher {
  /// Called once per pipeline run that finds at least one critical factor.
  /// Returns the notifications that were sent — one per critical factor, which
  /// is what STC-05 TC-03 expects when CO2 and noise go critical together.
  Future<List<AlertNotification>> sendAlert(
    SensorReading reading,
    ThresholdResult result,
  );
}

/// Default dispatcher. Builds one notification per critical factor and hands
/// them to [deliver], which the FCM integration overrides.
class FcmAlertDispatcher implements AlertDispatcher {
  /// Injected so a real FCM/local-notification plugin can be wired in without
  /// changing the message-building logic (or the tests that cover it).
  final Future<void> Function(AlertNotification notification)? deliver;

  const FcmAlertDispatcher({this.deliver});

  @override
  Future<List<AlertNotification>> sendAlert(
    SensorReading reading,
    ThresholdResult result,
  ) async {
    final notifications = <AlertNotification>[];

    for (final factor in result.criticalFactors) {
      final notification = AlertNotification(
        factor: factor.factor,
        value: factor.value,
        threshold: factor.threshold,
        message: buildMessage(factor),
      );
      notifications.add(notification);
      await deliver?.call(notification);
    }

    return notifications;
  }

  /// STC-05 TC-02: the notification has to name the affected factor and include
  /// the recorded value, e.g. "Warning: CO2 level is 2150 ppm - exceeds the
  /// safe limit of 2000 ppm."
  static String buildMessage(FactorResult factor) {
    final label = factorLabel(factor.factor);
    final unit = factorUnit(factor.factor);
    final value = _format(factor.value);
    final threshold = _format(factor.threshold);

    final buffer = StringBuffer('Warning: $label is $value $unit');
    if (factor.threshold != null) {
      buffer.write(' — exceeds the safe limit of $threshold $unit');
    }
    buffer.write('.');
    return buffer.toString();
  }

  static String factorLabel(String factor) {
    switch (factor) {
      case Factors.co2:
        return 'CO2 level';
      case Factors.temperature:
        return 'Temperature';
      case Factors.humidity:
        return 'Humidity';
      case Factors.pm25:
        return 'PM2.5';
      case Factors.light:
        return 'Light level';
      case Factors.noise:
        return 'Noise level';
      default:
        return factor;
    }
  }

  static String factorUnit(String factor) {
    switch (factor) {
      case Factors.co2:
        return 'ppm';
      case Factors.temperature:
        return '°C';
      case Factors.humidity:
        return '%';
      case Factors.pm25:
        return 'µg/m³';
      case Factors.light:
        return 'lux';
      case Factors.noise:
        return 'dB';
      default:
        return '';
    }
  }

  static String _format(double? value) {
    if (value == null) return '-';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
