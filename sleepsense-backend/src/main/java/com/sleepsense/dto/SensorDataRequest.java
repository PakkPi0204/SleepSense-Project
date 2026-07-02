package com.sleepsense.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

/**
 * DTO รับข้อมูล sensor จาก ESP32
 */
@Data
public class SensorDataRequest {

    @NotBlank(message = "deviceId is required")
    private String deviceId;

    @DecimalMin(value = "-10.0") @DecimalMax(value = "60.0")
    private double temperature;

    @DecimalMin(value = "0.0") @DecimalMax(value = "100.0")
    private double humidity;

    @DecimalMin(value = "300.0") @DecimalMax(value = "10000.0")
    private double co2;

    @DecimalMin(value = "0.0") @DecimalMax(value = "1000.0")
    private double pm25;

    @DecimalMin(value = "0.0") @DecimalMax(value = "100000.0")
    private double lightIntensity;

    @DecimalMin(value = "0.0") @DecimalMax(value = "130.0")
    private double noiseLevel;

    private boolean motionDetected;
}
