package com.sleepsense.analysis;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * What the Smart Suggestion analysis found across several nights of history.
 *
 * <p>Test Plan reference: STC-04. The response deliberately carries the evidence
 * as well as the advice — the cluster each night landed in, the pattern that was
 * detected, and how many nights support it — because STC-04 TC-03/TC-04 check
 * that a suggestion is traceable to a real recurring pattern rather than to a
 * single night's reading.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PatternAnalysisResult {

    /** One night of history, with the cluster it was assigned to. */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ClusteredNight {
        private String reportId;
        private String date;          // ISO-8601 date of the night's sleep start
        private int cluster;          // cluster index; labels are arbitrary
        private double avgCo2;
        private double maxCo2;
        private double avgTemperature;
        private double avgHumidity;
        private double avgPm25;
        private double avgLight;
        private double avgNoise;
        private int motionEventCount;
    }

    /** A summary of one cluster of similar nights. */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Cluster {
        private int index;
        private int nightCount;
        private String label;         // human-readable, e.g. "Warm, stuffy nights"
        private double avgCo2;
        private double avgTemperature;
        private double avgHumidity;
        private double avgPm25;
        private double avgLight;
        private double avgNoise;
        private double avgMotionEvents;
    }

    /** A recurring condition found across the nights in one cluster. */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DetectedPattern {
        private String id;            // e.g. "CO2_RECURRING_HIGH"
        private String factor;        // CO2 | TEMPERATURE | ...
        private String description;   // what the data actually shows
        private int occurrences;      // nights in the cluster exhibiting it
        private int nightsInCluster;
        private int cluster;
        private double confidence;    // occurrences / nightsInCluster, 0..1
    }

    /** An actionable recommendation derived from exactly one detected pattern. */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SmartSuggestion {
        private String patternId;     // ties the advice back to its evidence
        private String factor;
        private String title;
        private String recommendation;
        private String evidence;      // e.g. "Seen on 4 of the last 5 nights"
    }

    /** False when fewer than {@code MIN_NIGHTS} nights of history exist. */
    private boolean sufficientData;

    /** Set only when {@link #sufficientData} is false. */
    private String note;

    private int nightsAnalysed;
    private List<ClusteredNight> nights;
    private List<Cluster> clusters;
    private List<DetectedPattern> patterns;
    private List<SmartSuggestion> suggestions;
}
