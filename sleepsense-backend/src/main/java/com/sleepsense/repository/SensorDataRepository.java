package com.sleepsense.repository;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import com.sleepsense.model.SensorData;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ExecutionException;

@Repository
public class SensorDataRepository {

    private static final String COLLECTION = "sensor_data";

    private Firestore db() {
        return FirestoreClient.getFirestore();
    }

    /**
     * บันทึกข้อมูล sensor ลง Firestore
     */
    public String save(SensorData data) throws ExecutionException, InterruptedException {
        Map<String, Object> doc = toMap(data);
        ApiFuture<DocumentReference> future = db().collection(COLLECTION).add(doc);
        DocumentReference ref = future.get();
        return ref.getId();
    }

    /**
     * ดึงข้อมูล sensor ล่าสุด 1 รายการของ device
     */
    public Optional<SensorData> findLatest(String deviceId) throws ExecutionException, InterruptedException {
        QuerySnapshot snapshot = db().collection(COLLECTION)
                .whereEqualTo("deviceId", deviceId)
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(1)
                .get().get();

        if (snapshot.isEmpty()) return Optional.empty();
        return Optional.of(fromDocument(snapshot.getDocuments().get(0)));
    }

    /**
     * ดึงข้อมูล sensor ในช่วงเวลาที่กำหนด (สำหรับ morning report)
     */
    public List<SensorData> findByDeviceAndTimeRange(String deviceId, Instant from, Instant to)
            throws ExecutionException, InterruptedException {

        QuerySnapshot snapshot = db().collection(COLLECTION)
                .whereEqualTo("deviceId", deviceId)
                .whereGreaterThanOrEqualTo("timestamp", from.toEpochMilli())
                .whereLessThanOrEqualTo("timestamp", to.toEpochMilli())
                .orderBy("timestamp")
                .get().get();

        List<SensorData> result = new ArrayList<>();
        for (DocumentSnapshot doc : snapshot.getDocuments()) {
            result.add(fromDocument(doc));
        }
        return result;
    }

    // ──────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────

    private Map<String, Object> toMap(SensorData d) {
        Map<String, Object> m = new HashMap<>();
        m.put("deviceId",        d.getDeviceId());
        m.put("temperature",     d.getTemperature());
        m.put("humidity",        d.getHumidity());
        m.put("co2",             d.getCo2());
        m.put("pm25",            d.getPm25());
        m.put("lightIntensity",  d.getLightIntensity());
        m.put("noiseLevel",      d.getNoiseLevel());
        m.put("motionDetected",  d.isMotionDetected());
        m.put("timestamp",       d.getTimestamp().toEpochMilli());
        return m;
    }

    private SensorData fromDocument(DocumentSnapshot doc) {
        return SensorData.builder()
                .id(doc.getId())
                .deviceId(doc.getString("deviceId"))
                .temperature(getDouble(doc, "temperature"))
                .humidity(getDouble(doc, "humidity"))
                .co2(getDouble(doc, "co2"))
                .pm25(getDouble(doc, "pm25"))
                .lightIntensity(getDouble(doc, "lightIntensity"))
                .noiseLevel(getDouble(doc, "noiseLevel"))
                .motionDetected(Boolean.TRUE.equals(doc.getBoolean("motionDetected")))
                .timestamp(Instant.ofEpochMilli(doc.getLong("timestamp")))
                .build();
    }

    private double getDouble(DocumentSnapshot doc, String field) {
        Double val = doc.getDouble(field);
        return val != null ? val : 0.0;
    }
}
