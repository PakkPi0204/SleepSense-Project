package com.sleepsense.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * All threshold values, bound from application.properties.
 */
@Data
@Configuration
@ConfigurationProperties(prefix = "threshold")
public class ThresholdConfig {

    private double co2Warning   = 1000.0; // ppm
    private double co2Critical  = 2000.0;

    private double temperatureMin = 18.0; // °C — outside this band = WARNING
    private double temperatureMax = 26.0;
    private double temperatureCriticalMin = 15.0; // outside this band = CRITICAL
    private double temperatureCriticalMax = 32.0; // some nights run without AC; keeps alerts from firing constantly

    private double humidityMin = 30.0;    // % — outside this band = WARNING
    private double humidityMax = 60.0;
    private double humidityCriticalMin = 20.0; // outside this band = CRITICAL
    private double humidityCriticalMax = 70.0;

    private double pm25Warning  = 35.0;   // µg/m³
    private double pm25Critical = 75.0;

    private double lightMax = 50.0;       // lux (a bedroom should be dark) — WARNING
    private double lightCritical = 200.0; // lux — about as bright as the main light

    private double noiseWarning  = 40.0;  // dB
    private double noiseCritical = 60.0;
}
