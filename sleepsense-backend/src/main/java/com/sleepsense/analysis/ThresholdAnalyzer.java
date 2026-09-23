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
 * Compares sensor values against thresholds and produces alerts and advice.
 *
 * The caller always supplies the effective threshold config — SensorService
 * looks up the device's own settings first and falls back to the defaults — so
 * each user can tune how sensitive their alerts are. Some people need a cooler
 * room than average, or react more strongly to dust or noise.
 */
@Component
@RequiredArgsConstructor
public class ThresholdAnalyzer {

    /** Default config, used when the caller does not supply an effective one (e.g. tests). */
    private final ThresholdConfig defaultCfg;

    /**
     * Analyse one round of sensor data and return the alerts it raises.
     */
    public List<Alert> analyze(SensorData data) {
        return analyze(data, defaultCfg);
    }

    public List<Alert> analyze(SensorData data, ThresholdConfig cfg) {
        List<Alert> alerts = new ArrayList<>();

        checkCo2(data, alerts, cfg);
        checkTemperature(data, alerts, cfg);
        checkHumidity(data, alerts, cfg);
        checkPm25(data, alerts, cfg);
        checkLight(data, alerts, cfg);
        checkNoise(data, alerts, cfg);

        return alerts;
    }

    /**
     * Build pre-sleep advice from the current sensor data.
     */
    public List<String> generatePreSleepSuggestions(SensorData data) {
        return generatePreSleepSuggestions(data, defaultCfg);
    }

    public List<String> generatePreSleepSuggestions(SensorData data, ThresholdConfig cfg) {
        List<String> suggestions = new ArrayList<>();

        if (data.getCo2() > cfg.getCo2Warning())
            suggestions.add("CO2 is high (" + (int) data.getCo2() + " ppm) — open a window to air the room before bed");

        if (data.getTemperature() > cfg.getTemperatureMax())
            suggestions.add("Temperature is too high (" + data.getTemperature() + "°C) — turn on a fan or the air conditioning");
        else if (data.getTemperature() < cfg.getTemperatureMin())
            suggestions.add("Temperature is too low (" + data.getTemperature() + "°C) — warm the room up");

        if (data.getHumidity() > cfg.getHumidityMax())
            suggestions.add("Humidity is high (" + data.getHumidity() + "%) — run a dehumidifier");
        else if (data.getHumidity() < cfg.getHumidityMin())
            suggestions.add("Humidity is low (" + data.getHumidity() + "%) — run a humidifier");

        if (data.getPm25() > cfg.getPm25Warning())
            suggestions.add("PM2.5 is high (" + data.getPm25() + " µg/m³) — turn on an air purifier");

        if (data.getLightIntensity() > cfg.getLightMax())
            suggestions.add("The room is too bright (" + (int) data.getLightIntensity() + " lux) — turn the lights off or use blackout curtains");

        if (data.getNoiseLevel() > cfg.getNoiseWarning())
            suggestions.add("Background noise (" + (int) data.getNoiseLevel() + " dB) — reduce the source or use earplugs");

        if (suggestions.isEmpty())
            suggestions.add("Your bedroom is in good shape for sleep");

        return suggestions;
    }

    // ──────────────────────────────────────────────
    // Private checkers
    // ──────────────────────────────────────────────

    private void checkCo2(SensorData d, List<Alert> out, ThresholdConfig cfg) {
        if (d.getCo2() >= cfg.getCo2Critical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "CO2",
                    "Critical CO2 level: " + (int) d.getCo2() + " ppm — open a window now",
                    d.getCo2(), cfg.getCo2Critical()));
        } else if (d.getCo2() >= cfg.getCo2Warning()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "CO2",
                    "High CO2 level: " + (int) d.getCo2() + " ppm — the room needs airing out",
                    d.getCo2(), cfg.getCo2Warning()));
        }
    }

    private void checkTemperature(SensorData d, List<Alert> out, ThresholdConfig cfg) {
        double t = d.getTemperature();
        if (t > cfg.getTemperatureCriticalMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "TEMPERATURE",
                    "Critically high temperature: " + t + "°C — unsafe to sleep in",
                    t, cfg.getTemperatureCriticalMax()));
        } else if (t > cfg.getTemperatureMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "TEMPERATURE",
                    "Temperature is too high: " + t + "°C",
                    t, cfg.getTemperatureMax()));
        } else if (t < cfg.getTemperatureCriticalMin()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "TEMPERATURE",
                    "Critically low temperature: " + t + "°C — unsafe to sleep in",
                    t, cfg.getTemperatureCriticalMin()));
        } else if (t < cfg.getTemperatureMin()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "TEMPERATURE",
                    "Temperature is too low: " + t + "°C",
                    t, cfg.getTemperatureMin()));
        }
    }

    private void checkHumidity(SensorData d, List<Alert> out, ThresholdConfig cfg) {
        double h = d.getHumidity();
        if (h > cfg.getHumidityCriticalMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "HUMIDITY",
                    "Critically high humidity: " + h + "% — risk of mould and dust mites",
                    h, cfg.getHumidityCriticalMax()));
        } else if (h > cfg.getHumidityMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "HUMIDITY",
                    "Humidity is too high: " + h + "%",
                    h, cfg.getHumidityMax()));
        } else if (h < cfg.getHumidityCriticalMin()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "HUMIDITY",
                    "Critically low humidity: " + h + "% — irritating to the airways",
                    h, cfg.getHumidityCriticalMin()));
        } else if (h < cfg.getHumidityMin()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "HUMIDITY",
                    "Humidity is too low: " + h + "%",
                    h, cfg.getHumidityMin()));
        }
    }

    private void checkPm25(SensorData d, List<Alert> out, ThresholdConfig cfg) {
        if (d.getPm25() >= cfg.getPm25Critical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "PM25",
                    "Critical PM2.5 level: " + d.getPm25() + " µg/m³",
                    d.getPm25(), cfg.getPm25Critical()));
        } else if (d.getPm25() >= cfg.getPm25Warning()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "PM25",
                    "High PM2.5 level: " + d.getPm25() + " µg/m³ — run an air purifier",
                    d.getPm25(), cfg.getPm25Warning()));
        }
    }

    private void checkLight(SensorData d, List<Alert> out, ThresholdConfig cfg) {
        double lux = d.getLightIntensity();
        if (lux > cfg.getLightCritical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "LIGHT",
                    "Critical light level: " + (int) lux + " lux — as bright as the main light",
                    lux, cfg.getLightCritical()));
        } else if (lux > cfg.getLightMax()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "LIGHT",
                    "The room is too bright: " + (int) lux + " lux",
                    lux, cfg.getLightMax()));
        }
    }

    private void checkNoise(SensorData d, List<Alert> out, ThresholdConfig cfg) {
        if (d.getNoiseLevel() >= cfg.getNoiseCritical()) {
            out.add(buildAlert(d, Alert.AlertLevel.CRITICAL, "NOISE",
                    "Critical noise level: " + (int) d.getNoiseLevel() + " dB",
                    d.getNoiseLevel(), cfg.getNoiseCritical()));
        } else if (d.getNoiseLevel() >= cfg.getNoiseWarning()) {
            out.add(buildAlert(d, Alert.AlertLevel.WARNING, "NOISE",
                    "Background noise: " + (int) d.getNoiseLevel() + " dB",
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
