package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * One round of sensor readings as sent by the ESP32.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SensorData {
    private String id;
    private String deviceId;

    // Environmental sensors
    private double temperature;    // °C  (DHT22)
    private double humidity;       // %   (DHT22)
    private double co2;            // ppm (MH-Z19C)
    private double pm25;           // µg/m³ (PMS5003)
    private double lightIntensity; // lux (BH1750)
    private double noiseLevel;     // dB  (KY-037)

    // Motion
    private boolean motionDetected; // PIR sensor

    private Instant timestamp;
}
