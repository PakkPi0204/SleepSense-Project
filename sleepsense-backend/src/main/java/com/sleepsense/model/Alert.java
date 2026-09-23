package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Alert {
    private String id;
    private String deviceId;
    private AlertLevel level;
    private String factor;     // "CO2", "TEMPERATURE", "PM25", "NOISE", "LIGHT", "HUMIDITY"
    private String message;
    private double value;
    private double threshold;
    private Instant timestamp;

    // True once this problem has returned to normal (the value is back inside
    // the acceptable band under the current thresholds). Set by SensorService
    // when the latest analysis pass no longer flags this factor as WARNING or
    // CRITICAL. Without this flag every row looked "active" forever, even after
    // the problem cleared or the user widened the thresholds.
    @Builder.Default
    private boolean resolved = false;
    private Instant resolvedAt; // null while the alert is still active

    public enum AlertLevel {
        WARNING, CRITICAL
    }
}
