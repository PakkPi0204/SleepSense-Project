package com.sleepsense.service;

import com.sleepsense.analysis.ThresholdAnalyzer;
import com.sleepsense.dto.SensorDataRequest;
import com.sleepsense.model.Alert;
import com.sleepsense.model.SensorData;
import com.sleepsense.repository.AlertRepository;
import com.sleepsense.repository.SensorDataRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class SensorService {

    private final SensorDataRepository sensorRepo;
    private final AlertRepository alertRepo;
    private final ThresholdAnalyzer analyzer;

    /**
     * รับข้อมูลจาก ESP32 → บันทึก → วิเคราะห์ → สร้าง alert ถ้าเกิน threshold
     */
    public SensorData ingest(SensorDataRequest req) {
        SensorData data = SensorData.builder()
                .deviceId(req.getDeviceId())
                .temperature(req.getTemperature())
                .humidity(req.getHumidity())
                .co2(req.getCo2())
                .pm25(req.getPm25())
                .lightIntensity(req.getLightIntensity())
                .noiseLevel(req.getNoiseLevel())
                .motionDetected(req.isMotionDetected())
                .timestamp(Instant.now())
                .build();

        try {
            String id = sensorRepo.save(data);
            data.setId(id);
            log.debug("Saved sensor data: {}", id);
        } catch (Exception e) {
            log.error("Failed to save sensor data", e);
            throw new RuntimeException("Database error", e);
        }

        // Run threshold analysis and persist alerts
        List<Alert> alerts = analyzer.analyze(data);
        alerts.forEach(alert -> {
            try {
                String alertId = alertRepo.save(alert);
                log.warn("Alert [{}] saved: {} - {}", alertId, alert.getLevel(), alert.getMessage());
            } catch (Exception e) {
                log.error("Failed to save alert", e);
            }
        });

        return data;
    }

    public Optional<SensorData> getLatest(String deviceId) {
        try {
            return sensorRepo.findLatest(deviceId);
        } catch (Exception e) {
            log.error("Failed to get latest sensor data for device {}", deviceId, e);
            throw new RuntimeException("Database error", e);
        }
    }

    public List<SensorData> getRange(String deviceId, Instant from, Instant to) {
        try {
            return sensorRepo.findByDeviceAndTimeRange(deviceId, from, to);
        } catch (Exception e) {
            log.error("Failed to get sensor data range", e);
            throw new RuntimeException("Database error", e);
        }
    }

    public List<String> getPreSleepSuggestions(String deviceId) {
        SensorData latest = getLatest(deviceId)
                .orElseThrow(() -> new IllegalArgumentException("No data found for device: " + deviceId));
        return analyzer.generatePreSleepSuggestions(latest);
    }
}
