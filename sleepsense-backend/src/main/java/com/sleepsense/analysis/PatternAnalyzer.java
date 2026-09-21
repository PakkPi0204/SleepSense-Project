package com.sleepsense.analysis;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.MorningReport;
import org.springframework.stereotype.Component;

import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

/**
 * Turns several nights of Morning Reports into Smart Suggestions.
 *
 * <p>Test Plan reference: STC-04. A Smart Suggestion is "smart" because it comes
 * from history rather than from one reading: nights are clustered by their
 * environmental and motion profile, a condition only counts as a pattern when it
 * recurs across most nights of a cluster, and each recommendation names the
 * pattern it came from.
 *
 * <p>Clustering is k-means over min-max normalised feature vectors. Centroids
 * are seeded from the two most distant nights rather than at random, so the same
 * input always produces the same grouping — a test that asserts "Pattern A
 * nights land together" must not be flaky.
 */
@Component
public class PatternAnalyzer {

    /** STC-04 requires at least 3 nights before any historical claim is made. */
    public static final int MIN_NIGHTS = 3;

    /** A condition must recur on this share of a cluster's nights to be a pattern. */
    private static final double RECURRENCE_THRESHOLD = 0.6;

    /** ...and on at least this many nights, so 1-of-1 never looks like a trend. */
    private static final int MIN_OCCURRENCES = 2;

    /** How much CO2 must climb above its nightly average to count as a build-up. */
    private static final double CO2_BUILDUP_PPM = 250;

    private static final int MAX_ITERATIONS = 50;

    public PatternAnalysisResult analyse(List<MorningReport> history, ThresholdConfig cfg) {
        List<MorningReport> nights = usableNights(history);

        if (nights.size() < MIN_NIGHTS) {
            // STC-04 TC-05: say so plainly instead of inventing a trend.
            return PatternAnalysisResult.builder()
                    .sufficientData(false)
                    .note("More data is needed for detailed pattern analysis. "
                            + "At least " + MIN_NIGHTS + " nights of history are required; "
                            + nights.size() + " available so far.")
                    .nightsAnalysed(nights.size())
                    .nights(describeNights(nights, new int[nights.size()]))
                    .clusters(List.of())
                    .patterns(List.of())
                    .suggestions(List.of())
                    .build();
        }

        double[][] features = toFeatureMatrix(nights);
        normalise(features);

        int k = nights.size() >= 4 ? 2 : 1;
        int[] assignment = kMeans(features, k);

        List<PatternAnalysisResult.Cluster> clusters = summariseClusters(nights, assignment, k);

        // Report on the cluster the most recent night belongs to — that is the
        // pattern the user is living with right now.
        int focusCluster = assignment[0];

        List<PatternAnalysisResult.DetectedPattern> patterns =
                detectPatterns(nights, assignment, focusCluster, cfg);
        List<PatternAnalysisResult.SmartSuggestion> suggestions = buildSuggestions(patterns);

        return PatternAnalysisResult.builder()
                .sufficientData(true)
                .nightsAnalysed(nights.size())
                .nights(describeNights(nights, assignment))
                .clusters(clusters)
                .patterns(patterns)
                .suggestions(suggestions)
                .build();
    }

    // ──────────────────────────────────────────────
    // Input preparation
    // ──────────────────────────────────────────────

    /**
     * Drop nights the generator could not summarise (cluster "UNKNOWN" means no
     * sensor data was recorded), newest first.
     */
    private List<MorningReport> usableNights(List<MorningReport> history) {
        List<MorningReport> nights = new ArrayList<>();
        if (history == null) return nights;

        for (MorningReport report : history) {
            if (report == null) continue;
            if ("UNKNOWN".equals(report.getEnvironmentCluster())) continue;
            nights.add(report);
        }
        nights.sort(Comparator.comparing(
                MorningReport::getGeneratedAt,
                Comparator.nullsLast(Comparator.reverseOrder())));
        return nights;
    }

