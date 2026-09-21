package com.sleepsense.analysis;

import com.sleepsense.model.SensorData;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.ToDoubleFunction;

/**
 * Aggregates a night's worth of readings into per-factor avg / min / max.
 *
 * <p>Test Plan reference: UTC-03 ({@code utils/reportHelper.js ->
 * calculateDailyAverage()}). {@link MorningReportGenerator} uses the same
 * arithmetic when it builds a persisted Morning Report; this class exposes it on
 * its own so it can be unit tested without Firestore.
 */
@Component
public class ReportHelper {

    /**
     * @return null when {@code readings} is null or empty — UTC-03.02 asks for
     *         "null or all-null fields", and never for a thrown exception.
     */
    public DailyReport calculateDailyAverage(List<SensorData> readings) {
        if (readings == null || readings.isEmpty()) return null;

        Map<String, DailyReport.FactorSummary> factors = new LinkedHashMap<>();
        factors.put(ThresholdResult.CO2,
                summarise(readings, SensorData::getCo2));
        factors.put(ThresholdResult.TEMPERATURE,
                summarise(readings, SensorData::getTemperature));
        factors.put(ThresholdResult.HUMIDITY,
                summarise(readings, SensorData::getHumidity));
        factors.put(ThresholdResult.PM25,
                summarise(readings, SensorData::getPm25));
        factors.put(ThresholdResult.LIGHT,
                summarise(readings, SensorData::getLightIntensity));
        factors.put(ThresholdResult.NOISE,
                summarise(readings, SensorData::getNoiseLevel));

        int motionEvents = (int) readings.stream()
                .filter(SensorData::isMotionDetected)
                .count();

        return new DailyReport(factors, readings.size(), motionEvents);
    }

    private DailyReport.FactorSummary summarise(List<SensorData> readings,
                                                ToDoubleFunction<SensorData> pick) {
        double sum = 0;
        double min = Double.MAX_VALUE;
        double max = -Double.MAX_VALUE;
        int count = 0;

        for (SensorData reading : readings) {
            double value = pick.applyAsDouble(reading);
            sum += value;
            if (value < min) min = value;
            if (value > max) max = value;
            count++;
        }

        if (count == 0) return DailyReport.FactorSummary.EMPTY;
        return new DailyReport.FactorSummary(sum / count, min, max);
    }
}
