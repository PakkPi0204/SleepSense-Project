package com.sleepsense.analysis;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.Alert;
import com.sleepsense.model.SensorData;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Threshold-Based Analysis
 * เปรียบเทียบค่า sensor กับ threshold และสร้าง alert / คำแนะนำ
 */
@Component
@RequiredArgsConstructor
public class ThresholdAnalyzer {

    private final ThresholdConfig cfg;

    /**
     * วิเคราะห์ sensor data 1 รอบ → คืน list ของ alert ที่ตรวจพบ
     */
    public List<Alert> analyze(SensorData data) {
        List<Alert> alerts = new ArrayList<>();

        checkCo2(data, alerts);
        checkTemperature(data, alerts);
        checkHumidity(data, alerts);
        checkPm25(data, alerts);
        checkLight(data, alerts);
        checkNoise(data, alerts);

        return alerts;
    }

    /**
     * สร้างคำแนะนำ pre-sleep จาก sensor data ปัจจุบัน
     */
    public List<String> generatePreSleepSuggestions(SensorData data) {
        List<String> suggestions = new ArrayList<>();

        if (data.getCo2() > cfg.getCo2Warning())
            suggestions.add("CO₂ สูง (" + (int)data.getCo2() + " ppm) — เปิดหน้าต่างระบายอากาศก่อนนอน");

        if (data.getTemperature() > cfg.getTemperatureMax())
            suggestions.add("อุณหภูมิสูงเกินไป (" + data.getTemperature() + "°C) — เปิดพัดลมหรือแอร์");
        else if (data.getTemperature() < cfg.getTemperatureMin())
            suggestions.add("อุณหภูมิต่ำเกินไป (" + data.getTemperature() + "°C) — เพิ่มความอบอุ่นในห้อง");

        if (data.getHumidity() > cfg.getHumidityMax())
            suggestions.add("ความชื้นสูง (" + data.getHumidity() + "%) — เปิดเครื่องลดความชื้น");
        else if (data.getHumidity() < cfg.getHumidityMin())
            suggestions.add("ความชื้นต่ำ (" + data.getHumidity() + "%) — เปิดเครื่องเพิ่มความชื้น");

        if (data.getPm25() > cfg.getPm25Warning())
            suggestions.add("ฝุ่น PM2.5 สูง (" + data.getPm25() + " µg/m³) — เปิดเครื่องฟอกอากาศ");

        if (data.getLightIntensity() > cfg.getLightMax())
            suggestions.add("แสงสว่างมากเกินไป (" + (int)data.getLightIntensity() + " lux) — ปิดไฟหรือติดม่านทึบ");

        if (data.getNoiseLevel() > cfg.getNoiseWarning())
            suggestions.add("เสียงรบกวน (" + (int)data.getNoiseLevel() + " dB) — ลดแหล่งเสียงหรือใช้ที่อุดหู");

        if (suggestions.isEmpty())
            suggestions.add("สภาพแวดล้อมห้องนอนเหมาะสมสำหรับการนอนหลับ ✓");

        return suggestions;
    }

    // ──────────────────────────────────────────────
    // Private checkers
    // ──────────────────────────────────────────────

    private void checkCo2(SensorData d, List<Alert> out) {
        if (d.getCo2() >= cfg.getCo2Critical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "CO2",
                    "ระดับ CO₂ วิกฤต: " + (int)d.getCo2() + " ppm — เปิดหน้าต่างทันที",
                    d.getCo2(), cfg.getCo2Critical()));
        } else if (d.getCo2() >= cfg.getCo2Warning()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "CO2",
                    "ระดับ CO₂ สูง: " + (int)d.getCo2() + " ppm — ควรระบายอากาศ",
                    d.getCo2(), cfg.getCo2Warning()));
        }
    }

    private void checkTemperature(SensorData d, List<Alert> out) {
        if (d.getTemperature() > cfg.getTemperatureMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "TEMPERATURE",
                    "อุณหภูมิสูงเกินไป: " + d.getTemperature() + "°C",
                    d.getTemperature(), cfg.getTemperatureMax()));
        } else if (d.getTemperature() < cfg.getTemperatureMin()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "TEMPERATURE",
                    "อุณหภูมิต่ำเกินไป: " + d.getTemperature() + "°C",
                    d.getTemperature(), cfg.getTemperatureMin()));
        }
    }

    private void checkHumidity(SensorData d, List<Alert> out) {
        if (d.getHumidity() > cfg.getHumidityMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "HUMIDITY",
                    "ความชื้นสูงเกินไป: " + d.getHumidity() + "%",
                    d.getHumidity(), cfg.getHumidityMax()));
        } else if (d.getHumidity() < cfg.getHumidityMin()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "HUMIDITY",
                    "ความชื้นต่ำเกินไป: " + d.getHumidity() + "%",
                    d.getHumidity(), cfg.getHumidityMin()));
        }
    }

    private void checkPm25(SensorData d, List<Alert> out) {
        if (d.getPm25() >= cfg.getPm25Critical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "PM25",
                    "ฝุ่น PM2.5 วิกฤต: " + d.getPm25() + " µg/m³",
                    d.getPm25(), cfg.getPm25Critical()));
        } else if (d.getPm25() >= cfg.getPm25Warning()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "PM25",
                    "ฝุ่น PM2.5 สูง: " + d.getPm25() + " µg/m³ — ควรเปิดเครื่องฟอกอากาศ",
                    d.getPm25(), cfg.getPm25Warning()));
        }
    }

    private void checkLight(SensorData d, List<Alert> out) {
        if (d.getLightIntensity() > cfg.getLightMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "LIGHT",
                    "ความสว่างมากเกินไป: " + (int)d.getLightIntensity() + " lux",
                    d.getLightIntensity(), cfg.getLightMax()));
        }
    }

    private void checkNoise(SensorData d, List<Alert> out) {
        if (d.getNoiseLevel() >= cfg.getNoiseCritical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "NOISE",
                    "เสียงรบกวนวิกฤต: " + (int)d.getNoiseLevel() + " dB",
                    d.getNoiseLevel(), cfg.getNoiseCritical()));
        } else if (d.getNoiseLevel() >= cfg.getNoiseWarning()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "NOISE",
                    "เสียงรบกวน: " + (int)d.getNoiseLevel() + " dB",
                    d.getNoiseLevel(), cfg.getNoiseWarning()));
        }
    }

    private Alert buildAlert(SensorData d, Alert.AlertLevel level,
                             String factor, String message,
                             double value, double threshold) {
        return Alert.builder()
                .deviceId(d.getDeviceId())
                .level(level)
                .factor(factor)
                .message(message)
                .value(value)
                .threshold(threshold)
                .timestamp(Instant.now())
                .build();
    }
}
