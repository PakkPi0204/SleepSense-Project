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
     * The Flutter app fetches recent alerts — the full history including
     * resolved ones, for the Alerts log screen.
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
     * Only alerts that are genuinely still active (not yet resolved). Used for
     * the Home badge count and the critical popup, instead of /recent, so that
     * old rows whose problem has cleared (or whose thresholds have since been
     * widened) are not counted or shown again.
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
