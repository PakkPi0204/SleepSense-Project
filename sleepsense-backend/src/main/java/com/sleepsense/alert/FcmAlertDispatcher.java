package com.sleepsense.alert;

import com.sleepsense.analysis.FactorResult;
import com.sleepsense.analysis.ThresholdResult;
import com.sleepsense.model.SensorData;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Builds one notification per critical factor and hands each to Firebase Cloud
 * Messaging.
 *
 * <p>The build step and the delivery step are separate on purpose: message
 * wording is unit-testable without a live FCM connection, and overriding
 * {@link #deliver(AlertNotification)} is enough to swap the transport.
 */
@Slf4j
@Component
public class FcmAlertDispatcher implements AlertDispatcher {

    @Override
    public List<AlertNotification> sendAlert(String deviceId, SensorData reading,
                                             ThresholdResult result) {
        List<AlertNotification> notifications = new ArrayList<>();

        for (FactorResult factor : result.getCriticalFactors()) {
            AlertNotification notification = AlertNotification.builder()
                    .deviceId(deviceId)
                    .factor(factor.getFactor())
                    .value(factor.getValue())
                    .threshold(factor.getThreshold())
                    .title("Critical room alert")
                    .message(buildMessage(factor))
                    .build();

            notifications.add(notification);
            deliver(notification);
        }

        return notifications;
    }

    /**
     * Hand a single notification to FCM. Left as a logging stub so the rest of
     * the pipeline is testable before Firebase Messaging credentials are wired
     * in; override or replace this method to send for real.
     */
    protected void deliver(AlertNotification notification) {
        log.warn("Critical alert for {} — {}", notification.getDeviceId(),
                notification.getMessage());
    }

    /**
     * STC-05 TC-02: the notification has to name the affected factor and include
     * the recorded value, e.g. "Warning: CO2 level is 2150 ppm — exceeds the
     * safe limit of 2000 ppm."
     */
    public static String buildMessage(FactorResult factor) {
        String label = factorLabel(factor.getFactor());
        String unit = factorUnit(factor.getFactor());

        StringBuilder sb = new StringBuilder("Warning: ")
                .append(label).append(" is ")
                .append(format(factor.getValue())).append(' ').append(unit);

        if (factor.getThreshold() != null) {
            sb.append(" — exceeds the safe limit of ")
                    .append(format(factor.getThreshold())).append(' ').append(unit);
        }
        return sb.append('.').toString();
    }

    public static String factorLabel(String factor) {
        return switch (factor) {
            case ThresholdResult.CO2 -> "CO2 level";
            case ThresholdResult.TEMPERATURE -> "Temperature";
            case ThresholdResult.HUMIDITY -> "Humidity";
            case ThresholdResult.PM25 -> "PM2.5";
            case ThresholdResult.LIGHT -> "Light level";
            case ThresholdResult.NOISE -> "Noise level";
            default -> factor;
        };
    }

    public static String factorUnit(String factor) {
        return switch (factor) {
            case ThresholdResult.CO2 -> "ppm";
            case ThresholdResult.TEMPERATURE -> "°C";
            case ThresholdResult.HUMIDITY -> "%";
            case ThresholdResult.PM25 -> "µg/m³";
            case ThresholdResult.LIGHT -> "lux";
            case ThresholdResult.NOISE -> "dB";
            default -> "";
        };
    }

    private static String format(Double value) {
        if (value == null) return "-";
        return value == Math.rint(value)
                ? String.valueOf(value.longValue())
                : String.format("%.1f", value);
    }
}
