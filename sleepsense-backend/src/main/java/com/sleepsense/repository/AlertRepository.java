package com.sleepsense.repository;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import com.sleepsense.model.Alert;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ExecutionException;

@Repository
public class AlertRepository {

    private static final String COLLECTION = "alerts";

    private Firestore db() {
        return FirestoreClient.getFirestore();
    }

    public String save(Alert alert) throws ExecutionException, InterruptedException {
        Map<String, Object> doc = new HashMap<>();
        doc.put("deviceId",  alert.getDeviceId());
        doc.put("level",     alert.getLevel().name());
        doc.put("factor",    alert.getFactor());
        doc.put("message",   alert.getMessage());
        doc.put("value",     alert.getValue());
        doc.put("threshold", alert.getThreshold());
        doc.put("timestamp", alert.getTimestamp().toEpochMilli());
        doc.put("resolved",  alert.isResolved()); // false ตามค่า default ของ Alert ใหม่

        ApiFuture<DocumentReference> future = db().collection(COLLECTION).add(doc);
        return future.get().getId();
    }

    /**
     * ปิด (resolve) alert แถวนี้ — เรียกตอน SensorService พบว่ารอบวิเคราะห์
     * ล่าสุด factor ของ alert นี้กลับมาอยู่ในช่วงปกติแล้ว (ไม่ WARNING/CRITICAL
     * อีกต่อไปภายใต้ threshold ปัจจุบัน)
     */
    public void resolve(String alertId) throws ExecutionException, InterruptedException {
        Map<String, Object> updates = new HashMap<>();
        updates.put("resolved", true);
        updates.put("resolvedAt", Instant.now().toEpochMilli());
        db().collection(COLLECTION).document(alertId).update(updates).get();
    }

    public List<Alert> findRecentByDevice(String deviceId, int limit)
            throws ExecutionException, InterruptedException {

        QuerySnapshot snapshot = db().collection(COLLECTION)
                .whereEqualTo("deviceId", deviceId)
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(limit)
                .get().get();

        List<Alert> alerts = new ArrayList<>();
        for (DocumentSnapshot doc : snapshot.getDocuments()) {
            alerts.add(toAlert(doc));
        }
        return alerts;
    }

    /**
     * alert ที่ยัง "active" อยู่จริง (resolved == false) ของ device นี้ ไม่จำกัด
     * แค่ factor เดียว — ใช้ตัดสินว่าจะสร้างแถวใหม่ซ้ำไหม (ถ้า factor เดิม
     * ระดับเดิม active อยู่แล้ว) และใช้เทียบว่า factor ไหนควรถูก resolve ไปเพราะ
     * ค่ากลับมาปกติแล้ว
     *
     * ตั้งใจไม่ใช้ whereEqualTo("resolved", false) ตรงๆ ในตัว query (จะต้อง
     * สร้าง composite index ใหม่ใน Firestore ร่วมกับ deviceId) แต่ดึงตาม
     * deviceId + orderBy timestamp แบบเดียวกับ findRecentByDevice (index เดิม
     * ที่มีอยู่แล้วรองรับอยู่แล้ว) แล้วกรอง resolved ฝั่ง Java แทน
     */
    public List<Alert> findActiveByDevice(String deviceId)
            throws ExecutionException, InterruptedException {
        QuerySnapshot snapshot = db().collection(COLLECTION)
                .whereEqualTo("deviceId", deviceId)
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(200)
                .get().get();

        List<Alert> alerts = new ArrayList<>();
        for (DocumentSnapshot doc : snapshot.getDocuments()) {
            Alert alert = toAlert(doc);
            if (!alert.isResolved()) {
                alerts.add(alert);
            }
        }
        return alerts;
    }

    private Alert toAlert(DocumentSnapshot doc) {
        // แถวเก่าก่อนเพิ่ม field นี้จะไม่มี "resolved" เลย — ถือว่า false
        // (ยัง active อยู่) เพื่อความเข้ากันได้ย้อนหลัง ไม่ทำให้ query พังหรือ
        // แถวเก่าหายไปจากผลลัพธ์
        Boolean resolved = doc.getBoolean("resolved");
        Long resolvedAtMs = doc.getLong("resolvedAt");

        return Alert.builder()
                .id(doc.getId())
                .deviceId(doc.getString("deviceId"))
                .level(Alert.AlertLevel.valueOf(doc.getString("level")))
                .factor(doc.getString("factor"))
                .message(doc.getString("message"))
                .value(doc.getDouble("value"))
                .threshold(doc.getDouble("threshold"))
                .timestamp(Instant.ofEpochMilli(doc.getLong("timestamp")))
                .resolved(resolved != null && resolved)
                .resolvedAt(resolvedAtMs != null ? Instant.ofEpochMilli(resolvedAtMs) : null)
                .build();
    }
}
