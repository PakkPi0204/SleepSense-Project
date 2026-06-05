package com.sleepsense.controller;

import com.sleepsense.dto.ApiResponse;
import com.sleepsense.model.MorningReport;
import com.sleepsense.service.MorningReportService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@RestController
@RequestMapping("/api/report")
@RequiredArgsConstructor
public class MorningReportController {

    private final MorningReportService reportService;

    /**
     * POST /api/report/generate?deviceId=xxx&sleepStart=...&sleepEnd=...
     * Flutter app เรียกตอนผู้ใช้กด "ดูรายงาน" หลังตื่นนอน
     */
    @PostMapping("/generate")
    public ResponseEntity<ApiResponse<MorningReport>> generate(
            @RequestParam String deviceId,
            @RequestParam long sleepStart,   // epoch millis
            @RequestParam long sleepEnd) {

        MorningReport report = reportService.generate(
                deviceId,
                Instant.ofEpochMilli(sleepStart),
                Instant.ofEpochMilli(sleepEnd));

        return ResponseEntity.ok(ApiResponse.ok(report));
    }

    /**
     * GET /api/report/latest?deviceId=xxx
     * ดึง morning report ล่าสุด
     */
    @GetMapping("/latest")
    public ResponseEntity<ApiResponse<MorningReport>> getLatest(@RequestParam String deviceId) {
        return reportService.getLatest(deviceId)
                .map(r -> ResponseEntity.ok(ApiResponse.ok(r)))
                .orElse(ResponseEntity.ok(ApiResponse.error("No report found")));
    }
}
