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

    /**
     * ดึง morning report ย้อนหลังหลายคืน (สำหรับหน้า Stats)
     */
    public List<MorningReport> getHistory(String deviceId, int limit) {
        try {
            Firestore db = FirestoreClient.getFirestore();
            QuerySnapshot snapshot = db.collection(COLLECTION)
                    .whereEqualTo("deviceId", deviceId)
                    .orderBy("generatedAt", Query.Direction.DESCENDING)
                    .limit(limit)
                    .get().get();

            List<MorningReport> reports = new ArrayList<>();
            for (DocumentSnapshot doc : snapshot.getDocuments()) {
                reports.add(fromDocument(doc));
            }
            return reports;
        } catch (ExecutionException | InterruptedException e) {
            log.error("Failed to get morning report history", e);
            throw new RuntimeException("Database error", e);
        }
    }

    /**
     * ลบ morning report ตาม id (สำหรับปุ่มลบในแอป)
     */
    public boolean deleteById(String reportId) {
        try {
            Firestore db = FirestoreClient.getFirestore();
            db.collection(COLLECTION).document(reportId).delete().get();
            log.info("ลบ morning report: {}", reportId);
            return true;
        } catch (Exception e) {
            log.error("ลบ morning report {} ล้มเหลว", reportId, e);
            return false;
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
                .sleepStart(Instant.ofEpochMilli(getLong(doc, "sleepStart")))
                .sleepEnd(Instant.ofEpochMilli(getLong(doc, "sleepEnd")))
                .avgTemperature(getDouble(doc, "avgTemperature"))
                .avgHumidity(getDouble(doc, "avgHumidity"))
                .avgCo2(getDouble(doc, "avgCo2"))
                .avgPm25(getDouble(doc, "avgPm25"))
                .avgLight(getDouble(doc, "avgLight"))
                .avgNoise(getDouble(doc, "avgNoise"))
                .maxTemperature(getDouble(doc, "maxTemperature"))
                .maxCo2(getDouble(doc, "maxCo2"))
                .maxPm25(getDouble(doc, "maxPm25"))
                .maxNoise(getDouble(doc, "maxNoise"))
                .motionEventCount((int) getLong(doc, "motionEventCount"))
                .motionPattern(doc.getString("motionPattern"))
                .environmentCluster(doc.getString("environmentCluster"))
                .anomalies(getStringList(doc, "anomalies"))
                .suggestions(getStringList(doc, "suggestions"))
                .generatedAt(Instant.ofEpochMilli(getLong(doc, "generatedAt")))
                .build();
    }

    // ── null-safe helpers ──
    private long getLong(DocumentSnapshot doc, String field) {
        Long v = doc.getLong(field);
        return v != null ? v : 0L;
    }

    private double getDouble(DocumentSnapshot doc, String field) {
        Double v = doc.getDouble(field);
        return v != null ? v : 0.0;
    }

    @SuppressWarnings("unchecked")
    private List<String> getStringList(DocumentSnapshot doc, String field) {
        Object v = doc.get(field);
        if (v instanceof List<?> list) {
            return list.stream().map(String::valueOf).collect(java.util.stream.Collectors.toList());
        }
        return new java.util.ArrayList<>();
    }
}