    private double[][] toFeatureMatrix(List<MorningReport> nights) {
        double[][] features = new double[nights.size()][7];
        for (int i = 0; i < nights.size(); i++) {
            MorningReport n = nights.get(i);
            features[i] = new double[]{
                    n.getAvgCo2(),
                    n.getAvgTemperature(),
                    n.getAvgHumidity(),
                    n.getAvgPm25(),
                    n.getAvgLight(),
                    n.getAvgNoise(),
                    n.getMotionEventCount()
            };
        }
        return features;
    }

    /**
     * Min-max normalise each dimension in place so that CO2 (hundreds of ppm)
     * does not drown out temperature (tens of degrees) in the distance metric.
     */
    private void normalise(double[][] features) {
        if (features.length == 0) return;
        int dims = features[0].length;

        for (int d = 0; d < dims; d++) {
            double min = Double.MAX_VALUE;
            double max = -Double.MAX_VALUE;
            for (double[] row : features) {
                min = Math.min(min, row[d]);
                max = Math.max(max, row[d]);
            }
            double range = max - min;
            for (double[] row : features) {
                row[d] = range == 0 ? 0 : (row[d] - min) / range;
            }
        }
    }

    // ──────────────────────────────────────────────
    // Clustering
    // ──────────────────────────────────────────────

    /**
     * Lloyd's algorithm with deterministic seeding: the first two centroids are
     * the two nights furthest apart, which for a dataset built from two distinct
     * patterns puts one centroid in each from the start.
     */
    int[] kMeans(double[][] points, int k) {
        int n = points.length;
        int[] assignment = new int[n];
        if (k <= 1 || n <= k) {
            for (int i = 0; i < n; i++) assignment[i] = Math.min(i, k - 1);
            if (k <= 1) Arrays.fill(assignment, 0);
            return assignment;
        }

        double[][] centroids = seedCentroids(points, k);

        for (int iteration = 0; iteration < MAX_ITERATIONS; iteration++) {
            boolean changed = false;

            for (int i = 0; i < n; i++) {
                int nearest = 0;
                double best = Double.MAX_VALUE;
                for (int c = 0; c < k; c++) {
                    double distance = squaredDistance(points[i], centroids[c]);
                    if (distance < best) {
                        best = distance;
                        nearest = c;
                    }
                }
                if (assignment[i] != nearest) {
                    assignment[i] = nearest;
                    changed = true;
                }
            }

            centroids = recomputeCentroids(points, assignment, k, centroids);
            if (!changed) break;
        }

        return assignment;
    }

    private double[][] seedCentroids(double[][] points, int k) {
        double[][] centroids = new double[k][];

        // The two most distant points become the first two centroids.
        int a = 0;
        int b = 1;
        double furthest = -1;
        for (int i = 0; i < points.length; i++) {
            for (int j = i + 1; j < points.length; j++) {
                double distance = squaredDistance(points[i], points[j]);
                if (distance > furthest) {
                    furthest = distance;
                    a = i;
                    b = j;
                }
            }
        }
        centroids[0] = points[a].clone();
        if (k > 1) centroids[1] = points[b].clone();

        // Any further centroid is the point furthest from everything chosen so far.
        for (int c = 2; c < k; c++) {
            int pick = 0;
            double best = -1;
            for (int i = 0; i < points.length; i++) {
                double nearest = Double.MAX_VALUE;
                for (int done = 0; done < c; done++) {
                    nearest = Math.min(nearest, squaredDistance(points[i], centroids[done]));
                }
                if (nearest > best) {
                    best = nearest;
                    pick = i;
                }
            }
            centroids[c] = points[pick].clone();
        }

        return centroids;
    }

    private double[][] recomputeCentroids(double[][] points, int[] assignment,
                                          int k, double[][] previous) {
        int dims = points[0].length;
        double[][] sums = new double[k][dims];
        int[] counts = new int[k];

        for (int i = 0; i < points.length; i++) {
            int c = assignment[i];
            counts[c]++;
            for (int d = 0; d < dims; d++) sums[c][d] += points[i][d];
        }

        double[][] centroids = new double[k][dims];
        for (int c = 0; c < k; c++) {
            if (counts[c] == 0) {
                // Keep an emptied cluster where it was rather than collapsing it.
                centroids[c] = previous[c].clone();
                continue;
            }
            for (int d = 0; d < dims; d++) centroids[c][d] = sums[c][d] / counts[c];
        }
        return centroids;
    }

