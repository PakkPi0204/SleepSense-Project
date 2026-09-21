import '../models/sensor_reading.dart';
import '../models/threshold_config.dart';
import '../services/alert_service.dart';
import '../services/sensor_service.dart';
import '../utils/threshold_checker.dart';

/// What one pass of the pipeline produced.
class PipelineOutcome {
  final SensorReading reading;
  final ThresholdResult result;

  /// The notifications that went out. Empty when nothing was critical, in which
  /// case [alertSent] is false and `sendAlert` was never called.
  final List<AlertNotification> notifications;
  final bool alertSent;

  const PipelineOutcome({
    required this.reading,
    required this.result,
    required this.notifications,
    required this.alertSent,
  });
}

/// getSensorData() -> checkThreshold() -> sendAlert()
///
/// Test Plan reference: ITC-01 (Test-SensorPipeline). Normal data flows through
/// without triggering an alert; critical data triggers exactly one `sendAlert`
/// call, which in turn emits one notification per critical factor.
class SensorPipeline {
  final SensorService sensorService;
  final AlertDispatcher alertDispatcher;
  final ThresholdConfig config;

  const SensorPipeline({
    required this.sensorService,
    required this.alertDispatcher,
    this.config = ThresholdConfig.defaults,
  });

  Future<PipelineOutcome> run() async {
    final reading = await sensorService.getSensorData();
    final result = checkThreshold(reading, config: config);

    if (!result.isCritical) {
      return PipelineOutcome(
        reading: reading,
        result: result,
        notifications: const [],
        alertSent: false,
      );
    }

    final notifications = await alertDispatcher.sendAlert(reading, result);
    return PipelineOutcome(
      reading: reading,
      result: result,
      notifications: notifications,
      alertSent: true,
    );
  }
}
