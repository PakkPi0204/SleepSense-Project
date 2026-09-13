package com.sleepsense.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * ค่า threshold ที่ผู้ใช้ปรับเองสำหรับ device หนึ่งตัว (เก็บใน Firestore)
 * เช่น บางคนต้องนอนห้องเย็นกว่าปกติ หรือไวต่อฝุ่น/เสียงมากกว่าค่าเฉลี่ยทั่วไป
 *
 * ถ้า device ไหนไม่เคยบันทึกไว้ (ไม่มี document นี้) ระบบจะใช้ค่า default
 * จาก ThresholdConfig (application.properties) แทนโดยอัตโนมัติ
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ThresholdSettings {
    private String deviceId;

    private Double co2Warning;
    private Double co2Critical;

    private Double temperatureMin;
    private Double temperatureMax;
    private Double temperatureCriticalMin;
    private Double temperatureCriticalMax;

    private Double humidityMin;
    private Double humidityMax;
    private Double humidityCriticalMin;
    private Double humidityCriticalMax;

    private Double pm25Warning;
    private Double pm25Critical;

    private Double lightMax;
    private Double lightCritical;

    private Double noiseWarning;
    private Double noiseCritical;

    private Instant updatedAt;

    /** true ถ้าผู้ใช้เคยบันทึกค่าที่ปรับเองไว้จริง (ไม่ใช่ default ที่ประกอบขึ้นมาโชว์เฉยๆ) */
    private boolean customized;
}
