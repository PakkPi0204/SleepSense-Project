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
     * Called by the Flutter app when the user stops monitoring in the morning.
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
     * Fetch the most recent morning report.
     */
    @GetMapping("/latest")
    public ResponseEntity<ApiResponse<MorningReport>> getLatest(@RequestParam String deviceId) {
        return reportService.getLatest(deviceId)
                .map(r -> ResponseEntity.ok(ApiResponse.ok(r)))
                .orElse(ResponseEntity.ok(ApiResponse.error("No report found")));
    }

    /**
     * GET /api/report/history?deviceId=xxx&limit=30
     * Fetch several nights of morning reports (used by the Morning Report history).
     */
    @GetMapping("/history")
    public ResponseEntity<ApiResponse<java.util.List<MorningReport>>> getHistory(
            @RequestParam String deviceId,
            @RequestParam(defaultValue = "30") int limit) {
        java.util.List<MorningReport> reports = reportService.getHistory(deviceId, limit);
        return ResponseEntity.ok(ApiResponse.ok(reports));
    }

    /**
     * DELETE /api/report/{reportId}
     * Delete a single morning report (the delete action in the app).
     */
    @DeleteMapping("/{reportId}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable String reportId) {
        boolean ok = reportService.deleteById(reportId);
        if (ok) {
            return ResponseEntity.ok(ApiResponse.ok("Report deleted", null));
        }
        return ResponseEntity.ok(ApiResponse.error("Failed to delete report"));
    }
}
