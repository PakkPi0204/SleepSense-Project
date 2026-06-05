package com.sleepsense.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import com.sleepsense.analysis.MorningReportGenerator;
import com.sleepsense.model.MorningReport;
import com.sleepsense.model.SensorData;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ExecutionException;

@Slf4j
@Service
@RequiredArgsConstructor
public class MorningReportService {

    private static final String COLLECTION = "morning_reports";

    private final SensorService sensorService;
    private final MorningReportGenerator generator;

    /**
     * สร้างและบันทึก morning report สำหรับช่วงเวลาที่ระบุ
     */
    public MorningReport generate(String deviceId, Instant sleepStart, Instant sleepEnd) {
        List<SensorData> data = sensorService.getRange(deviceId, sleepStart, sleepEnd);
        MorningReport report = generator.generate(deviceId, data, sleepStart, sleepEnd);

        try {
            Firestore db = FirestoreClient.getFirestore();
            Map<String, Object> doc = toMap(report);
            ApiFuture<DocumentReference> future = db.collection(COLLECTION).add(doc);
            report.setId(future.get().getId());
        } catch (Exception e) {
            log.error("Failed to save morning report", e);
        }

        return report;
    }

    /**
     * ดึง morning report ล่าสุดของ device
     */
    public Optional<MorningReport> getLatest(String deviceId) {
        try {
            Firestore db = FirestoreClient.getFirestore();
            QuerySnapshot snapshot = db.collection(COLLECTION)
                    .whereEqualTo("deviceId", deviceId)
                    .orderBy("generatedAt", Query.Direction.DESCENDING)
                    .limit(1)
                    .get().get();

            if (snapshot.isEmpty()) return Optional.empty();
            return Optional.of(fromDocument(snapshot.getDocuments().get(0)));
        } catch (ExecutionException | InterruptedException e) {
            log.error("Failed to get morning report", e);
            throw new RuntimeException("Database error", e);
        }
    }

    // ──────────────────────────────────────────────
    private Map<String, Object> toMap(MorningReport r) {
        Map<String, Object> m = new HashMap<>();
        m.put("deviceId",           r.getDeviceId());
        m.put("sleepStart",         r.getSleepStart().toEpochMilli());
        m.put("sleepEnd",           r.getSleepEnd().toEpochMilli());
        m.put("avgTemperature",     r.getAvgTemperature());
        m.put("avgHumidity",        r.getAvgHumidity());
        m.put("avgCo2",             r.getAvgCo2());
        m.put("avgPm25",            r.getAvgPm25());
        m.put("avgLight",           r.getAvgLight());
        m.put("avgNoise",           r.getAvgNoise());
        m.put("maxTemperature",     r.getMaxTemperature());
        m.put("maxCo2",             r.getMaxCo2());
        m.put("maxPm25",            r.getMaxPm25());
        m.put("maxNoise",           r.getMaxNoise());
        m.put("motionEventCount",   r.getMotionEventCount());
        m.put("motionPattern",      r.getMotionPattern());
        m.put("environmentCluster", r.getEnvironmentCluster());
        m.put("anomalies",          r.getAnomalies());
        m.put("suggestions",        r.getSuggestions());
        m.put("generatedAt",        r.getGeneratedAt().toEpochMilli());
        return m;
    }

    private MorningReport fromDocument(DocumentSnapshot doc) {
        return MorningReport.builder()
                .id(doc.getId())
                .deviceId(doc.getString("deviceId"))
                .sleepStart(Instant.ofEpochMilli(doc.getLong("sleepStart")))
                .sleepEnd(Instant.ofEpochMilli(doc.getLong("sleepEnd")))
                .avgTemperature(doc.getDouble("avgTemperature"))
                .avgHumidity(doc.getDouble("avgHumidity"))
                .avgCo2(doc.getDouble("avgCo2"))
                .avgPm25(doc.getDouble("avgPm25"))
                .avgLight(doc.getDouble("avgLight"))
                .avgNoise(doc.getDouble("avgNoise"))
                .maxTemperature(doc.getDouble("maxTemperature"))
                .maxCo2(doc.getDouble("maxCo2"))
                .maxPm25(doc.getDouble("maxPm25"))
                .maxNoise(doc.getDouble("maxNoise"))
                .motionEventCount(Objects.requireNonNull(doc.getLong("motionEventCount")).intValue())
                .motionPattern(doc.getString("motionPattern"))
                .environmentCluster(doc.getString("environmentCluster"))
                .anomalies((List<String>) doc.get("anomalies"))
                .suggestions((List<String>) doc.get("suggestions"))
                .generatedAt(Instant.ofEpochMilli(doc.getLong("generatedAt")))
                .build();
    }
}
