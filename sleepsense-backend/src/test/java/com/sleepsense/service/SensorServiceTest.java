package com.sleepsense.service;

import com.sleepsense.analysis.ThresholdAnalyzer;
import com.sleepsense.model.SensorData;
import com.sleepsense.repository.AlertRepository;
import com.sleepsense.repository.SensorDataRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

/**
 * Test Plan Chapter 3.1 — UTC-01 getSensorData (server side)
 *
 * <p>Component: com.sleepsense.service.SensorService#getSensorData
 *
 * <p>The Test Plan mocks an HTTP GET of /api/sensor/latest. On the server the
 * equivalent seam is the repository, mocked here with Mockito; the Flutter suite
 * in {@code test/unit/sensor_service_test.dart} covers the HTTP side.
 */
@ExtendWith(MockitoExtension.class)
class SensorServiceTest {

    private static final String DEVICE_ID = "test-device-01";

    @Mock
    private SensorDataRepository sensorRepo;
    @Mock
    private AlertRepository alertRepo;
    @Mock
    private ThresholdAnalyzer analyzer;
    @Mock
    private ThresholdSettingsService thresholdSettingsService;

    @InjectMocks
    private SensorService sensorService;

    /** TD-01: a populated reading. */
    private static SensorData td01() {
        return SensorData.builder()
                .id("reading-1")
                .deviceId(DEVICE_ID)
                .co2(850)
                .temperature(27.5)
                .humidity(65.0)
                .pm25(12.3)
                .lightIntensity(320)
                .noiseLevel(45.2)
                .timestamp(Instant.now())
                .build();
    }

    @Nested
    @DisplayName("UTC-01.01 Test-getSensorData.latestReading")
    class LatestReading {

        @Test
        @DisplayName("returns the latest sensor reading correctly")
        void returnsLatestReading() throws Exception {
            when(sensorRepo.findLatest(DEVICE_ID)).thenReturn(Optional.of(td01()));

            SensorData reading = sensorService.getSensorData(DEVICE_ID);

            assertThat(reading.getCo2()).isEqualTo(850);
            assertThat(reading.getTemperature()).isEqualTo(27.5);
            assertThat(reading.getHumidity()).isEqualTo(65.0);
            assertThat(reading.getPm25()).isEqualTo(12.3);
            assertThat(reading.getLightIntensity()).isEqualTo(320);
            assertThat(reading.getNoiseLevel()).isEqualTo(45.2);
        }
    }

    @Nested
    @DisplayName("UTC-01.02 Test-getSensorData.emptyResponse")
    class EmptyResponse {

        @Test
        @DisplayName("returns an empty reading when no data is available, without throwing")
        void handlesNoData() throws Exception {
            when(sensorRepo.findLatest(DEVICE_ID)).thenReturn(Optional.empty());

            assertThatCode(() -> sensorService.getSensorData(DEVICE_ID))
                    .doesNotThrowAnyException();

            SensorData reading = sensorService.getSensorData(DEVICE_ID);

            assertThat(reading).isNotNull();
            assertThat(reading.getDeviceId()).isEqualTo(DEVICE_ID);
            assertThat(reading.getCo2()).isZero();
            assertThat(reading.getTemperature()).isZero();
            assertThat(reading.getHumidity()).isZero();
        }

        @Test
        @DisplayName("getLatest reports the absence as an empty Optional")
        void getLatestIsEmpty() throws Exception {
            when(sensorRepo.findLatest(DEVICE_ID)).thenReturn(Optional.empty());

            assertThat(sensorService.getLatest(DEVICE_ID)).isEmpty();
        }
    }

    @Nested
    @DisplayName("UTC-01.03 Test-getSensorData.networkError")
    class DatastoreError {

        @Test
        @DisplayName("throws an error with a non-null message when the datastore fails")
        void throwsOnFailure() throws Exception {
            when(sensorRepo.findLatest(anyString()))
                    .thenThrow(new RuntimeException("Connection refused"));

            assertThatThrownBy(() -> sensorService.getSensorData(DEVICE_ID))
                    .isInstanceOf(RuntimeException.class)
                    .hasMessageContaining("Database error");
        }
    }
}