    private double squaredDistance(double[] a, double[] b) {
        double total = 0;
        for (int d = 0; d < a.length; d++) {
            double delta = a[d] - b[d];
            total += delta * delta;
        }
        return total;
    }

    // ──────────────────────────────────────────────
    // Pattern detection
    // ──────────────────────────────────────────────

    /**
     * A factor becomes a pattern only when it is out of range on most nights of
     * the cluster. Anything rarer is left out entirely, so the response never
     * claims a trend the data does not support (STC-04 TC-03).
     */
    private List<PatternAnalysisResult.DetectedPattern> detectPatterns(
            List<MorningReport> nights, int[] assignment, int cluster, ThresholdConfig cfg) {

        List<MorningReport> inCluster = new ArrayList<>();
        for (int i = 0; i < nights.size(); i++) {
            if (assignment[i] == cluster) inCluster.add(nights.get(i));
        }

        int total = inCluster.size();
        List<PatternAnalysisResult.DetectedPattern> patterns = new ArrayList<>();
        if (total == 0) return patterns;

        addPattern(patterns, cluster, total, "CO2_RECURRING_HIGH", ThresholdResult.CO2,
                count(inCluster, n -> n.getAvgCo2() > cfg.getCo2Warning()),
                "CO2 stayed above " + (int) cfg.getCo2Warning() + " ppm on average");

        addPattern(patterns, cluster, total, "CO2_OVERNIGHT_BUILDUP", ThresholdResult.CO2,
                count(inCluster, n -> n.getMaxCo2() - n.getAvgCo2() >= CO2_BUILDUP_PPM),
                "CO2 climbed more than " + (int) CO2_BUILDUP_PPM
                        + " ppm above its nightly average before morning");

        addPattern(patterns, cluster, total, "TEMPERATURE_RECURRING_HIGH",
                ThresholdResult.TEMPERATURE,
                count(inCluster, n -> n.getAvgTemperature() > cfg.getTemperatureMax()),
                "the room ran warmer than " + (int) cfg.getTemperatureMax() + "°C on average");

        addPattern(patterns, cluster, total, "TEMPERATURE_RECURRING_LOW",
                ThresholdResult.TEMPERATURE,
                count(inCluster, n -> n.getAvgTemperature() < cfg.getTemperatureMin()),
                "the room ran cooler than " + (int) cfg.getTemperatureMin() + "°C on average");

        addPattern(patterns, cluster, total, "HUMIDITY_RECURRING_HIGH",
                ThresholdResult.HUMIDITY,
                count(inCluster, n -> n.getAvgHumidity() > cfg.getHumidityMax()),
                "humidity stayed above " + (int) cfg.getHumidityMax() + "%");

        addPattern(patterns, cluster, total, "HUMIDITY_RECURRING_LOW",
                ThresholdResult.HUMIDITY,
                count(inCluster, n -> n.getAvgHumidity() < cfg.getHumidityMin()),
                "humidity stayed below " + (int) cfg.getHumidityMin() + "%");

        addPattern(patterns, cluster, total, "PM25_RECURRING_HIGH", ThresholdResult.PM25,
                count(inCluster, n -> n.getAvgPm25() > cfg.getPm25Warning()),
                "PM2.5 stayed above " + (int) cfg.getPm25Warning() + " µg/m³");

        addPattern(patterns, cluster, total, "LIGHT_RECURRING_HIGH", ThresholdResult.LIGHT,
                count(inCluster, n -> n.getAvgLight() > cfg.getLightMax()),
                "the room stayed brighter than " + (int) cfg.getLightMax() + " lux");

        addPattern(patterns, cluster, total, "NOISE_RECURRING_HIGH", ThresholdResult.NOISE,
                count(inCluster, n -> n.getAvgNoise() > cfg.getNoiseWarning()),
                "background noise stayed above " + (int) cfg.getNoiseWarning() + " dB");

        addPattern(patterns, cluster, total, "MOTION_RECURRING_HIGH", "MOTION",
                count(inCluster, n -> "HIGH".equals(n.getMotionPattern())),
                "you moved around a lot during the night");

        patterns.sort(Comparator.comparingDouble(
                PatternAnalysisResult.DetectedPattern::getConfidence).reversed());
        return patterns;
    }

