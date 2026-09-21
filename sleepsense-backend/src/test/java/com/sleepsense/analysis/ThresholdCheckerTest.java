package com.sleepsense.analysis;

import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.SensorData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test Plan Chapter 3.2 — UTC-02 checkThreshold
 *
 * <p>Component: com.sleepsense.analysis.ThresholdChecker#checkThreshold
 *
 * <p><b>Note on the threshold configuration.</b> UTC-02's prerequisite is
 * "Threshold configuration is loaded with predefined acceptable ranges", but the
 * Test Plan never states the numbers. The TD values only classify the way the
 * Test Plan says they do under a configuration more permissive than the bedroom
 * defaults SleepSense ships — TD-01 calls 320 lux and 45.2 dB "normal", while the
 * shipped defaults warn above 50 lux and 40 dB. Each case therefore runs against
 * {@link #testPlanConfig()}, reconstructed from the TD data, and the all-critical
 * case additionally against the shipped defaults. See the handover note about
 * revising TD-01/TD-03.
 */
class ThresholdCheckerTest {

    private final ThresholdChecker checker = new ThresholdChecker(new ThresholdConfig());

    /** The configuration the Test Plan's TD data implies. */
    private static ThresholdConfig testPlanConfig() {
        ThresholdConfig cfg = new ThresholdConfig();
        cfg.setCo2Warning(1000);
        cfg.setCo2Critical(2000);
        cfg.setTemperatureMin(18);
        cfg.setTemperatureMax(28);
        cfg.setTemperatureCriticalMin(15);
        cfg.setTemperatureCriticalMax(32);
        cfg.setHumidityMin(30);
        cfg.setHumidityMax(70);
        cfg.setHumidityCriticalMin(20);
        cfg.setHumidityCriticalMax(80);
        cfg.setPm25Warning(35);
        cfg.setPm25Critical(75);
        cfg.setLightMax(400);
        cfg.setLightCritical(800);
        cfg.setNoiseWarning(50);
        cfg.setNoiseCritical(85);
        return cfg;
    }

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
    /** TD-01: all within normal range. */
    private static final SensorData TD_01 = reading(850, 27.5, 65.0, 12.3, 320, 45.2);

    /** TD-02: all exceed the critical threshold. */
    private static final SensorData TD_02 = reading(2100, 36.0, 85.0, 75.0, 950, 90.0);

    /** TD-03: CO2 in the warning range only. */
    private static final SensorData TD_03 = reading(1600, 27.5, 65.0, 12.3, 320, 45.2);

    @Nested
    @DisplayName("UTC-02.01 Test-checkThreshold.allNormal")
    class AllNormal {

        @Test
        @DisplayName("every factor is normal when all values are within range")
        void everyFactorNormal() {
            ThresholdResult result = checker.checkThreshold(TD_01, testPlanConfig());

            for (String factor : ThresholdResult.ALL_FACTORS) {
                assertThat(result.statusOf(factor))
                        .as("%s should be normal", factor)
                        .isEqualTo(ThresholdResult.STATUS_NORMAL);
            }

            assertThat(result.isCritical()).isFalse();
            assertThat(result.hasWarning()).isFalse();
            assertThat(result.getAlertFactors()).isEmpty();
        }
    }

    @Nested
    @DisplayName("UTC-02.02 Test-checkThreshold.allCritical")
    class AllCritical {

        @Test
        @DisplayName("every factor is critical when all values exceed critical limits")
        void everyFactorCritical() {
            ThresholdResult result = checker.checkThreshold(TD_02, testPlanConfig());

            for (String factor : ThresholdResult.ALL_FACTORS) {
                assertThat(result.statusOf(factor))
                        .as("%s should be critical", factor)
                        .isEqualTo(ThresholdResult.STATUS_CRITICAL);
            }

            assertThat(result.isCritical()).isTrue();
            assertThat(result.getAlertFactors()).hasSize(6);
            assertThat(result.getCriticalFactors()).hasSize(6);
        }

        @Test
        @DisplayName("TD-02 is critical on every factor under the shipped defaults too")
        void criticalUnderShippedDefaults() {
            ThresholdResult result = checker.checkThreshold(TD_02);

            for (String factor : ThresholdResult.ALL_FACTORS) {
                assertThat(result.statusOf(factor))
                        .as("%s should be critical", factor)
                        .isEqualTo(ThresholdResult.STATUS_CRITICAL);
            }
            assertThat(result.getAlertFactors()).hasSize(6);
        }
    }

    @Nested
    @DisplayName("UTC-02.03 Test-checkThreshold.partialWarning")
    class PartialWarning {

        @Test
        @DisplayName("only co2 is warning when only its value is in the warning range")
        void onlyCo2Warns() {
            ThresholdConfig cfg = testPlanConfig();
            ThresholdResult result = checker.checkThreshold(TD_03, cfg);

            assertThat(result.statusOf(ThresholdResult.CO2))
                    .isEqualTo(ThresholdResult.STATUS_WARNING);
            assertThat(result.get(ThresholdResult.CO2).getThreshold())
                    .isEqualTo(cfg.getCo2Warning());

            for (String factor : ThresholdResult.ALL_FACTORS) {
                if (factor.equals(ThresholdResult.CO2)) continue;
                assertThat(result.statusOf(factor))
                        .as("%s should be normal", factor)
                        .isEqualTo(ThresholdResult.STATUS_NORMAL);
            }

            assertThat(result.isCritical()).isFalse();
            assertThat(result.getAlertFactors()).hasSize(1);
            assertThat(result.getAlertFactors().get(0).getFactor())
                    .isEqualTo(ThresholdResult.CO2);
        }
    }

    @Nested
    @DisplayName("boundary and missing-sensor behaviour")
    class Edges {

        @Test
        void valueExactlyOnWarningThresholdIsWarning() {
            SensorData d = reading(1000, 22, 50, 10, 8, 30);
            assertThat(checker.checkThreshold(d).statusOf(ThresholdResult.CO2))
                    .isEqualTo(ThresholdResult.STATUS_WARNING);
        }

        @Test
        void valueExactlyOnCriticalThresholdIsCritical() {
            SensorData d = reading(2000, 22, 50, 10, 8, 30);
            assertThat(checker.checkThreshold(d).statusOf(ThresholdResult.CO2))
                    .isEqualTo(ThresholdResult.STATUS_CRITICAL);
        }

        @Test
        void temperatureBelowCriticalMinimumIsCritical() {
            SensorData d = reading(500, 12, 50, 10, 8, 30);
            ThresholdResult result = checker.checkThreshold(d);

            assertThat(result.statusOf(ThresholdResult.TEMPERATURE))
                    .isEqualTo(ThresholdResult.STATUS_CRITICAL);
            assertThat(result.get(ThresholdResult.TEMPERATURE).getThreshold())
                    .isEqualTo(new ThresholdConfig().getTemperatureCriticalMin());
        }

        @Test
        void humidityBelowComfortMinimumIsWarningNotCritical() {
            SensorData d = reading(500, 22, 25, 10, 8, 30);
            ThresholdResult result = checker.checkThreshold(d);

            assertThat(result.statusOf(ThresholdResult.HUMIDITY))
                    .isEqualTo(ThresholdResult.STATUS_WARNING);
            assertThat(result.isCritical()).isFalse();
        }

        @Test
        @DisplayName("a disconnected sensor is reported normal, not as an alert")
        void disconnectedSensorIsNormal() {
            // Backend convention: CO2 at or below zero, temperature and humidity
            // below zero, mean "no sensor attached".
            SensorData d = reading(0, -1, -1, 0, 0, 0);
            ThresholdResult result = checker.checkThreshold(d);

            assertThat(result.statusOf(ThresholdResult.CO2))
                    .isEqualTo(ThresholdResult.STATUS_NORMAL);
            assertThat(result.statusOf(ThresholdResult.TEMPERATURE))
                    .isEqualTo(ThresholdResult.STATUS_NORMAL);
            assertThat(result.statusOf(ThresholdResult.HUMIDITY))
                    .isEqualTo(ThresholdResult.STATUS_NORMAL);
            assertThat(result.getAlertFactors()).isEmpty();
        }

        @Test
        void customThresholdsOverrideTheDefaults() {
            ThresholdConfig strict = new ThresholdConfig();
            strict.setCo2Warning(600);
            strict.setCo2Critical(900);

            SensorData d = reading(850, 22, 50, 10, 8, 30);
            assertThat(checker.checkThreshold(d, strict).statusOf(ThresholdResult.CO2))
                    .isEqualTo(ThresholdResult.STATUS_WARNING);
        }
    }
}
