package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;

/**
 * Summary of the bedroom environment over one night.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MorningReport {
    private String id;
    private String deviceId;
    private Instant sleepStart;
    private Instant sleepEnd;

    // Averages across the whole night
    private double avgTemperature;
    private double avgHumidity;
    private double avgCo2;
    private double avgPm25;
    private double avgLight;
    private double avgNoise;

    // Peak values
    private double maxTemperature;
    private double maxCo2;
    private double maxPm25;
    private double maxNoise;

    // Motion summary
    private int motionEventCount;   // how many samples detected movement
    private String motionPattern;   // "LOW" | "MODERATE" | "HIGH"

    // Cluster result (from the data clustering step)
    private String environmentCluster; // "GOOD" | "MODERATE" | "POOR"

    // Data completeness (%) — samples collected vs. samples expected, so a
    // device that was offline for part of the night is visible in the report
    private int dataCompleteness;

    // Abnormal periods detected
    private List<String> anomalies;

    // Recommendations
    private List<String> suggestions;

    private Instant generatedAt;
}
