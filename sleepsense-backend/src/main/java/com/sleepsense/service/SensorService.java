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
     * Receive a reading from the ESP32: store it, analyse it, and raise alerts
     * for anything over threshold (custom thresholds if set, otherwise defaults).
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

        // Analyse against this device's own thresholds when it has any.
        ThresholdConfig effective = thresholdSettingsService.getEffective(req.getDeviceId());

        List<Alert> alerts = analyzer.analyze(data, effective);
        processAlerts(req.getDeviceId(), alerts);

        return data;
    }

    /**
     * This used to insert a new Alert row every time analyze() found a problem,
     * so an ongoing problem (a room that stays too warm for several minutes)
     * produced a fresh row every 30 seconds, and nothing ever recorded that the
     * problem had cleared. The frontend had to guess which rows were still true
     * (see DashboardMapper.isFactorCritical on the Flutter side, which was a
     * stopgap).
     *
     * The backend now owns the resolved/active state:
     *   1) a factor that was active but is no longer flagged this round (value
     *      back to normal, or thresholds widened) is resolved;
     *   2) a factor still flagged at the same level as the active row is left
     *      alone, so the collection is not spammed with duplicates;
     *   3) a factor whose level changed (WARNING escalating to CRITICAL) or that
     *      was not active before resolves the old row (if any) and inserts a new
     *      one.
     */
    private void processAlerts(String deviceId, List<Alert> alerts) {
        List<Alert> activeAlerts;
        try {
            activeAlerts = alertRepo.findActiveByDevice(deviceId);
        } catch (Exception e) {
            log.error("Failed to fetch active alerts for device {}", deviceId, e);
            // The active list is unavailable — insert directly as before. A
            // duplicate beats silently losing this round's critical alert.
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

        // 1) Resolve alerts for factors that are no longer a problem.
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

        // 2)/3) Insert only for factors with no active alert at the same level.
        for (Alert alert : alerts) {
            Alert existingActive = activeAlerts.stream()
                    .filter(a -> a.getFactor().equals(alert.getFactor()))
                    .findFirst()
                    .orElse(null);

            if (existingActive != null && existingActive.getLevel() == alert.getLevel()) {
                continue; // same problem, same level, still ongoing
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

    /**
     * The latest reading for a device, as the pipeline consumes it.
     *
     * <p>Test Plan reference: UTC-01 ({@code getSensorData()}). Where the Flutter
     * client mocks an HTTP GET of /api/sensor/latest, the server-side equivalent
     * mocks the repository — both end up asking the same question.
     *
     * <ul>
     *   <li>a stored reading comes back as-is (UTC-01.01);</li>
     *   <li>no stored reading yields an empty {@link SensorData} whose fields are
     *       all zero rather than a null or an exception (UTC-01.02);</li>
     *   <li>a datastore failure throws, with a non-null message (UTC-01.03).</li>
     * </ul>
     */
    public SensorData getSensorData(String deviceId) {
        return getLatest(deviceId).orElseGet(() -> SensorData.builder()
                .deviceId(deviceId)
                .timestamp(Instant.now())
                .build());
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
