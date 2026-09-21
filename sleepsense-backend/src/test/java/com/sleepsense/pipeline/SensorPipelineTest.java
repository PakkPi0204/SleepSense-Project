package com.sleepsense.pipeline;

import com.sleepsense.alert.AlertDispatcher;
import com.sleepsense.alert.AlertNotification;
import com.sleepsense.alert.FcmAlertDispatcher;
import com.sleepsense.analysis.ThresholdChecker;
import com.sleepsense.analysis.ThresholdResult;
import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.SensorData;
import com.sleepsense.service.SensorService;
import com.sleepsense.service.ThresholdSettingsService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Test Plan Chapter 4 — ITC-01 Test-SensorPipeline
 *
 * <p>Component: getSensorData() -&gt; checkThreshold() -&gt; sendAlert()
 *
 * <p>{@link SensorService} and {@link AlertDispatcher} are mocked, standing in
 * for the HTTP GET of /api/sensor/latest and for FCM delivery respectively. The
 * real {@link ThresholdChecker} runs in between, so the test exercises the actual
 * classification rather than a stub of it.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SensorPipelineTest {

    private static final String DEVICE_ID = "test-device-01";

    @Mock
    private SensorService sensorService;
    @Mock
    private AlertDispatcher alertDispatcher;
    @Mock
    private ThresholdSettingsService thresholdSettingsService;

    private SensorPipeline pipeline;

    @BeforeEach
    void setUp() {
        ThresholdConfig defaults = new ThresholdConfig();
        ThresholdChecker checker = new ThresholdChecker(defaults);
        when(thresholdSettingsService.getEffective(anyString())).thenReturn(defaults);

        pipeline = new SensorPipeline(
                sensorService, checker, alertDispatcher, thresholdSettingsService);
    }

    private static SensorData reading(double co2, double temp, double humidity,
                                      double pm25, double light, double noise) {
        return SensorData.builder()
                .deviceId(DEVICE_ID)
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
    private static final SensorData TD_01 = reading(850, 22.0, 50.0, 12.3, 12, 32.0);
    private static final SensorData TD_02 = reading(2100, 36.0, 85.0, 75.0, 950, 90.0);

    @Test
    @DisplayName("ITC-01 TC-01: normal data flows through without triggering an alert")
    void normalDataDoesNotAlert() {
        when(sensorService.getSensorData(DEVICE_ID)).thenReturn(TD_01);

        SensorPipeline.Outcome outcome = pipeline.run(DEVICE_ID);

        for (String factor : ThresholdResult.ALL_FACTORS) {
            assertThat(outcome.getResult().statusOf(factor))
                    .as("%s should be normal", factor)
                    .isEqualTo(ThresholdResult.STATUS_NORMAL);
        }
        assertThat(outcome.getResult().isCritical()).isFalse();

        // sendAlert is NOT called.
        verify(alertDispatcher, never()).sendAlert(anyString(), any(), any());
        assertThat(outcome.isAlertSent()).isFalse();
        assertThat(outcome.getNotifications()).isEmpty();
    }

    @Test
    @DisplayName("ITC-01 TC-02: critical data flows through and triggers an alert")
    void criticalDataAlertsOnce() {
        when(sensorService.getSensorData(DEVICE_ID)).thenReturn(TD_02);
        when(alertDispatcher.sendAlert(eq(DEVICE_ID), any(), any()))
                .thenReturn(List.of(AlertNotification.builder()
                        .deviceId(DEVICE_ID)
                        .factor(ThresholdResult.CO2)
                        .message("Warning: CO2 level is 2100 ppm.")
                        .build()));

        SensorPipeline.Outcome outcome = pipeline.run(DEVICE_ID);

        assertThat(outcome.getResult().isCritical()).isTrue();

        // sendAlert IS called — the FCM mock is invoked exactly once.
        verify(alertDispatcher, times(1)).sendAlert(eq(DEVICE_ID), any(), any());
        assertThat(outcome.isAlertSent()).isTrue();
    }

    @Test
    @DisplayName("STC-05 TC-03: one notification per critical factor, naming factor and value")
    void oneNotificationPerCriticalFactor() {
        // Only CO2 and noise are critical here.
        SensorData mixed = reading(2150, 22.0, 50.0, 10.0, 8, 88.0);
        when(sensorService.getSensorData(DEVICE_ID)).thenReturn(mixed);

        // Use the real dispatcher to check the messages it builds.
        FcmAlertDispatcher real = new FcmAlertDispatcher();
        when(alertDispatcher.sendAlert(eq(DEVICE_ID), any(), any()))
                .thenAnswer(invocation -> real.sendAlert(
                        invocation.getArgument(0),
                        invocation.getArgument(1),
                        invocation.getArgument(2)));

        SensorPipeline.Outcome outcome = pipeline.run(DEVICE_ID);

        // sendAlert is still invoked once for the run...
        verify(alertDispatcher, times(1)).sendAlert(eq(DEVICE_ID), any(), any());
        // ...but it emits a separate notification per affected factor.
        assertThat(outcome.getNotifications()).hasSize(2);
        assertThat(outcome.getNotifications())
                .extracting(AlertNotification::getFactor)
                .containsExactlyInAnyOrder(ThresholdResult.CO2, ThresholdResult.NOISE);

        String co2Message = outcome.getNotifications().stream()
                .filter(n -> ThresholdResult.CO2.equals(n.getFactor()))
                .findFirst().orElseThrow()
                .getMessage();
        assertThat(co2Message).contains("CO2").contains("2150");
    }
}
