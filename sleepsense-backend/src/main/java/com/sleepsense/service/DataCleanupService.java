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
 * ลบข้อมูลเก่าอัตโนมัติ
 * - sensor_data และ alerts ที่เก่ากว่า X วัน จะถูกลบทิ้ง
 * - รันอัตโนมัติทุกวันตอนตี 3 (ต้องเปิด backend ค้างไว้)
 *
 * morning_reports ไม่ถูกลบอัตโนมัติ (เก็บเป็นสถิติ ลบเองผ่าน API)
 */
@Slf4j
@Service
public class DataCleanupService {

    @Value("${cleanup.retention.days:30}")
    private int retentionDays;

    @Value("${cleanup.batch.size:400}")
    private int batchSize;

    /**
     * รันทุกวันเวลา 03:00 น. (cron: วินาที นาที ชั่วโมง วัน เดือน วันในสัปดาห์)
     */
    @Scheduled(cron = "0 0 3 * * *")
    public void cleanupOldData() {
        long cutoff = Instant.now().minus(retentionDays, ChronoUnit.DAYS).toEpochMilli();
        log.info("เริ่มลบข้อมูลเก่ากว่า {} วัน (ก่อน timestamp {})", retentionDays, cutoff);

        int deletedSensor = deleteOlderThan("sensor_data", cutoff);
        int deletedAlerts = deleteOlderThan("alerts", cutoff);

        log.info("ลบข้อมูลเสร็จ: sensor_data={} รายการ, alerts={} รายการ",
                deletedSensor, deletedAlerts);
    }

    /**
     * ลบ document ใน collection ที่ timestamp เก่ากว่า cutoff
     * ลบทีละ batch เพื่อไม่ให้หนักเกินไป
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

                // ถ้าได้น้อยกว่า batch size แปลว่าหมดแล้ว
                if (docs.size() < batchSize) break;
            }
        } catch (Exception e) {
            log.error("ลบข้อมูล collection {} ล้มเหลว", collection, e);
        }

        return totalDeleted;
    }
}
