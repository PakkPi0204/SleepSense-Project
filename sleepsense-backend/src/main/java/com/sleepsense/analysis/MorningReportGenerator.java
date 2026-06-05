package com.sleepsense.analysis;

import com.sleepsense.model.MorningReport;
import com.sleepsense.model.SensorData;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.OptionalDouble;

/**
 * สร้าง Morning Report จากข้อมูลตลอดคืน
 */
@Component
public class MorningReportGenerator {

    private final EnvironmentClusterer clusterer;

    public MorningReportGenerator(EnvironmentClusterer clusterer) {
        this.clusterer = clusterer;
    }

    public MorningReport generate(String deviceId, List<SensorData> data,
                                   Instant sleepStart, Instant sleepEnd) {
        if (data.isEmpty()) {
            return MorningReport.builder()
                    .deviceId(deviceId)
                    .sleepStart(sleepStart)
                    .sleepEnd(sleepEnd)
                    .environmentCluster("UNKNOWN")
                    .generatedAt(Instant.now())
                    .build();
        }

        // ─── Averages ───
        double avgTemp  = avg(data, d -> d.getTemperature());
        double avgHum   = avg(data, d -> d.getHumidity());
        double avgCo2   = avg(data, d -> d.getCo2());
        double avgPm25  = avg(data, d -> d.getPm25());
        double avgLight = avg(data, d -> d.getLightIntensity());
        double avgNoise = avg(data, d -> d.getNoiseLevel());

        // ─── Max values ───
        double maxTemp  = max(data, d -> d.getTemperature());
        double maxCo2   = max(data, d -> d.getCo2());
        double maxPm25  = max(data, d -> d.getPm25());
        double maxNoise = max(data, d -> d.getNoiseLevel());

        // ─── Motion ───
        long motionCount = data.stream().filter(SensorData::isMotionDetected).count();
        String motionPattern = motionCount < 5 ? "LOW"
                             : motionCount < 15 ? "MODERATE"
                             : "HIGH";

        // ─── Clustering ───
        String cluster = clusterer.cluster(data);

        // ─── Anomalies ───
        List<String> anomalies = detectAnomalies(avgTemp, maxCo2, maxPm25, maxNoise, motionPattern);

        // ─── Suggestions ───
        List<String> suggestions = buildSuggestions(avgTemp, avgCo2, avgPm25, avgNoise, motionPattern, cluster);

        return MorningReport.builder()
                .deviceId(deviceId)
                .sleepStart(sleepStart)
                .sleepEnd(sleepEnd)
                .avgTemperature(round(avgTemp))
                .avgHumidity(round(avgHum))
                .avgCo2(round(avgCo2))
                .avgPm25(round(avgPm25))
                .avgLight(round(avgLight))
                .avgNoise(round(avgNoise))
                .maxTemperature(round(maxTemp))
                .maxCo2(round(maxCo2))
                .maxPm25(round(maxPm25))
                .maxNoise(round(maxNoise))
                .motionEventCount((int) motionCount)
                .motionPattern(motionPattern)
                .environmentCluster(cluster)
                .anomalies(anomalies)
                .suggestions(suggestions)
                .generatedAt(Instant.now())
                .build();
    }

    // ──────────────────────────────────────────────
    private List<String> detectAnomalies(double avgTemp, double maxCo2,
                                          double maxPm25, double maxNoise,
                                          String motionPattern) {
        List<String> anomalies = new ArrayList<>();
        if (avgTemp > 26)  anomalies.add("อุณหภูมิเฉลี่ยสูงตลอดคืน (" + avgTemp + "°C)");
        if (maxCo2 > 1000) anomalies.add("CO₂ สูงสุดเกินมาตรฐาน (" + (int)maxCo2 + " ppm)");
        if (maxPm25 > 35)  anomalies.add("ฝุ่น PM2.5 สูงสุดเกินมาตรฐาน (" + maxPm25 + " µg/m³)");
        if (maxNoise > 60) anomalies.add("มีเสียงรบกวนระดับสูง (" + (int)maxNoise + " dB)");
        if ("HIGH".equals(motionPattern)) anomalies.add("ตรวจพบการเคลื่อนไหวบ่อยครั้งระหว่างนอน");
        return anomalies;
    }

    private List<String> buildSuggestions(double avgTemp, double avgCo2, double avgPm25,
                                           double avgNoise, String motionPattern, String cluster) {
        List<String> s = new ArrayList<>();

        if (avgTemp > 26)
            s.add("ลองปรับอุณหภูมิแอร์ให้อยู่ที่ 20–24°C เพื่อการนอนที่สบายขึ้น");
        if (avgCo2 > 1000)
            s.add("เปิดหน้าต่างหรือปรับระบบระบายอากาศก่อนนอน เพื่อลด CO₂");
        if (avgPm25 > 35)
            s.add("ใช้เครื่องฟอกอากาศในห้องนอนเพื่อลดฝุ่น PM2.5");
        if (avgNoise > 40)
            s.add("ลดแหล่งเสียงรบกวนหรือใช้เครื่องเสียงสีขาว (white noise)");
        if ("HIGH".equals(motionPattern))
            s.add("การเคลื่อนไหวบ่อยอาจเกิดจากความไม่สบายตัว — ตรวจสอบอุณหภูมิและที่นอน");
        if ("GOOD".equals(cluster))
            s.add("สภาพแวดล้อมห้องนอนโดยรวมดี ✓ รักษาสภาพนี้ต่อไป");
        if (s.isEmpty())
            s.add("สภาพแวดล้อมห้องนอนอยู่ในเกณฑ์ดี ไม่มีข้อแนะนำเพิ่มเติม");

        return s;
    }

    // ──────────────────────────────────────────────
    private double avg(List<SensorData> data, java.util.function.ToDoubleFunction<SensorData> fn) {
        OptionalDouble r = data.stream().mapToDouble(fn).average();
        return r.isPresent() ? r.getAsDouble() : 0.0;
    }

    private double max(List<SensorData> data, java.util.function.ToDoubleFunction<SensorData> fn) {
        OptionalDouble r = data.stream().mapToDouble(fn).max();
        return r.isPresent() ? r.getAsDouble() : 0.0;
    }

    private double round(double v) {
        return Math.round(v * 10.0) / 10.0;
    }
}
