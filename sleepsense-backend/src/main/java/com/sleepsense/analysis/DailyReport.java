package com.sleepsense.analysis;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Per-factor average / minimum / maximum across a set of readings.
 *
 * <p>Test Plan reference: UTC-03 ({@code calculateDailyAverage()}).
 */
public class DailyReport {

    /** avg / min / max for one factor. All null when no reading carried a value. */
    public static class FactorSummary {
        private final Double avg;
        private final Double min;
        private final Double max;

        public static final FactorSummary EMPTY = new FactorSummary(null, null, null);

        public FactorSummary(Double avg, Double min, Double max) {
            this.avg = avg;
            this.min = min;
            this.max = max;
        }

        public Double getAvg() {
            return avg;
        }

        public Double getMin() {
            return min;
        }

        public Double getMax() {
            return max;
        }

        public boolean isEmpty() {
            return avg == null && min == null && max == null;
        }

        @Override
        public String toString() {
            return "{avg: " + avg + ", min: " + min + ", max: " + max + "}";
        }
    }

    private final Map<String, FactorSummary> factors;
    private final int sampleCount;
    private final int motionEventCount;

    public DailyReport(Map<String, FactorSummary> factors,
                       int sampleCount, int motionEventCount) {
        this.factors = Collections.unmodifiableMap(new LinkedHashMap<>(factors));
        this.sampleCount = sampleCount;
        this.motionEventCount = motionEventCount;
    }

    public Map<String, FactorSummary> getFactors() {
        return factors;
    }

    /** Look a factor up by the keys on {@link ThresholdResult}. */
    public FactorSummary get(String factor) {
        return factors.getOrDefault(factor, FactorSummary.EMPTY);
    }

    public FactorSummary getCo2() {
        return get(ThresholdResult.CO2);
    }

    public FactorSummary getTemperature() {
        return get(ThresholdResult.TEMPERATURE);
    }

    public FactorSummary getHumidity() {
        return get(ThresholdResult.HUMIDITY);
    }

    public FactorSummary getPm25() {
        return get(ThresholdResult.PM25);
    }

    public FactorSummary getLight() {
        return get(ThresholdResult.LIGHT);
    }

    public FactorSummary getNoise() {
        return get(ThresholdResult.NOISE);
    }

    public int getSampleCount() {
        return sampleCount;
    }

    public int getMotionEventCount() {
        return motionEventCount;
    }

    /** LOW / MODERATE / HIGH, using the same cut-offs as MorningReportGenerator. */
    public String getMotionPattern() {
        if (motionEventCount < 5) return "LOW";
        if (motionEventCount < 15) return "MODERATE";
        return "HIGH";
    }
}
