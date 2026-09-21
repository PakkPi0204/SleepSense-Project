package com.sleepsense.controller;

import com.sleepsense.analysis.PatternAnalysisResult;
import com.sleepsense.dto.ApiResponse;
import com.sleepsense.service.SmartSuggestionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/suggestions")
@RequiredArgsConstructor
public class SmartSuggestionController {

    private final SmartSuggestionService smartSuggestionService;

    /**
     * GET /api/suggestions/smart?deviceId=xxx&nights=14
     *
     * <p>Runs the multi-night pattern analysis behind the Smart Suggestions
     * screen. The response carries the clustered nights and the detected
     * patterns alongside the advice, so the app can show the user why each
     * recommendation was made.
     */
    @GetMapping("/smart")
    public ResponseEntity<ApiResponse<PatternAnalysisResult>> getSmartSuggestions(
            @RequestParam String deviceId,
            @RequestParam(defaultValue = "14") int nights) {

        PatternAnalysisResult result = smartSuggestionService.analyse(deviceId, nights);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }
}