    private void addPattern(List<PatternAnalysisResult.DetectedPattern> out,
                            int cluster, int total, String id, String factor,
                            int occurrences, String what) {
        if (occurrences < MIN_OCCURRENCES) return;
        double confidence = (double) occurrences / total;
        if (confidence < RECURRENCE_THRESHOLD) return;

        out.add(PatternAnalysisResult.DetectedPattern.builder()
                .id(id)
                .factor(factor)
                .description("On " + occurrences + " of " + total
                        + " similar nights, " + what + ".")
                .occurrences(occurrences)
                .nightsInCluster(total)
                .cluster(cluster)
                .confidence(confidence)
                .build());
    }

    private int count(List<MorningReport> nights, java.util.function.Predicate<MorningReport> test) {
        int matches = 0;
        for (MorningReport night : nights) {
            if (test.test(night)) matches++;
        }
        return matches;
    }

    // ──────────────────────────────────────────────
    // Suggestions
    // ──────────────────────────────────────────────

    /**
     * Every suggestion is derived from exactly one detected pattern and carries
     * that pattern's id plus the evidence behind it (STC-04 TC-04).
     */
    private List<PatternAnalysisResult.SmartSuggestion> buildSuggestions(
            List<PatternAnalysisResult.DetectedPattern> patterns) {

        List<PatternAnalysisResult.SmartSuggestion> suggestions = new ArrayList<>();

        for (PatternAnalysisResult.DetectedPattern pattern : patterns) {
            String title;
            String recommendation;

            switch (pattern.getId()) {
                case "CO2_RECURRING_HIGH" -> {
                    title = "Ventilate before bed";
                    recommendation = "Your bedroom air is consistently stale overnight. "
                            + "Air the room out for 10-15 minutes before you go to sleep, "
                            + "or leave a door or vent open while you sleep.";
                }
                case "CO2_OVERNIGHT_BUILDUP" -> {
                    title = "Keep air moving through the night";
                    recommendation = "CO2 builds up steadily after you fall asleep rather "
                            + "than starting high. Airing the room out beforehand will not be "
                            + "enough on its own — leave a gap for airflow overnight.";
                }
                case "TEMPERATURE_RECURRING_HIGH" -> {
                    title = "Cool the room down";
                    recommendation = "Set the air conditioning a couple of degrees lower, or "
                            + "run a fan, starting about 30 minutes before bedtime.";
                }
                case "TEMPERATURE_RECURRING_LOW" -> {
                    title = "Warm the room up";
                    recommendation = "Add a blanket or raise the thermostat slightly — the "
                            + "room is regularly colder than your comfort range.";
                }
                case "HUMIDITY_RECURRING_HIGH" -> {
                    title = "Reduce humidity";
                    recommendation = "Run a dehumidifier or the air conditioner's dry mode. "
                            + "Persistently damp air also encourages mould and dust mites.";
                }
                case "HUMIDITY_RECURRING_LOW" -> {
                    title = "Add some humidity";
                    recommendation = "Dry air night after night can leave your throat and "
                            + "sinuses irritated. A humidifier in the bedroom should help.";
                }
                case "PM25_RECURRING_HIGH" -> {
                    title = "Filter the air";
                    recommendation = "Run an air purifier in the bedroom and keep windows "
                            + "closed on high-dust days.";
                }
                case "LIGHT_RECURRING_HIGH" -> {
                    title = "Make the room darker";
                    recommendation = "Blackout curtains or covering standby LEDs will help; "
                            + "light at this level suppresses melatonin.";
                }
                case "NOISE_RECURRING_HIGH" -> {
                    title = "Cut the background noise";
                    recommendation = "Try earplugs or a white-noise source to mask the "
                            + "recurring background sound.";
                }
                case "MOTION_RECURRING_HIGH" -> {
                    title = "Look at sleep comfort";
                    recommendation = "Frequent movement often tracks with a room that is too "
                            + "warm or a mattress that no longer suits you. Try the temperature "
                            + "first, since it is the cheaper experiment.";
                }
                default -> {
                    continue;
                }
            }

            suggestions.add(PatternAnalysisResult.SmartSuggestion.builder()
                    .patternId(pattern.getId())
                    .factor(pattern.getFactor())
                    .title(title)
                    .recommendation(recommendation)
                    .evidence(pattern.getDescription())
                    .build());
        }

        return suggestions;
    }

