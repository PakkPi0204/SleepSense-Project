package com.sleepsense.analysis;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.MorningReport;
import com.sleepsense.model.SensorData;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.OptionalDouble;

/**
 * Builds a Morning Report from a whole night of readings.
 */
@Component
public class MorningReportGenerator {

    private final EnvironmentClusterer clusterer;

    /** Default config, used when the caller does not supply an effective one (e.g. tests). */
    private final ThresholdConfig defaultCfg;

    public MorningReportGenerator(EnvironmentClusterer clusterer, ThresholdConfig defaultCfg) {
        this.clusterer = clusterer;
        this.defaultCfg = defaultCfg;
    }

    public MorningReport generate(String deviceId, List<SensorData> data,
                                   Instant sleepStart, Instant sleepEnd) {
        return generate(deviceId, data, sleepStart, sleepEnd, defaultCfg);
    }

    /**
     * @param cfg this device's effective thresholds (custom if any, otherwise
     *            the defaults). Callers should always take this from
     *            ThresholdSettingsService.getEffective(deviceId) so anomalies
     *            and suggestions stay in step with what the user configured.
     */
    public MorningReport generate(String deviceId, List<SensorData> data,
                                   Instant sleepStart, Instant sleepEnd, ThresholdConfig cfg) {
        if (data.isEmpty()) {
            return MorningReport.builder()
                    .deviceId(deviceId)
                    .sleepStart(sleepStart)
                    .sleepEnd(sleepEnd)
                    .environmentCluster("UNKNOWN")
                    .generatedAt(Instant.now())
                    .build();
        }

        // ─── Averages ───
        double avgTemp  = avg(data, d -> d.getTemperature());
        double avgHum   = avg(data, d -> d.getHumidity());
        double avgCo2   = avg(data, d -> d.getCo2());
        double avgPm25  = avg(data, d -> d.getPm25());
        double avgLight = avg(data, d -> d.getLightIntensity());
        double avgNoise = avg(data, d -> d.getNoiseLevel());

        // ─── Max values ───
        double maxTemp  = max(data, d -> d.getTemperature());
        double maxCo2   = max(data, d -> d.getCo2());
        double maxPm25  = max(data, d -> d.getPm25());
        double maxNoise = max(data, d -> d.getNoiseLevel());

        // ─── Motion ───
        long motionCount = data.stream().filter(SensorData::isMotionDetected).count();
        String motionPattern = motionCount < 5 ? "LOW"
                             : motionCount < 15 ? "MODERATE"
                             : "HIGH";

        // ─── Clustering ───
        String cluster = clusterer.cluster(data);

        // ─── Anomalies ───
        List<String> anomalies = detectAnomalies(avgTemp, maxCo2, maxPm25, maxNoise, motionPattern, cfg);

        // ─── Suggestions ───
        List<String> suggestions = buildSuggestions(avgTemp, avgCo2, avgPm25, avgNoise, motionPattern, cluster, cfg);

        // ─── Data completeness ───
        // The ESP32 posts every 30s = 2 samples/minute, so work out what share
        // of the expected samples actually arrived.
        long minutes = java.time.Duration.between(sleepStart, sleepEnd).toMinutes();
        int expected = (int) Math.max(1, minutes * 2); // at least 1, to avoid dividing by zero
        int completeness = (int) Math.min(100, Math.round(data.size() * 100.0 / expected));

        return MorningReport.builder()
                .deviceId(deviceId)
                .sleepStart(sleepStart)
                .sleepEnd(sleepEnd)
                .avgTemperature(round(avgTemp))
                .avgHumidity(round(avgHum))
                .avgCo2(round(avgCo2))
                .avgPm25(round(avgPm25))
                .avgLight(round(avgLight))
                .avgNoise(round(avgNoise))
                .maxTemperature(round(maxTemp))
                .maxCo2(round(maxCo2))
                .maxPm25(round(maxPm25))
                .maxNoise(round(maxNoise))
                .motionEventCount((int) motionCount)
                .motionPattern(motionPattern)
                .environmentCluster(cluster)
                .dataCompleteness(completeness)
                .anomalies(anomalies)
                .suggestions(suggestions)
                .generatedAt(Instant.now())
                .build();
    }

    // ──────────────────────────────────────────────
    private List<String> detectAnomalies(double avgTemp, double maxCo2,
                                          double maxPm25, double maxNoise,
                                          String motionPattern, ThresholdConfig cfg) {
        List<String> anomalies = new ArrayList<>();
        if (avgTemp > cfg.getTemperatureMax())
            anomalies.add("Average temperature stayed high all night (" + avgTemp + "°C)");
        if (maxCo2 > cfg.getCo2Warning())
            anomalies.add("Peak CO2 went over the recommended limit (" + (int) maxCo2 + " ppm)");
        if (maxPm25 > cfg.getPm25Warning())
            anomalies.add("Peak PM2.5 went over the recommended limit (" + maxPm25 + " µg/m³)");
        if (maxNoise > cfg.getNoiseCritical())
            anomalies.add("Loud noise was recorded (" + (int) maxNoise + " dB)");
        if ("HIGH".equals(motionPattern)) anomalies.add("Frequent movement was detected during the night");
        return anomalies;
    }

    private List<String> buildSuggestions(double avgTemp, double avgCo2, double avgPm25,
                                           double avgNoise, String motionPattern, String cluster,
                                           ThresholdConfig cfg) {
        List<String> s = new ArrayList<>();

        if (avgTemp > cfg.getTemperatureMax())
            s.add("Try setting the air conditioning to " + (int) cfg.getTemperatureMin()
                    + "-" + (int) cfg.getTemperatureMax() + "°C for a more comfortable night");
        if (avgCo2 > cfg.getCo2Warning())
            s.add("Open a window or improve ventilation before bed to bring CO2 down");
        if (avgPm25 > cfg.getPm25Warning())
            s.add("Run an air purifier in the bedroom to reduce PM2.5");
        if (avgNoise > cfg.getNoiseWarning())
            s.add("Reduce noise sources, or mask them with white noise");
        if ("HIGH".equals(motionPattern))
            s.add("Frequent movement often means discomfort — check the temperature and your mattress");
        if ("GOOD".equals(cluster))
            s.add("Your bedroom environment was good overall — keep it up");
        if (s.isEmpty())
            s.add("Your bedroom environment was within range. No further suggestions");

        return s;
    }

    // ──────────────────────────────────────────────
    private double avg(List<SensorData> data, java.util.function.ToDoubleFunction<SensorData> fn) {
        OptionalDouble r = data.stream().mapToDouble(fn).average();
        return r.isPresent() ? r.getAsDouble() : 0.0;
    }

    private double max(List<SensorData> data, java.util.function.ToDoubleFunction<SensorData> fn) {
        OptionalDouble r = data.stream().mapToDouble(fn).max();
        return r.isPresent() ? r.getAsDouble() : 0.0;
    }

    private double round(double v) {
        return Math.round(v * 10.0) / 10.0;
    }
}