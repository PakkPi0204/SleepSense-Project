package com.sleepsense.service;

import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Automatic cleanup of old data.
 * - sensor_data and alerts older than the retention window are deleted
 * - runs every day at 03:00 (the backend has to stay up for this)
 *
 * morning_reports are never deleted automatically — they are the user's
 * history, and are removed individually through the API instead.
 */
@Slf4j
@Service
public class DataCleanupService {

    @Value("${cleanup.retention.days:30}")
    private int retentionDays;

    @Value("${cleanup.batch.size:400}")
    private int batchSize;

    /**
     * Runs daily at 03:00 (cron fields: second minute hour day month weekday).
     */
    @Scheduled(cron = "0 0 3 * * *")
    public void cleanupOldData() {
        long cutoff = Instant.now().minus(retentionDays, ChronoUnit.DAYS).toEpochMilli();
        log.info("Deleting data older than {} days (before timestamp {})", retentionDays, cutoff);

        int deletedSensor = deleteOlderThan("sensor_data", cutoff);
        int deletedAlerts = deleteOlderThan("alerts", cutoff);

        log.info("Cleanup finished: sensor_data={} documents, alerts={} documents",
                deletedSensor, deletedAlerts);
    }

    /**
     * Delete documents in a collection whose timestamp is older than the cutoff,
     * one batch at a time so a large backlog does not overwhelm Firestore.
     */
    private int deleteOlderThan(String collection, long cutoff) {
        Firestore db = FirestoreClient.getFirestore();
        int totalDeleted = 0;

        try {
            while (true) {
                QuerySnapshot snapshot = db.collection(collection)
                        .whereLessThan("timestamp", cutoff)
                        .limit(batchSize)
                        .get().get();

                List<QueryDocumentSnapshot> docs = snapshot.getDocuments();
                if (docs.isEmpty()) break;

                WriteBatch batch = db.batch();
                for (QueryDocumentSnapshot doc : docs) {
                    batch.delete(doc.getReference());
                }
                batch.commit().get();

                totalDeleted += docs.size();

                // A short page means there is nothing left to delete.
                if (docs.size() < batchSize) break;
            }
        } catch (Exception e) {
            log.error("Failed to clean up collection {}", collection, e);
        }

        return totalDeleted;
    }
}
