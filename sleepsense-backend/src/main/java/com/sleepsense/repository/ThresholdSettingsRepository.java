package com.sleepsense.repository;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.google.firebase.cloud.FirestoreClient;
import com.sleepsense.model.ThresholdSettings;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ExecutionException;

@Repository
public class ThresholdSettingsRepository {

    private static final String COLLECTION = "threshold_settings";

    private Firestore db() {
        return FirestoreClient.getFirestore();
    }

    /** The deviceId is the document id — one device, one settings document. */
    public Optional<ThresholdSettings> findByDeviceId(String deviceId)
            throws ExecutionException, InterruptedException {
        DocumentSnapshot doc = db().collection(COLLECTION).document(deviceId).get().get();
        if (!doc.exists()) return Optional.empty();
        return Optional.of(fromDocument(doc));
    }

    public void save(ThresholdSettings settings) throws ExecutionException, InterruptedException {
        ApiFuture<WriteResult> future =
                db().collection(COLLECTION).document(settings.getDeviceId()).set(toMap(settings));
        future.get();
    }

    public void delete(String deviceId) throws ExecutionException, InterruptedException {
        db().collection(COLLECTION).document(deviceId).delete().get();
    }

    // ──────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────

    private Map<String, Object> toMap(ThresholdSettings s) {
        Map<String, Object> m = new HashMap<>();
        m.put("deviceId", s.getDeviceId());
        m.put("co2Warning", s.getCo2Warning());
        m.put("co2Critical", s.getCo2Critical());
        m.put("temperatureMin", s.getTemperatureMin());
        m.put("temperatureMax", s.getTemperatureMax());
        m.put("temperatureCriticalMin", s.getTemperatureCriticalMin());
        m.put("temperatureCriticalMax", s.getTemperatureCriticalMax());
        m.put("humidityMin", s.getHumidityMin());
        m.put("humidityMax", s.getHumidityMax());
        m.put("humidityCriticalMin", s.getHumidityCriticalMin());
        m.put("humidityCriticalMax", s.getHumidityCriticalMax());
        m.put("pm25Warning", s.getPm25Warning());
        m.put("pm25Critical", s.getPm25Critical());
        m.put("lightMax", s.getLightMax());
        m.put("lightCritical", s.getLightCritical());
        m.put("noiseWarning", s.getNoiseWarning());
        m.put("noiseCritical", s.getNoiseCritical());
        m.put("updatedAt", Instant.now().toEpochMilli());
        return m;
    }

    private ThresholdSettings fromDocument(DocumentSnapshot doc) {
        Long updatedAtMillis = doc.getLong("updatedAt");
        return ThresholdSettings.builder()
                .deviceId(doc.getString("deviceId"))
                .co2Warning(doc.getDouble("co2Warning"))
                .co2Critical(doc.getDouble("co2Critical"))
                .temperatureMin(doc.getDouble("temperatureMin"))
                .temperatureMax(doc.getDouble("temperatureMax"))
                .temperatureCriticalMin(doc.getDouble("temperatureCriticalMin"))
                .temperatureCriticalMax(doc.getDouble("temperatureCriticalMax"))
                .humidityMin(doc.getDouble("humidityMin"))
                .humidityMax(doc.getDouble("humidityMax"))
                .humidityCriticalMin(doc.getDouble("humidityCriticalMin"))
                .humidityCriticalMax(doc.getDouble("humidityCriticalMax"))
                .pm25Warning(doc.getDouble("pm25Warning"))
                .pm25Critical(doc.getDouble("pm25Critical"))
                .lightMax(doc.getDouble("lightMax"))
                .lightCritical(doc.getDouble("lightCritical"))
                .noiseWarning(doc.getDouble("noiseWarning"))
                .noiseCritical(doc.getDouble("noiseCritical"))
                .updatedAt(updatedAtMillis != null ? Instant.ofEpochMilli(updatedAtMillis) : null)
                .customized(true)
                .build();
    }
}
