# SleepSense Backend

Spring Boot backend สำหรับโปรเจกต์ SleepSense — IoT Sleep Environment Monitoring System

---

## วิธี Build & Run

### สิ่งที่ต้องมีก่อน
- Java 17 (JDK)
- Maven (หรือใช้ IDE เช่น IntelliJ/VS Code ที่มี Maven ในตัว)
- ไฟล์ Firebase service account key (JSON) — ดาวน์โหลดจาก Firebase Console →
  Project Settings → Service Accounts → Generate new private key

### ขั้นตอน
1. วางไฟล์ Firebase key ที่ดาวน์โหลดมาไว้ที่
   `sleepsense-backend/src/main/resources/firebase-service-account.json`
2. แก้ `src/main/resources/application.properties` ให้ `firebase.database.url`
   ตรงกับ Firestore project จริงของคุณ (ค่าเริ่มต้นเป็นแค่ placeholder)
3. Build (ดาวน์โหลด dependency + compile + รัน unit test):
   ```
   cd sleepsense-backend
   mvn clean install
   ```
4. รันเซิร์ฟเวอร์:
   ```
   mvn spring-boot:run
   ```
   หรือรันจาก jar ที่ build เสร็จแล้ว:
   ```
   java -jar target/sleepsense-backend-1.0.0.jar
   ```
5. เช็คว่าเซิร์ฟเวอร์ขึ้นสำเร็จ — ควรเห็น log "Started SleepSenseApplication"
   แล้วลองเปิด `http://localhost:8080/api/thresholds?deviceId=test-device-01`
   ในเบราว์เซอร์ ควรได้ JSON response กลับมา

**หมายเหตุ:** ทุกครั้งที่แก้โค้ด Java หรือ `application.properties` ต้อง
**restart เซิร์ฟเวอร์ใหม่** (`Ctrl+C` แล้วรัน `mvn spring-boot:run` อีกครั้ง)
ค่าที่แก้ถึงจะมีผลจริง — ตัว build ไม่ได้ hot-reload อัตโนมัติ

---

## Architecture

```
ESP32 (sensors) ──POST──► Spring Boot API ──► Firebase Firestore
                                │
Flutter App ◄──GET/POST────────┘
```

## Stack
- **Spring Boot 3.2** (Java 17)
- **Firebase Admin SDK** — Firestore database
- **Lombok** — reduce boilerplate


---

## API Endpoints

### Sensor Data (ESP32 → Server)
| Method | Endpoint | คำอธิบาย |
|--------|----------|-----------|
| POST | `/api/sensor/data` | ESP32 ส่งข้อมูล sensor |
| GET | `/api/sensor/latest?deviceId=xxx` | ดึงค่าล่าสุด (real-time dashboard) |
| GET | `/api/sensor/presleep?deviceId=xxx` | คำแนะนำ pre-sleep |

### Morning Report
| Method | Endpoint | คำอธิบาย |
|--------|----------|-----------|
| POST | `/api/report/generate?deviceId=xxx&sleepStart=ms&sleepEnd=ms` | สร้างรายงานเช้า |
| GET | `/api/report/latest?deviceId=xxx` | รายงานล่าสุด |

### Alerts
| Method | Endpoint | คำอธิบาย |
|--------|----------|-----------|
| GET | `/api/alerts/recent?deviceId=xxx&limit=20` | alert ล่าสุด |

---

## ESP32 — ตัวอย่าง POST /api/sensor/data

```json
{
  "deviceId": "esp32-room-01",
  "temperature": 27.5,
  "humidity": 65.0,
  "co2": 850.0,
  "pm25": 18.5,
  "lightIntensity": 12.0,
  "noiseLevel": 38.0,
  "motionDetected": false
}
```

Response:
```json
{
  "success": true,
  "message": "Data received",
  "data": {
    "id": "abc123",
    "deviceId": "esp32-room-01",
    ...
  }
}
```

---

## Project Structure
```
src/main/java/com/sleepsense/
├── SleepSenseApplication.java
├── analysis/
│   ├── ThresholdAnalyzer.java     ← Threshold-Based Analysis
│   ├── EnvironmentClusterer.java  ← Data Clustering
│   └── MorningReportGenerator.java
├── config/
│   ├── FirebaseConfig.java
│   ├── CorsConfig.java
│   └── ThresholdConfig.java      ← ปรับ threshold ได้ใน application.properties
├── controller/
│   ├── SensorController.java
│   ├── MorningReportController.java
│   ├── AlertController.java
│   └── GlobalExceptionHandler.java
├── dto/
│   ├── SensorDataRequest.java
│   └── ApiResponse.java
├── model/
│   ├── SensorData.java
│   ├── Alert.java
│   └── MorningReport.java
├── repository/
│   ├── SensorDataRepository.java
│   └── AlertRepository.java
└── service/
    ├── SensorService.java
    └── MorningReportService.java
```

---

## Firestore Collections
| Collection | คำอธิบาย |
|------------|-----------|
| `sensor_data` | raw sensor readings ทุก 30–60 วินาที |
| `alerts` | alerts ที่เกิดจาก threshold analysis |
| `morning_reports` | รายงานสรุปตอนเช้า |

---

## Threshold Defaults (ปรับได้ใน application.properties)
| Factor | Warning | Critical |
|--------|---------|----------|
| CO₂ | 1000 ppm | 2000 ppm |
| Temperature | <18 หรือ >26 °C | — |
| Humidity | <40 หรือ >60 % | — |
| PM2.5 | 35 µg/m³ | 75 µg/m³ |
| Light | >50 lux | — |
| Noise | 40 dB | 60 dB |
