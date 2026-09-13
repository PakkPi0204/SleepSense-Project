package com.sleepsense.controller;

import com.sleepsense.dto.ApiResponse;
import com.sleepsense.model.Alert;
import com.sleepsense.repository.AlertRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/alerts")
@RequiredArgsConstructor
public class AlertController {

    private final AlertRepository alertRepository;

    /**
     * GET /api/alerts/recent?deviceId=xxx&limit=20
     * Flutter app ดึง alert ล่าสุด (ประวัติทั้งหมด รวมที่ resolved แล้ว —
     * ใช้กับหน้า Alerts history/log)
     */
    @GetMapping("/recent")
    public ResponseEntity<ApiResponse<List<Alert>>> getRecent(
            @RequestParam String deviceId,
            @RequestParam(defaultValue = "20") int limit) {
        try {
            List<Alert> alerts = alertRepository.findRecentByDevice(deviceId, limit);
            return ResponseEntity.ok(ApiResponse.ok(alerts));
        } catch (Exception e) {
            return ResponseEntity.ok(ApiResponse.error("Failed to fetch alerts: " + e.getMessage()));
        }
    }

    /**
     * GET /api/alerts/active?deviceId=xxx
     * alert ที่ยัง active อยู่จริง (ยังไม่ resolved) เท่านั้น — ใช้กับ badge
     * นับจำนวนแจ้งเตือนหน้า Home และ critical popup แทน /recent เพื่อไม่ให้
     * แถวเก่าที่ปัญหาหายไปแล้ว (หรือ threshold ถูกปรับใหม่จนไม่วิกฤตแล้ว) ถูก
     * นับ/บังคับเด้งซ้ำอีก
     */
    @GetMapping("/active")
    public ResponseEntity<ApiResponse<List<Alert>>> getActive(
            @RequestParam String deviceId) {
        try {
            List<Alert> alerts = alertRepository.findActiveByDevice(deviceId);
            return ResponseEntity.ok(ApiResponse.ok(alerts));
        } catch (Exception e) {
            return ResponseEntity.ok(ApiResponse.error("Failed to fetch active alerts: " + e.getMessage()));
        }
    }
}
