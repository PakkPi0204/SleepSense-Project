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
     * Flutter app ดึง alert ล่าสุด
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
}
