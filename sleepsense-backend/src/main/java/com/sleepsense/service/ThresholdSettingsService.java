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
 * Manages per-device custom thresholds, overriding the defaults in
 * ThresholdConfig for people who need a cooler room, or who are more
 * sensitive to dust or noise than average.
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

    /** Stops duplicate alerts when the user saves several times in quick succession. */
    private static final long DEDUPE_WINDOW_SECONDS = 15;

    /** This device's effective thresholds — custom if any, otherwise the defaults. */
    public ThresholdConfig getEffective(String deviceId) {
        Optional<ThresholdSettings> custom = safeFind(deviceId);
        return custom.map(this::merge).orElse(defaults);
    }

    /** Values for the settings screen — the defaults with customized=false when nothing was saved. */
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

        // Alerts used to be raised only when the ESP32 posted a new reading (see
        // SensorService.ingest()), so tightening a threshold when the room was
        // already past the new critical point produced no alert until the next
        // sample arrived, up to 30 seconds later. Re-checking the latest stored
        // reading right here makes a threshold change feel immediate.
        reEvaluateLatestReading(deviceId, merge(saved));

        return saved;
    }

    /**
     * Re-evaluate the most recent stored reading against the new thresholds
     * immediately after a save, raising an alert without waiting for the next
     * ESP32 round. A failure here must not fail the threshold save itself.
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

    /** Reset this device back to the system defaults. */
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
     * Reject nonsensical settings such as warning above critical, or min above
     * max. Fields left null are skipped here and filled from the defaults on merge.
     */
    private void validate(ThresholdSettings s) {
        requireOrder(s.getTemperatureCriticalMin(), s.getTemperatureMin(),
                "Temperature critical-min must be lower than min");
        requireOrder(s.getTemperatureMin(), s.getTemperatureMax(),
                "Temperature min must be lower than max");
        requireOrder(s.getTemperatureMax(), s.getTemperatureCriticalMax(),
                "Temperature max must be lower than critical-max");

        requireOrder(s.getHumidityCriticalMin(), s.getHumidityMin(),
                "Humidity critical-min must be lower than min");
        requireOrder(s.getHumidityMin(), s.getHumidityMax(),
                "Humidity min must be lower than max");
        requireOrder(s.getHumidityMax(), s.getHumidityCriticalMax(),
                "Humidity max must be lower than critical-max");

        requireOrder(s.getCo2Warning(), s.getCo2Critical(),
                "CO2 warning must be lower than critical");
        requireOrder(s.getPm25Warning(), s.getPm25Critical(),
                "PM2.5 warning must be lower than critical");
        requireOrder(s.getNoiseWarning(), s.getNoiseCritical(),
                "Noise warning must be lower than critical");
        requireOrder(s.getLightMax(), s.getLightCritical(),
                "Light max must be lower than critical");
    }

    private void requireOrder(Double smaller, Double larger, String message) {
        if (smaller != null && larger != null && smaller >= larger) {
            throw new IllegalArgumentException(message);
        }
    }
}