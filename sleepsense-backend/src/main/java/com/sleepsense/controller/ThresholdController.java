package com.sleepsense.controller;

import com.sleepsense.dto.ApiResponse;
import com.sleepsense.model.ThresholdSettings;
import com.sleepsense.service.ThresholdSettingsService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/thresholds")
@RequiredArgsConstructor
public class ThresholdController {

    private final ThresholdSettingsService thresholdSettingsService;

    /**
     * GET /api/thresholds?deviceId=xxx
     * คืนค่า threshold ที่ใช้งานจริงของ device นี้ (custom ถ้ามี ไม่งั้นเป็น default)
     * พร้อม flag "customized" บอกว่าเป็นค่าที่ผู้ใช้ปรับเองหรือเป็นค่าตั้งต้นของระบบ
     */
    @GetMapping
    public ResponseEntity<ApiResponse<ThresholdSettings>> get(@RequestParam String deviceId) {
        ThresholdSettings settings = thresholdSettingsService.getSettingsOrDefault(deviceId);
        return ResponseEntity.ok(ApiResponse.ok(settings));
    }

    /**
     * PUT /api/thresholds?deviceId=xxx
     * บันทึกค่า threshold ที่ผู้ใช้ปรับเอง — ส่งได้ทั้งชุด หรือเฉพาะฟิลด์ที่อยากเปลี่ยน
     * (ฟิลด์ที่เป็น null จะถูกเติมด้วยค่า default ของระบบตอนนำไปใช้งานจริง)
     */
    @PutMapping
    public ResponseEntity<ApiResponse<ThresholdSettings>> update(
            @RequestParam String deviceId,
            @Valid @RequestBody ThresholdSettings input) {
        try {
            ThresholdSettings saved = thresholdSettingsService.save(deviceId, input);
            return ResponseEntity.ok(ApiResponse.ok("บันทึกค่า threshold แล้ว", saved));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    /**
     * DELETE /api/thresholds?deviceId=xxx
     * รีเซ็ต threshold ของ device นี้กลับไปใช้ค่า default ของระบบ
     */
    @DeleteMapping
    public ResponseEntity<ApiResponse<ThresholdSettings>> reset(@RequestParam String deviceId) {
        ThresholdSettings reset = thresholdSettingsService.resetToDefault(deviceId);
        return ResponseEntity.ok(ApiResponse.ok("รีเซ็ตกลับเป็นค่า default แล้ว", reset));
    }
}
