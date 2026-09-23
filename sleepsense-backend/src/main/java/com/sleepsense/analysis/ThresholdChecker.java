package com.sleepsense.analysis;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.SensorData;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Compares a sensor snapshot against the configured thresholds and classifies
 * every factor as normal, warning or critical.
 *
 * <p>Test Plan reference: UTC-02 ({@code utils/thresholdChecker.js ->
 * checkThreshold()}). {@link ThresholdAnalyzer} turns the same comparison into
 * {@code Alert} rows for persistence; this class exposes the raw verdict so the
 * pipeline and the unit tests can reason about it without touching the database.
 *
 * <p>A factor whose sensor is not connected is reported as normal rather than as
 * an alert. The "not connected" convention matches the rest of the system:
 * temperature and humidity below zero, and CO2 at or below zero.
 */
@Component
@RequiredArgsConstructor
public class ThresholdChecker {

    /** Default config, used when the caller does not supply an effective one. */
    private final ThresholdConfig defaultCfg;

    public ThresholdResult checkThreshold(SensorData data) {
        return checkThreshold(data, defaultCfg);
    }

    public ThresholdResult checkThreshold(SensorData data, ThresholdConfig cfg) {
        Map<String, FactorResult> factors = new LinkedHashMap<>();

        factors.put(ThresholdResult.CO2, upperBound(
                ThresholdResult.CO2,
                data.getCo2() <= 0 ? null : data.getCo2(),
                cfg.getCo2Warning(), cfg.getCo2Critical()));

        factors.put(ThresholdResult.TEMPERATURE, range(
                ThresholdResult.TEMPERATURE,
                data.getTemperature() < 0 ? null : data.getTemperature(),
                cfg.getTemperatureMin(), cfg.getTemperatureMax(),
                cfg.getTemperatureCriticalMin(), cfg.getTemperatureCriticalMax()));

        factors.put(ThresholdResult.HUMIDITY, range(
                ThresholdResult.HUMIDITY,
                data.getHumidity() < 0 ? null : data.getHumidity(),
                cfg.getHumidityMin(), cfg.getHumidityMax(),
                cfg.getHumidityCriticalMin(), cfg.getHumidityCriticalMax()));

        factors.put(ThresholdResult.PM25, upperBound(
                ThresholdResult.PM25, data.getPm25(),
                cfg.getPm25Warning(), cfg.getPm25Critical()));

        factors.put(ThresholdResult.LIGHT, upperBound(
                ThresholdResult.LIGHT, data.getLightIntensity(),
                cfg.getLightMax(), cfg.getLightCritical()));

        factors.put(ThresholdResult.NOISE, upperBound(
                ThresholdResult.NOISE, data.getNoiseLevel(),
                cfg.getNoiseWarning(), cfg.getNoiseCritical()));

        return new ThresholdResult(factors);
    }

    /** Factors that only get worse in one direction: CO2, PM2.5, light, noise. */
    private FactorResult upperBound(String factor, Double value,
                                    double warning, double critical) {
        if (value == null) return FactorResult.normal(factor, null);
        if (value >= critical) return FactorResult.critical(factor, value, critical);
        if (value >= warning) return FactorResult.warning(factor, value, warning);
        return FactorResult.normal(factor, value);
    }

    /** Factors with both a lower and an upper bound: temperature and humidity. */
    private FactorResult range(String factor, Double value,
                               double min, double max,
                               double criticalMin, double criticalMax) {
        if (value == null) return FactorResult.normal(factor, null);
        if (value > criticalMax) return FactorResult.critical(factor, value, criticalMax);
        if (value < criticalMin) return FactorResult.critical(factor, value, criticalMin);
        if (value > max) return FactorResult.warning(factor, value, max);
        if (value < min) return FactorResult.warning(factor, value, min);
        return FactorResult.normal(factor, value);
    }
}
