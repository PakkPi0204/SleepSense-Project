package com.sleepsense.service;

import com.sleepsense.analysis.ThresholdAnalyzer;
import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.Alert;
import com.sleepsense.model.SensorData;
import com.sleepsense.model.ThresholdSettings;
import com.sleepsense.repository.AlertRepository;
import com.sleepsense.repository.SensorDataRepository;
import com.sleepsense.repository.ThresholdSettingsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

/**
 * จัดการ threshold ที่ผู้ใช้ปรับเองต่อ device — ทับค่า default จาก ThresholdConfig
 * เผื่อบางคนต้องนอนห้องเย็นกว่าปกติ ไวต่อฝุ่น/เสียงมากกว่าค่าเฉลี่ยทั่วไป ฯลฯ
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ThresholdSettingsService {

    private final ThresholdSettingsRepository repo;
    private final ThresholdConfig defaults;
    private final SensorDataRepository sensorRepo;
    private final AlertRepository alertRepo;
    private final ThresholdAnalyzer analyzer;

    /** กันสร้าง alert ซ้ำถ้าผู้ใช้กด save ติดกันหลายครั้งในช่วงสั้นๆ */
    private static final long DEDUPE_WINDOW_SECONDS = 15;

    /** ค่า threshold ที่ "ใช้งานจริง" ของ device นี้ — custom ถ้ามี ไม่งั้นใช้ default */
    public ThresholdConfig getEffective(String deviceId) {
        Optional<ThresholdSettings> custom = safeFind(deviceId);
        return custom.map(this::merge).orElse(defaults);
    }

    /** ค่าสำหรับแสดงในหน้าตั้งค่า — คืนค่า default (พร้อม flag customized=false) ถ้ายังไม่เคยตั้งเอง */
    public ThresholdSettings getSettingsOrDefault(String deviceId) {
        return safeFind(deviceId).orElseGet(() -> fromDefaults(deviceId));
    }

    public ThresholdSettings save(String deviceId, ThresholdSettings input) {
        validate(input);
        input.setDeviceId(deviceId);
        input.setCustomized(true);
        try {
            repo.save(input);
        } catch (Exception e) {
            log.error("Failed to save threshold settings for {}", deviceId, e);
            throw new RuntimeException("Database error", e);
        }
        ThresholdSettings saved = getSettingsOrDefault(deviceId);

        // เดิม: alert จะถูกสร้างเฉพาะตอน ESP32 ส่งข้อมูลใหม่เข้ามาเท่านั้น (ดู
        // SensorService.ingest()) แปลว่าถ้าผู้ใช้ปรับ threshold ให้เข้มขึ้นแล้ว
        // ค่าปัจจุบันในห้องเข้าเกณฑ์วิกฤตพอดี จะไม่มี alert/popup ใดๆ จนกว่า
        // sensor รอบถัดไปจะส่งเข้ามา (อาจอีก 30+ วิ) — เช็คค่าล่าสุดที่มีอยู่แล้ว
        // ทันทีตรงนี้ เพื่อให้การปรับ threshold รู้สึก "real time" จริงๆ
        reEvaluateLatestReading(deviceId, merge(saved));

        return saved;
    }

    /**
     * เช็คค่า sensor ล่าสุดที่มีอยู่ในระบบกับ threshold ใหม่ทันทีหลัง save —
     * ถ้าเข้าเกณฑ์ warning/critical จะสร้าง alert ใหม่เลย ไม่ต้องรอรอบถัดไปของ
     * ESP32 ความล้มเหลวตรงนี้ไม่ควรทำให้การบันทึก threshold ล้มเหลวไปด้วย
     */
    private void reEvaluateLatestReading(String deviceId, ThresholdConfig effective) {
        try {
            Optional<SensorData> latest = sensorRepo.findLatest(deviceId);
            if (latest.isEmpty()) return;

            List<Alert> newAlerts = analyzer.analyze(latest.get(), effective);
            if (newAlerts.isEmpty()) return;

            List<Alert> recent = alertRepo.findRecentByDevice(deviceId, 20);
            Instant cutoff = Instant.now().minus(DEDUPE_WINDOW_SECONDS, ChronoUnit.SECONDS);

            for (Alert alert : newAlerts) {
                boolean duplicate = recent.stream().anyMatch(r ->
                        r.getFactor().equals(alert.getFactor())
                                && r.getLevel() == alert.getLevel()
                                && r.getTimestamp().isAfter(cutoff));
                if (duplicate) continue;

                alertRepo.save(alert);
                log.info("Re-evaluated alert after threshold change [{}]: {} - {}",
                        deviceId, alert.getLevel(), alert.getMessage());
            }
        } catch (Exception e) {
            log.error("Failed to re-evaluate latest reading after threshold change for {}",
                    deviceId, e);
        }
    }

    /** รีเซ็ตกลับไปใช้ค่า default ของระบบ */
    public ThresholdSettings resetToDefault(String deviceId) {
        try {
            repo.delete(deviceId);
        } catch (Exception e) {
            log.error("Failed to reset threshold settings for {}", deviceId, e);
            throw new RuntimeException("Database error", e);
        }
        return fromDefaults(deviceId);
    }

    // ──────────────────────────────────────────────

    private Optional<ThresholdSettings> safeFind(String deviceId) {
        try {
            return repo.findByDeviceId(deviceId);
        } catch (Exception e) {
            log.error("Failed to load threshold settings for {}", deviceId, e);
            return Optional.empty();
        }
    }

    private ThresholdSettings fromDefaults(String deviceId) {
        return ThresholdSettings.builder()
                .deviceId(deviceId)
                .co2Warning(defaults.getCo2Warning())
                .co2Critical(defaults.getCo2Critical())
                .temperatureMin(defaults.getTemperatureMin())
                .temperatureMax(defaults.getTemperatureMax())
                .temperatureCriticalMin(defaults.getTemperatureCriticalMin())
                .temperatureCriticalMax(defaults.getTemperatureCriticalMax())
                .humidityMin(defaults.getHumidityMin())
                .humidityMax(defaults.getHumidityMax())
                .humidityCriticalMin(defaults.getHumidityCriticalMin())
                .humidityCriticalMax(defaults.getHumidityCriticalMax())
                .pm25Warning(defaults.getPm25Warning())
                .pm25Critical(defaults.getPm25Critical())
                .lightMax(defaults.getLightMax())
                .lightCritical(defaults.getLightCritical())
                .noiseWarning(defaults.getNoiseWarning())
                .noiseCritical(defaults.getNoiseCritical())
                .customized(false)
                .build();
    }

    private ThresholdConfig merge(ThresholdSettings s) {
        ThresholdConfig eff = new ThresholdConfig();
        eff.setCo2Warning(nz(s.getCo2Warning(), defaults.getCo2Warning()));
        eff.setCo2Critical(nz(s.getCo2Critical(), defaults.getCo2Critical()));
        eff.setTemperatureMin(nz(s.getTemperatureMin(), defaults.getTemperatureMin()));
        eff.setTemperatureMax(nz(s.getTemperatureMax(), defaults.getTemperatureMax()));
        eff.setTemperatureCriticalMin(nz(s.getTemperatureCriticalMin(), defaults.getTemperatureCriticalMin()));
        eff.setTemperatureCriticalMax(nz(s.getTemperatureCriticalMax(), defaults.getTemperatureCriticalMax()));
        eff.setHumidityMin(nz(s.getHumidityMin(), defaults.getHumidityMin()));
        eff.setHumidityMax(nz(s.getHumidityMax(), defaults.getHumidityMax()));
        eff.setHumidityCriticalMin(nz(s.getHumidityCriticalMin(), defaults.getHumidityCriticalMin()));
        eff.setHumidityCriticalMax(nz(s.getHumidityCriticalMax(), defaults.getHumidityCriticalMax()));
        eff.setPm25Warning(nz(s.getPm25Warning(), defaults.getPm25Warning()));
        eff.setPm25Critical(nz(s.getPm25Critical(), defaults.getPm25Critical()));
        eff.setLightMax(nz(s.getLightMax(), defaults.getLightMax()));
        eff.setLightCritical(nz(s.getLightCritical(), defaults.getLightCritical()));
        eff.setNoiseWarning(nz(s.getNoiseWarning(), defaults.getNoiseWarning()));
        eff.setNoiseCritical(nz(s.getNoiseCritical(), defaults.getNoiseCritical()));
        return eff;
    }

    private double nz(Double v, double fallback) {
        return v != null ? v : fallback;
    }

    /**
     * กันผู้ใช้ตั้งค่าพัง เช่น warning มากกว่า critical หรือ min มากกว่า max
     * ค่าที่เป็น null (ไม่ได้ส่งมา) จะข้ามการเช็ค แล้วไปใช้ default ตอน merge
     */
    private void validate(ThresholdSettings s) {
        requireOrder(s.getTemperatureCriticalMin(), s.getTemperatureMin(),
                "Temperature critical-min ต้องน้อยกว่า min");
        requireOrder(s.getTemperatureMin(), s.getTemperatureMax(),
                "Temperature min ต้องน้อยกว่า max");
        requireOrder(s.getTemperatureMax(), s.getTemperatureCriticalMax(),
                "Temperature max ต้องน้อยกว่า critical-max");

        requireOrder(s.getHumidityCriticalMin(), s.getHumidityMin(),
                "Humidity critical-min ต้องน้อยกว่า min");
        requireOrder(s.getHumidityMin(), s.getHumidityMax(),
                "Humidity min ต้องน้อยกว่า max");
        requireOrder(s.getHumidityMax(), s.getHumidityCriticalMax(),
                "Humidity max ต้องน้อยกว่า critical-max");

        requireOrder(s.getCo2Warning(), s.getCo2Critical(),
                "CO2 warning ต้องน้อยกว่า critical");
        requireOrder(s.getPm25Warning(), s.getPm25Critical(),
                "PM2.5 warning ต้องน้อยกว่า critical");
        requireOrder(s.getNoiseWarning(), s.getNoiseCritical(),
                "Noise warning ต้องน้อยกว่า critical");
        requireOrder(s.getLightMax(), s.getLightCritical(),
                "Light max ต้องน้อยกว่า critical");
    }

    private void requireOrder(Double smaller, Double larger, String message) {
        if (smaller != null && larger != null && smaller >= larger) {
            throw new IllegalArgumentException(message);
        }
    }
}