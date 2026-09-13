package com.sleepsense.service;

import com.sleepsense.analysis.ThresholdAnalyzer;
import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.dto.SensorDataRequest;
import com.sleepsense.model.Alert;
import com.sleepsense.model.SensorData;
import com.sleepsense.repository.AlertRepository;
import com.sleepsense.repository.SensorDataRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class SensorService {

    private final SensorDataRepository sensorRepo;
    private final AlertRepository alertRepo;
    private final ThresholdAnalyzer analyzer;
    private final ThresholdSettingsService thresholdSettingsService;

    /**
     * รับข้อมูลจาก ESP32 → บันทึก → วิเคราะห์ → สร้าง alert ถ้าเกิน threshold
     * (ใช้ threshold ที่ device นี้ตั้งเองถ้ามี ไม่งั้น fallback ไปที่ค่า default)
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

        // ดึง threshold ที่ device นี้ตั้งเอง (ถ้ามี) มาใช้วิเคราะห์แทนค่า default
        ThresholdConfig effective = thresholdSettingsService.getEffective(req.getDeviceId());

        List<Alert> alerts = analyzer.analyze(data, effective);
        processAlerts(req.getDeviceId(), alerts);

        return data;
    }

    /**
     * เดิมโค้ดตรงนี้แค่ insert แถว Alert ใหม่ทุกครั้งที่ analyze() เจอปัญหา —
     * ทำให้ระหว่างที่ปัญหาเดิมยังต่อเนื่องอยู่ (เช่น อุณหภูมิสูงค้างอยู่หลาย
     * นาที) จะมีแถวใหม่ถูกสร้างทุกๆ 30 วิ (ทุกรอบที่ ESP32 ส่งค่ามา) และไม่มี
     * กลไกใดๆ บอกว่าปัญหาเดิม "หายไปแล้ว" เลย ทำให้ frontend ต้องคอยเดา/กรอง
     * เองว่า alert แถวไหนยังจริงอยู่ (ดู DashboardMapper.isFactorCritical ฝั่ง
     * Flutter ที่แก้เป็นการชั่วคราวไปก่อนหน้านี้)
     *
     * ตอนนี้ backend เป็นฝ่ายจัดการสถานะ resolved/active เองแล้ว:
     *   1) factor ไหนที่เคย active อยู่ แต่รอบนี้ analyze() ไม่เจอปัญหาแล้ว
     *      (ค่ากลับมาปกติ หรือผู้ใช้ปรับ threshold ใหม่จนไม่วิกฤตแล้ว) → resolve
     *   2) factor ไหนที่ analyze() เจอปัญหาแต่ level เดิมกับที่ active อยู่แล้ว
     *      (ยังเป็นปัญหาเดิมต่อเนื่อง) → ไม่ insert ซ้ำ กันสแปม DB
     *   3) factor ไหนที่ level เปลี่ยนไป (เช่น WARNING ยกระดับเป็น CRITICAL)
     *      หรือเป็นปัญหาใหม่ที่ไม่เคย active มาก่อน → resolve อันเก่า (ถ้ามี)
     *      แล้ว insert แถวใหม่แทน
     */
    private void processAlerts(String deviceId, List<Alert> alerts) {
        List<Alert> activeAlerts;
        try {
            activeAlerts = alertRepo.findActiveByDevice(deviceId);
        } catch (Exception e) {
            log.error("Failed to fetch active alerts for device {}", deviceId, e);
            // ดึง active list ไม่ได้ — ยอมให้ insert ตรงๆ แบบเดิมไปก่อน ดีกว่า
            // ทำให้ alert วิกฤตรอบนี้หายไปเฉยๆ เพราะเช็ค dedupe ไม่ได้
            alerts.forEach(alert -> {
                try {
                    alertRepo.save(alert);
                } catch (Exception saveError) {
                    log.error("Failed to save alert", saveError);
                }
            });
            return;
        }

        Set<String> currentFactors = new HashSet<>();
        for (Alert a : alerts) currentFactors.add(a.getFactor());

        // 1) resolve alert เก่าของ factor ที่ตอนนี้ไม่มีปัญหาแล้ว
        for (Alert active : activeAlerts) {
            if (!currentFactors.contains(active.getFactor())) {
                try {
                    alertRepo.resolve(active.getId());
                    log.info("Alert [{}] auto-resolved: {} back to normal", active.getId(), active.getFactor());
                } catch (Exception e) {
                    log.error("Failed to resolve alert {}", active.getId(), e);
                }
            }
        }

        // 2)/3) สร้างแถวใหม่เฉพาะ factor ที่ยังไม่มี active alert ระดับเดิมอยู่
        for (Alert alert : alerts) {
            Alert existingActive = activeAlerts.stream()
                    .filter(a -> a.getFactor().equals(alert.getFactor()))
                    .findFirst()
                    .orElse(null);

            if (existingActive != null && existingActive.getLevel() == alert.getLevel()) {
                continue; // ปัญหาเดิม ระดับเดิม ยังต่อเนื่องอยู่ — ไม่ต้อง insert ซ้ำ
            }
            if (existingActive != null) {
                try {
                    alertRepo.resolve(existingActive.getId());
                } catch (Exception e) {
                    log.error("Failed to resolve alert {}", existingActive.getId(), e);
                }
            }
            try {
                String alertId = alertRepo.save(alert);
                log.warn("Alert [{}] saved: {} - {}", alertId, alert.getLevel(), alert.getMessage());
            } catch (Exception e) {
                log.error("Failed to save alert", e);
            }
        }
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
        ThresholdConfig effective = thresholdSettingsService.getEffective(deviceId);
        return analyzer.generatePreSleepSuggestions(latest, effective);
    }
}
