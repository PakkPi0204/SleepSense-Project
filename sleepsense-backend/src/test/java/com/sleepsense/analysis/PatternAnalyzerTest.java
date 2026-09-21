package com.sleepsense.analysis;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.MorningReport;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test Plan Chapter 5.4 — STC-04 Receive Smart Suggestions
 *
 * <p>STC-04 is written as a system test, but its substance — that clustering
 * groups similar nights, that a detected pattern matches the known
 * characteristics of the input, and that a suggestion is derived from that
 * pattern — is analysis logic. Covering it here means it can be verified against
 * a controlled dataset rather than by waiting several real nights.
 *
 * <p>Component: com.sleepsense.analysis.PatternAnalyzer#analyse
 */
class PatternAnalyzerTest {

    private final PatternAnalyzer analyzer = new PatternAnalyzer();
    private final ThresholdConfig cfg = new ThresholdConfig();

    /**
     * Pattern A: warm, stuffy nights with CO2 building up before morning.
     * Every value is over the default warning band for CO2, temperature and
     * humidity.
     */
    private static MorningReport patternA(int daysAgo) {
        return night(daysAgo, 1400, 1800, 29.0, 72.0, 10.0, 5.0, 30.0, 3);
    }

    /** Pattern B: cool, well-ventilated nights, comfortably within range. */
    private static MorningReport patternB(int daysAgo) {
        return night(daysAgo, 600, 700, 22.0, 50.0, 8.0, 4.0, 28.0, 2);
    }

    private static MorningReport night(int daysAgo, double avgCo2, double maxCo2,
                                       double temp, double humidity, double pm25,
                                       double light, double noise, int motion) {
        Instant when = Instant.now().minus(daysAgo, ChronoUnit.DAYS);
        return MorningReport.builder()
                .id("report-" + daysAgo)
                .deviceId("test-device-01")
                .sleepStart(when)
                .sleepEnd(when.plus(8, ChronoUnit.HOURS))
                .generatedAt(when.plus(8, ChronoUnit.HOURS))
                .avgCo2(avgCo2)
                .maxCo2(maxCo2)
                .avgTemperature(temp)
                .maxTemperature(temp + 1)
                .avgHumidity(humidity)
                .avgPm25(pm25)
                .maxPm25(pm25)
                .avgLight(light)
                .avgNoise(noise)
                .maxNoise(noise)
                .motionEventCount(motion)
                .motionPattern(motion < 5 ? "LOW" : motion < 15 ? "MODERATE" : "HIGH")
                .environmentCluster("MODERATE")
                .dataCompleteness(100)
                .anomalies(List.of())
                .suggestions(List.of())
                .build();
    }

    /** Six nights: the three most recent share Pattern A, the older three Pattern B. */
    private static List<MorningReport> controlledDataset() {
        List<MorningReport> nights = new ArrayList<>();
        for (int i = 1; i <= 3; i++) nights.add(patternA(i));
        for (int i = 4; i <= 6; i++) nights.add(patternB(i));
        return nights;
    }

    @Test
    @DisplayName("STC-04 TC-01: a recurring pattern across several nights yields a suggestion")
    void detectsRecurringPatternAndSuggests() {
        PatternAnalysisResult result = analyzer.analyse(controlledDataset(), cfg);

        assertThat(result.isSufficientData()).isTrue();
        assertThat(result.getNightsAnalysed()).isEqualTo(6);
        assertThat(result.getSuggestions()).isNotEmpty();

        // The advice must rest on more than a single night.
        assertThat(result.getPatterns())
                .allSatisfy(p -> assertThat(p.getOccurrences()).isGreaterThan(1));
    }

    @Test
    @DisplayName("STC-04 TC-02: clustering groups similar nights and separates distinct ones")
    void clusteringSeparatesTheTwoPatterns() {
        PatternAnalysisResult result = analyzer.analyse(controlledDataset(), cfg);

        List<PatternAnalysisResult.ClusteredNight> nights = result.getNights();
        assertThat(nights).hasSize(6);

        // Nights come back newest first, so 0-2 are Pattern A and 3-5 Pattern B.
        Set<Integer> patternAClusters = nights.subList(0, 3).stream()
                .map(PatternAnalysisResult.ClusteredNight::getCluster)
                .collect(Collectors.toSet());
        Set<Integer> patternBClusters = nights.subList(3, 6).stream()
                .map(PatternAnalysisResult.ClusteredNight::getCluster)
                .collect(Collectors.toSet());

        // Each pattern lands wholly in one cluster...
        assertThat(patternAClusters).hasSize(1);
        assertThat(patternBClusters).hasSize(1);
        // ...and the two clusters are different. Cluster labels are arbitrary;
        // only the grouping is asserted on.
        assertThat(patternAClusters).isNotEqualTo(patternBClusters);

        assertThat(result.getClusters()).hasSize(2);
        assertThat(result.getClusters())
                .allSatisfy(c -> assertThat(c.getNightCount()).isEqualTo(3));
    }

