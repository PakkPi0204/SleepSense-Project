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

        ApiFuture<DocumentReference> future = db().collection(COLLECTION).add(doc);
        return future.get().getId();
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
            alerts.add(Alert.builder()
                    .id(doc.getId())
                    .deviceId(doc.getString("deviceId"))
                    .level(Alert.AlertLevel.valueOf(doc.getString("level")))
                    .factor(doc.getString("factor"))
                    .message(doc.getString("message"))
                    .value(doc.getDouble("value"))
                    .threshold(doc.getDouble("threshold"))
                    .timestamp(Instant.ofEpochMilli(doc.getLong("timestamp")))
                    .build());
        }
        return alerts;
    }
}
