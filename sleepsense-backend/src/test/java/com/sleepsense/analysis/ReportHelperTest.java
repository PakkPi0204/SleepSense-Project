package com.sleepsense.analysis;

import com.sleepsense.model.SensorData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

/**
 * Test Plan Chapter 3.3 — UTC-03 calculateDailyAverage
 *
 * <p>Component: com.sleepsense.analysis.ReportHelper#calculateDailyAverage
 */
class ReportHelperTest {

    private static final double TOLERANCE = 0.001;

    private final ReportHelper helper = new ReportHelper();

    private static SensorData reading(double co2, double temp, double humidity,
                                      double pm25, double light, double noise) {
        return SensorData.builder()
                .deviceId("test-device-01")
                .co2(co2)
                .temperature(temp)
                .humidity(humidity)
                .pm25(pm25)
                .lightIntensity(light)
                .noiseLevel(noise)
                .timestamp(Instant.now())
                .build();
    }

    // ── Environment Test Data ──────────────────────────────────────────────
    /** TD-01: three readings. */
    private static final List<SensorData> TD_01 = List.of(
            reading(800, 26.0, 60.0, 10.0, 300, 40.0),
            reading(900, 28.0, 70.0, 14.0, 340, 50.0),
            reading(1000, 30.0, 80.0, 18.0, 380, 60.0));

    /** TD-02: empty list — no readings. */
    private static final List<SensorData> TD_02 = List.of();

    @Nested
    @DisplayName("UTC-03.01 Test-calculateDailyAverage.normalData")
    class NormalData {

        @Test
        @DisplayName("returns the correct avg/min/max from 3 readings")
        void correctAggregates() {
            DailyReport report = helper.calculateDailyAverage(TD_01);

            assertThat(report).isNotNull();

            assertSummary(report.getCo2(), 900, 800, 1000);
            assertSummary(report.getTemperature(), 28.0, 26.0, 30.0);
            assertSummary(report.getHumidity(), 70.0, 60.0, 80.0);
            assertSummary(report.getPm25(), 14.0, 10.0, 18.0);
            assertSummary(report.getLight(), 340, 300, 380);
            assertSummary(report.getNoise(), 50.0, 40.0, 60.0);

            assertThat(report.getSampleCount()).isEqualTo(3);
        }

        @Test
        void singleReadingAveragesToItself() {
            DailyReport report = helper.calculateDailyAverage(
                    List.of(reading(742, 22, 50, 10, 8, 30)));

            assertSummary(report.getCo2(), 742, 742, 742);
        }

        @Test
        void motionEventsAreCountedAndClassified() {
            SensorData moved = reading(500, 22, 50, 10, 8, 30);
            moved.setMotionDetected(true);
            SensorData still = reading(500, 22, 50, 10, 8, 30);

            DailyReport report =
                    helper.calculateDailyAverage(List.of(moved, moved, still));

            assertThat(report.getMotionEventCount()).isEqualTo(2);
            assertThat(report.getMotionPattern()).isEqualTo("LOW");
        }
    }

    @Nested
    @DisplayName("UTC-03.02 Test-calculateDailyAverage.emptyArray")
    class EmptyArray {

        @Test
        @DisplayName("handles empty input gracefully and throws nothing")
        void emptyReturnsNull() {
            assertThatCode(() -> helper.calculateDailyAverage(TD_02))
                    .doesNotThrowAnyException();

            assertThat(helper.calculateDailyAverage(TD_02)).isNull();
        }

        @Test
        @DisplayName("a null list is treated the same as an empty one")
        void nullReturnsNull() {
            assertThatCode(() -> helper.calculateDailyAverage(null))
                    .doesNotThrowAnyException();

            assertThat(helper.calculateDailyAverage(null)).isNull();
        }
    }

    private static void assertSummary(DailyReport.FactorSummary summary,
                                      double avg, double min, double max) {
        assertThat(summary.getAvg()).isCloseTo(avg, org.assertj.core.data.Offset.offset(TOLERANCE));
        assertThat(summary.getMin()).isCloseTo(min, org.assertj.core.data.Offset.offset(TOLERANCE));
        assertThat(summary.getMax()).isCloseTo(max, org.assertj.core.data.Offset.offset(TOLERANCE));
    }
}
