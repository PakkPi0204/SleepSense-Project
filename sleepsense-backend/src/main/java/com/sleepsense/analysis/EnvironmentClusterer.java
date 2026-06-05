package com.sleepsense.analysis;

import com.sleepsense.model.SensorData;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Data Clustering — จัดกลุ่มสภาพแวดล้อมห้องนอนตาม feature vector
 *
 * ใช้ weighted-score แทน full K-Means เพื่อให้เหมาะกับขนาดข้อมูล prototype
 * ผลลัพธ์: "GOOD" | "MODERATE" | "POOR"
 *
 * สามารถแทนที่ด้วย Weka หรือ library ML ภายหลังได้
 */
@Component
public class EnvironmentClusterer {

    /**
     * คืน cluster label สำหรับชุดข้อมูลทั้งคืน
     */
    public String cluster(List<SensorData> dataPoints) {
        if (dataPoints == null || dataPoints.isEmpty()) return "UNKNOWN";

        double score = dataPoints.stream()
                .mapToDouble(this::scorePoint)
                .average()
                .orElse(0.0);

        // Score 0–100: ยิ่งสูงยิ่งดี
        if (score >= 70) return "GOOD";
        if (score >= 40) return "MODERATE";
        return "POOR";
    }

    /**
     * คืนค่า 0-100 สำหรับ sensor snapshot หนึ่งจุด
     * แต่ละปัจจัยมี weight เท่ากัน (1/6)
     */
    private double scorePoint(SensorData d) {
        double s = 0;
        s += scoreTemperature(d.getTemperature());
        s += scoreHumidity(d.getHumidity());
        s += scoreCo2(d.getCo2());
        s += scorePm25(d.getPm25());
        s += scoreLight(d.getLightIntensity());
        s += scoreNoise(d.getNoiseLevel());
        return s / 6.0;
    }

    // ──────────────────────────────────────────────
    // Individual factor scores (0–100)
    // ──────────────────────────────────────────────

    private double scoreTemperature(double t) {
        // Best: 20–24 °C  → 100
        if (t >= 20 && t <= 24) return 100;
        if (t >= 18 && t < 20)  return 70;
        if (t > 24  && t <= 26) return 70;
        return 20;
    }

    private double scoreHumidity(double h) {
        if (h >= 45 && h <= 55) return 100;
        if (h >= 40 && h < 45 || h > 55 && h <= 60) return 70;
        return 20;
    }

    private double scoreCo2(double co2) {
        if (co2 < 700)  return 100;
        if (co2 < 1000) return 70;
        if (co2 < 2000) return 30;
        return 0;
    }

    private double scorePm25(double pm25) {
        if (pm25 < 12)  return 100;
        if (pm25 < 35)  return 70;
        if (pm25 < 75)  return 30;
        return 0;
    }

    private double scoreLight(double lux) {
        if (lux < 5)  return 100;
        if (lux < 50) return 60;
        return 20;
    }

    private double scoreNoise(double db) {
        if (db < 30) return 100;
        if (db < 40) return 70;
        if (db < 60) return 30;
        return 0;
    }
}
