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

    public enum AlertLevel {
        WARNING, CRITICAL
    }
}
