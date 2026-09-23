package com.sleepsense.analysis;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The outcome of evaluating one {@link com.sleepsense.model.SensorData} snapshot
 * against a threshold configuration.
 *
 * <p>Test Plan reference: UTC-02 ({@code checkThreshold()}). The status strings
 * are the ones the Test Plan asserts on: {@code normal}, {@code warning},
 * {@code critical}.
 */
public class ThresholdResult {

    /** Canonical factor keys — the same strings used in {@code Alert.factor}. */
    public static final String CO2 = "CO2";
    public static final String TEMPERATURE = "TEMPERATURE";
    public static final String HUMIDITY = "HUMIDITY";
    public static final String PM25 = "PM25";
    public static final String LIGHT = "LIGHT";
    public static final String NOISE = "NOISE";

    /** The six environmental factors, in the order the Test Plan lists them. */
    public static final List<String> ALL_FACTORS =
            List.of(CO2, TEMPERATURE, HUMIDITY, PM25, LIGHT, NOISE);

    public static final String STATUS_NORMAL = "normal";
    public static final String STATUS_WARNING = "warning";
    public static final String STATUS_CRITICAL = "critical";

    private final Map<String, FactorResult> factors;

    public ThresholdResult(Map<String, FactorResult> factors) {
        this.factors = Collections.unmodifiableMap(new LinkedHashMap<>(factors));
    }

    public Map<String, FactorResult> getFactors() {
        return factors;
    }

    public FactorResult get(String factor) {
        return factors.get(factor);
    }

    /** Convenience for {@code get(factor).getStatus()}. */
    public String statusOf(String factor) {
        FactorResult result = factors.get(factor);
        return result == null ? STATUS_NORMAL : result.getStatus();
    }

    /** True when at least one factor crossed its critical threshold. */
    public boolean isCritical() {
        return factors.values().stream().anyMatch(FactorResult::isCritical);
    }

    /** True when at least one factor sits in the warning band. */
    public boolean hasWarning() {
        return factors.values().stream().anyMatch(FactorResult::isWarning);
    }

    /**
     * Every factor that is not normal, critical ones first. Empty when the whole
     * room is in range — UTC-02.01's "no warnings or alerts".
     */
    public List<FactorResult> getAlertFactors() {
        List<FactorResult> flagged = new ArrayList<>();
        for (FactorResult result : factors.values()) {
            if (!result.isNormal()) flagged.add(result);
        }
        flagged.sort(Comparator.comparing(FactorResult::isCritical).reversed());
        return flagged;
    }

    /** Just the critical factors — one push notification is sent per entry. */
    public List<FactorResult> getCriticalFactors() {
        List<FactorResult> critical = new ArrayList<>();
        for (FactorResult result : factors.values()) {
            if (result.isCritical()) critical.add(result);
        }
        return critical;
    }

    @Override
    public String toString() {
        return "ThresholdResult" + factors.values();
    }
}
