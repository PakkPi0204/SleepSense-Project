package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * ข้อมูลจาก sensor ทั้งหมดที่ ESP32 ส่งมาในแต่ละรอบ
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
