package com.sleepsense.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * ค่า threshold ทั้งหมด — ดึงจาก application.properties
 */
@Data
@Configuration
@ConfigurationProperties(prefix = "threshold")
public class ThresholdConfig {

    private double co2Warning   = 1000.0; // ppm
    private double co2Critical  = 2000.0;

    private double temperatureMin = 18.0; // °C
    private double temperatureMax = 26.0;

    private double humidityMin = 40.0;    // %
    private double humidityMax = 60.0;

    private double pm25Warning  = 35.0;   // µg/m³
    private double pm25Critical = 75.0;

    private double lightMax = 50.0;       // lux (ห้องนอนควรมืด)

    private double noiseWarning  = 40.0;  // dB
    private double noiseCritical = 60.0;
}
