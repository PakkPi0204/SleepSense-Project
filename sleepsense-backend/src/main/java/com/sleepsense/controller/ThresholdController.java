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
     * Returns this device's effective thresholds (custom if any, otherwise the
     * defaults), with a "customized" flag saying which of the two it is.
     */
    @GetMapping
    public ResponseEntity<ApiResponse<ThresholdSettings>> get(@RequestParam String deviceId) {
        ThresholdSettings settings = thresholdSettingsService.getSettingsOrDefault(deviceId);
        return ResponseEntity.ok(ApiResponse.ok(settings));
    }

    /**
     * PUT /api/thresholds?deviceId=xxx
     * Save the user's custom thresholds. Send the whole set or only the fields
     * you want to change; null fields fall back to the system defaults in use.
     */
    @PutMapping
    public ResponseEntity<ApiResponse<ThresholdSettings>> update(
            @RequestParam String deviceId,
            @Valid @RequestBody ThresholdSettings input) {
        try {
            ThresholdSettings saved = thresholdSettingsService.save(deviceId, input);
            return ResponseEntity.ok(ApiResponse.ok("Thresholds saved", saved));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    /**
     * DELETE /api/thresholds?deviceId=xxx
     * Reset this device's thresholds back to the system defaults.
     */
    @DeleteMapping
    public ResponseEntity<ApiResponse<ThresholdSettings>> reset(@RequestParam String deviceId) {
        ThresholdSettings reset = thresholdSettingsService.resetToDefault(deviceId);
        return ResponseEntity.ok(ApiResponse.ok("Reset to system defaults", reset));
    }
}
