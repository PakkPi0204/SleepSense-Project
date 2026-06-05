package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;

/**
 * รายงานสรุปสภาพแวดล้อมในช่วงกลางคืน
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

    // ค่าเฉลี่ยตลอดคืน
    private double avgTemperature;
    private double avgHumidity;
    private double avgCo2;
    private double avgPm25;
    private double avgLight;
    private double avgNoise;

    // ค่าสูงสุด
    private double maxTemperature;
    private double maxCo2;
    private double maxPm25;
    private double maxNoise;

    // Motion summary
    private int motionEventCount;   // จำนวนครั้งที่ตรวจจับการเคลื่อนไหว
    private String motionPattern;   // "LOW" | "MODERATE" | "HIGH"

    // Cluster result (จาก Data Clustering)
    private String environmentCluster; // "GOOD" | "MODERATE" | "POOR"

    // Abnormal periods detected
    private List<String> anomalies;

    // Recommendations
    private List<String> suggestions;

    private Instant generatedAt;
}
