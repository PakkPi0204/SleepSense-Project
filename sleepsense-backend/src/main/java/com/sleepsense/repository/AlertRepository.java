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
        doc.put("resolved",  alert.isResolved()); // false by default for a new Alert

        ApiFuture<DocumentReference> future = db().collection(COLLECTION).add(doc);
        return future.get().getId();
    }

    /**
     * Resolve this alert row. Called when SensorService finds that the latest
     * analysis pass no longer flags this factor as WARNING or CRITICAL under the
     * current thresholds.
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
     * Every alert for this device that is still active (resolved == false),
     * across all factors. Used to decide whether a new row is needed (an
     * unchanged factor at an unchanged level does not need one) and to work out
     * which factors should now be resolved because the value came back to normal.
     *
     * Deliberately avoids whereEqualTo("resolved", false) in the query, which
     * would need a new composite index on top of deviceId. Instead it queries by
     * deviceId + orderBy timestamp exactly like findRecentByDevice — the index
     * that already exists — and filters on resolved in Java.
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
        // Rows written before this field existed have no "resolved" key. Treat
        // them as false (still active) for backward compatibility, so old rows
        // neither break the query nor disappear from the results.
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
