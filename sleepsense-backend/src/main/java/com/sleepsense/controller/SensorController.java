package com.sleepsense.controller;

import com.sleepsense.dto.ApiResponse;
import com.sleepsense.dto.SensorDataRequest;
import com.sleepsense.model.SensorData;
import com.sleepsense.service.SensorService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/sensor")
@RequiredArgsConstructor
public class SensorController {

    private final SensorService sensorService;

    /**
     * POST /api/sensor/data
     * ESP32 ส่งข้อมูล sensor มาทุก 30–60 วินาที
     */
    @PostMapping("/data")
    public ResponseEntity<ApiResponse<SensorData>> ingest(@Valid @RequestBody SensorDataRequest req) {
        SensorData saved = sensorService.ingest(req);
        return ResponseEntity.ok(ApiResponse.ok("Data received", saved));
    }

    /**
     * GET /api/sensor/latest?deviceId=xxx
     * Flutter app ดึงค่าล่าสุดเพื่อแสดง real-time dashboard
     */
    @GetMapping("/latest")
    public ResponseEntity<ApiResponse<SensorData>> getLatest(@RequestParam String deviceId) {
        return sensorService.getLatest(deviceId)
                .map(d -> ResponseEntity.ok(ApiResponse.ok(d)))
                .orElse(ResponseEntity.ok(ApiResponse.error("No data found")));
    }

    /**
     * GET /api/sensor/presleep?deviceId=xxx
     * Flutter app ขอคำแนะนำก่อนนอน
     */
    @GetMapping("/presleep")
    public ResponseEntity<ApiResponse<List<String>>> getPreSleepSuggestions(@RequestParam String deviceId) {
        List<String> suggestions = sensorService.getPreSleepSuggestions(deviceId);
        return ResponseEntity.ok(ApiResponse.ok(suggestions));
    }
}
