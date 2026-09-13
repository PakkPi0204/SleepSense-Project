package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Alert {
    private String id;
    private String deviceId;
    private AlertLevel level;
    private String factor;     // "CO2", "TEMPERATURE", "PM25", "NOISE", "LIGHT", "HUMIDITY"
    private String message;
    private double value;
    private double threshold;
    private Instant timestamp;

    // true เมื่อปัญหานี้กลับสู่ภาวะปกติแล้ว (ค่ากลับมาอยู่ในช่วงที่ยอมรับได้
    // ภายใต้ threshold ปัจจุบัน) — ตั้งโดย SensorService ตอนพบว่ารอบวิเคราะห์
    // ล่าสุด factor นี้ไม่ติดเงื่อนไข WARNING/CRITICAL อีกต่อไป เดิม Alert ไม่มี
    // สถานะนี้เลย ทำให้ทุกแถวถูกมองว่า "active" ตลอดไป แม้ปัญหาจะหายไปแล้วหรือ
    // ผู้ใช้ปรับ threshold ใหม่จนค่าเดิมไม่วิกฤตแล้วก็ตาม
    @Builder.Default
    private boolean resolved = false;
    private Instant resolvedAt; // null ถ้ายัง active อยู่

    public enum AlertLevel {
        WARNING, CRITICAL
    }
}
