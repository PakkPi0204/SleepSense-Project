package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Per-device thresholds the user has customised (stored in Firestore).
 * Some people need a cooler room than average, or are more sensitive to dust
 *
 * or noise. When a device has no document here the system automatically falls
 * back to the defaults in ThresholdConfig (application.properties).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ThresholdSettings {
    private String deviceId;

    private Double co2Warning;
    private Double co2Critical;

    private Double temperatureMin;
    private Double temperatureMax;
    private Double temperatureCriticalMin;
    private Double temperatureCriticalMax;

    private Double humidityMin;
    private Double humidityMax;
    private Double humidityCriticalMin;
    private Double humidityCriticalMax;

    private Double pm25Warning;
    private Double pm25Critical;

    private Double lightMax;
    private Double lightCritical;

    private Double noiseWarning;
    private Double noiseCritical;

    private Instant updatedAt;

    /** True when the user really saved custom values, rather than these being defaults assembled for display. */
    private boolean customized;
}
