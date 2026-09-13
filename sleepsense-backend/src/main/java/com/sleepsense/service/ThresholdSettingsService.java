package com.sleepsense.service;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.ThresholdSettings;
import com.sleepsense.repository.ThresholdSettingsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

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
        return getSettingsOrDefault(deviceId);
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