    // ──────────────────────────────────────────────
    // Presentation helpers
    // ──────────────────────────────────────────────

    private List<PatternAnalysisResult.ClusteredNight> describeNights(
            List<MorningReport> nights, int[] assignment) {

        List<PatternAnalysisResult.ClusteredNight> described = new ArrayList<>();
        for (int i = 0; i < nights.size(); i++) {
            MorningReport n = nights.get(i);
            described.add(PatternAnalysisResult.ClusteredNight.builder()
                    .reportId(n.getId())
                    .date(n.getSleepStart() == null ? null
                            : n.getSleepStart().atZone(ZoneOffset.UTC).toLocalDate().toString())
                    .cluster(assignment[i])
                    .avgCo2(n.getAvgCo2())
                    .maxCo2(n.getMaxCo2())
                    .avgTemperature(n.getAvgTemperature())
                    .avgHumidity(n.getAvgHumidity())
                    .avgPm25(n.getAvgPm25())
                    .avgLight(n.getAvgLight())
                    .avgNoise(n.getAvgNoise())
                    .motionEventCount(n.getMotionEventCount())
                    .build());
        }
        return described;
    }

    private List<PatternAnalysisResult.Cluster> summariseClusters(
            List<MorningReport> nights, int[] assignment, int k) {

        List<PatternAnalysisResult.Cluster> clusters = new ArrayList<>();

        for (int c = 0; c < k; c++) {
            double co2 = 0, temp = 0, humidity = 0, pm25 = 0, light = 0, noise = 0, motion = 0;
            int count = 0;

            for (int i = 0; i < nights.size(); i++) {
                if (assignment[i] != c) continue;
                MorningReport n = nights.get(i);
                co2 += n.getAvgCo2();
                temp += n.getAvgTemperature();
                humidity += n.getAvgHumidity();
                pm25 += n.getAvgPm25();
                light += n.getAvgLight();
                noise += n.getAvgNoise();
                motion += n.getMotionEventCount();
                count++;
            }
            if (count == 0) continue;

            clusters.add(PatternAnalysisResult.Cluster.builder()
                    .index(c)
                    .nightCount(count)
                    .label(labelFor(temp / count, co2 / count, noise / count))
                    .avgCo2(round(co2 / count))
                    .avgTemperature(round(temp / count))
                    .avgHumidity(round(humidity / count))
                    .avgPm25(round(pm25 / count))
                    .avgLight(round(light / count))
                    .avgNoise(round(noise / count))
                    .avgMotionEvents(round(motion / count))
                    .build());
        }

        return clusters;
    }

    /**
     * A short descriptive name so the app can show "Warm, stuffy nights" instead
     * of "Cluster 0". Purely cosmetic — the grouping itself carries the meaning.
     */
    private String labelFor(double avgTemp, double avgCo2, double avgNoise) {
        List<String> traits = new ArrayList<>();
        if (avgTemp >= 28) traits.add("Warm");
        else if (avgTemp <= 20) traits.add("Cool");
        if (avgCo2 >= 1000) traits.add("stuffy");
        if (avgNoise >= 45) traits.add("noisy");

        if (traits.isEmpty()) return "Comfortable nights";
        return String.join(", ", traits) + " nights";
    }

    private double round(double value) {
        return Math.round(value * 10.0) / 10.0;
    }
}