    @Test
    @DisplayName("STC-04 TC-03: the detected pattern matches the known input, and nothing else")
    void detectedPatternMatchesTheInput() {
        PatternAnalysisResult result = analyzer.analyse(controlledDataset(), cfg);

        List<String> patternIds = result.getPatterns().stream()
                .map(PatternAnalysisResult.DetectedPattern::getId)
                .toList();

        // Pattern A really is warm, stuffy, humid, with CO2 climbing overnight.
        assertThat(patternIds).contains(
                "CO2_RECURRING_HIGH",
                "CO2_OVERNIGHT_BUILDUP",
                "TEMPERATURE_RECURRING_HIGH",
                "HUMIDITY_RECURRING_HIGH");

        // ...and is not dusty, bright, noisy or restless, so none of those may be
        // reported.
        assertThat(patternIds).doesNotContain(
                "PM25_RECURRING_HIGH",
                "LIGHT_RECURRING_HIGH",
                "NOISE_RECURRING_HIGH",
                "MOTION_RECURRING_HIGH",
                "TEMPERATURE_RECURRING_LOW",
                "HUMIDITY_RECURRING_LOW");

        // Every pattern is reported against the cluster it was found in, with a
        // confidence that reflects how often it recurred.
        assertThat(result.getPatterns()).allSatisfy(p -> {
            assertThat(p.getConfidence()).isBetween(0.6, 1.0);
            assertThat(p.getNightsInCluster()).isEqualTo(3);
            assertThat(p.getDescription()).contains("of 3 similar nights");
        });
    }

    @Test
    @DisplayName("STC-04 TC-04: every suggestion is derived from a detected pattern")
    void suggestionsAreTraceableToPatterns() {
        PatternAnalysisResult result = analyzer.analyse(controlledDataset(), cfg);

        Set<String> patternIds = result.getPatterns().stream()
                .map(PatternAnalysisResult.DetectedPattern::getId)
                .collect(Collectors.toSet());

        assertThat(result.getSuggestions()).isNotEmpty();
        assertThat(result.getSuggestions()).allSatisfy(s -> {
            // Tied to real evidence, not floating free.
            assertThat(patternIds).contains(s.getPatternId());
            assertThat(s.getEvidence()).isNotBlank();
            assertThat(s.getRecommendation()).isNotBlank();
        });

        // The stuffy-room pattern produces ventilation advice.
        assertThat(result.getSuggestions())
                .extracting(PatternAnalysisResult.SmartSuggestion::getPatternId)
                .contains("CO2_RECURRING_HIGH");
    }

    @Test
    @DisplayName("STC-04 TC-05: fewer than 3 nights reports insufficient data")
    void insufficientHistoryIsReportedPlainly() {
        List<MorningReport> twoNights = List.of(patternA(1), patternA(2));

        PatternAnalysisResult result = analyzer.analyse(twoNights, cfg);

        assertThat(result.isSufficientData()).isFalse();
        assertThat(result.getNote())
                .contains("More data is needed for detailed pattern analysis");
        assertThat(result.getPatterns()).isEmpty();
        assertThat(result.getSuggestions()).isEmpty();
    }

    @Test
    @DisplayName("nights with no sensor data are excluded from the analysis")
    void unknownNightsAreIgnored() {
        List<MorningReport> nights = new ArrayList<>(controlledDataset());
        MorningReport empty = night(7, 0, 0, 0, 0, 0, 0, 0, 0);
        empty.setEnvironmentCluster("UNKNOWN");
        nights.add(empty);

        PatternAnalysisResult result = analyzer.analyse(nights, cfg);

        assertThat(result.getNightsAnalysed()).isEqualTo(6);
    }

    @Test
    @DisplayName("an empty history is handled without throwing")
    void emptyHistory() {
        PatternAnalysisResult result = analyzer.analyse(List.of(), cfg);

        assertThat(result.isSufficientData()).isFalse();
        assertThat(result.getNightsAnalysed()).isZero();
    }

    @Test
    @DisplayName("a null history is handled without throwing")
    void nullHistory() {
        PatternAnalysisResult result = analyzer.analyse(null, cfg);

        assertThat(result.isSufficientData()).isFalse();
        assertThat(result.getNightsAnalysed()).isZero();
    }
}
