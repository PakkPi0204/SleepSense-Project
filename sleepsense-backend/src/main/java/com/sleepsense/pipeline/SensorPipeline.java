package com.sleepsense.pipeline;

import com.sleepsense.alert.AlertDispatcher;
import com.sleepsense.alert.AlertNotification;
import com.sleepsense.analysis.ThresholdChecker;
import com.sleepsense.analysis.ThresholdResult;
import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.SensorData;
import com.sleepsense.service.SensorService;
import com.sleepsense.service.ThresholdSettingsService;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;

/**
 * getSensorData() -&gt; checkThreshold() -&gt; sendAlert()
 *
 * <p>Test Plan reference: ITC-01 (Test-SensorPipeline). Normal data flows
 * through without triggering an alert; critical data triggers exactly one
 * {@code sendAlert} call, which in turn emits one notification per critical
 * factor.
 */
@Component
@RequiredArgsConstructor
public class SensorPipeline {

    private final SensorService sensorService;
    private final ThresholdChecker thresholdChecker;
    private final AlertDispatcher alertDispatcher;
    private final ThresholdSettingsService thresholdSettingsService;

    /** What one pass of the pipeline produced. */
    @Getter
    public static class Outcome {
        private final SensorData reading;
        private final ThresholdResult result;
        private final List<AlertNotification> notifications;
        private final boolean alertSent;

        public Outcome(SensorData reading, ThresholdResult result,
                       List<AlertNotification> notifications, boolean alertSent) {
            this.reading = reading;
            this.result = result;
            this.notifications = notifications;
            this.alertSent = alertSent;
        }
    }

    public Outcome run(String deviceId) {
        SensorData reading = sensorService.getSensorData(deviceId);
        ThresholdConfig effective = thresholdSettingsService.getEffective(deviceId);
        ThresholdResult result = thresholdChecker.checkThreshold(reading, effective);

        if (!result.isCritical()) {
            return new Outcome(reading, result, Collections.emptyList(), false);
        }

        List<AlertNotification> notifications =
                alertDispatcher.sendAlert(deviceId, reading, result);
        return new Outcome(reading, result, notifications, true);
    }
}
