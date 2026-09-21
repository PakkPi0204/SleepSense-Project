package com.sleepsense.analysis;

/**
 * The verdict for a single environmental factor within a {@link ThresholdResult}.
 */
public class FactorResult {

    private final String factor;
    private final String status;

    /** The measured value, or null when that sensor reported nothing. */
    private final Double value;

    /** The threshold the value was compared against — null while normal. */
    private final Double threshold;

    public FactorResult(String factor, String status, Double value, Double threshold) {
        this.factor = factor;
        this.status = status;
        this.value = value;
        this.threshold = threshold;
    }

    public static FactorResult normal(String factor, Double value) {
        return new FactorResult(factor, ThresholdResult.STATUS_NORMAL, value, null);
    }

    public static FactorResult warning(String factor, Double value, Double threshold) {
        return new FactorResult(factor, ThresholdResult.STATUS_WARNING, value, threshold);
    }

    public static FactorResult critical(String factor, Double value, Double threshold) {
        return new FactorResult(factor, ThresholdResult.STATUS_CRITICAL, value, threshold);
    }

    public String getFactor() {
        return factor;
    }

    public String getStatus() {
        return status;
    }

    public Double getValue() {
        return value;
    }

    public Double getThreshold() {
        return threshold;
    }

    public boolean isNormal() {
        return ThresholdResult.STATUS_NORMAL.equals(status);
    }

    public boolean isWarning() {
        return ThresholdResult.STATUS_WARNING.equals(status);
    }

    public boolean isCritical() {
        return ThresholdResult.STATUS_CRITICAL.equals(status);
    }

    @Override
    public String toString() {
        return factor + ": " + status + " (value: " + value + ")";
    }
}
