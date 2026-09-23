package com.sleepsense.service;

import com.sleepsense.analysis.PatternAnalysisResult;
import com.sleepsense.analysis.PatternAnalyzer;
import com.sleepsense.config.ThresholdConfig;
import com.sleepsense.model.MorningReport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Serves the Smart Suggestions screen: pull the recent Morning Reports for a
 * device and run the multi-night pattern analysis over them.
 *
 * <p>Test Plan reference: STC-04.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SmartSuggestionService {

    /** How many nights of history to look at by default. */
    public static final int DEFAULT_WINDOW = 14;

    private final MorningReportService reportService;
    private final ThresholdSettingsService thresholdSettingsService;
    private final PatternAnalyzer patternAnalyzer;

    public PatternAnalysisResult analyse(String deviceId, int nights) {
        int window = nights > 0 ? nights : DEFAULT_WINDOW;

        List<MorningReport> history;
        try {
            history = reportService.getHistory(deviceId, window);
        } catch (Exception e) {
            log.error("Failed to load report history for {}", deviceId, e);
            throw new RuntimeException("Database error", e);
        }

        ThresholdConfig effective = thresholdSettingsService.getEffective(deviceId);
        return patternAnalyzer.analyse(history, effective);
    }
}
