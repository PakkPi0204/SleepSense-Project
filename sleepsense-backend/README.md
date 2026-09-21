# SleepSense Backend

Spring Boot backend for SleepSense — an IoT sleep environment monitoring system.

---

## Build and run

### Prerequisites
- Java 17 (JDK)
- Maven (or an IDE with Maven built in, such as IntelliJ or VS Code)
- A Firebase service account key (JSON) — download it from the Firebase Console:
  Project Settings → Service Accounts → Generate new private key

### Steps
1. Put the downloaded Firebase key at
   `sleepsense-backend/src/main/resources/firebase-service-account.json`
2. Edit `src/main/resources/application.properties` so `firebase.database.url`
   matches your real Firestore project — the default is only a placeholder.
3. Build (fetch dependencies, compile, run the unit tests):
   ```
   cd sleepsense-backend
   mvn clean install
   ```
4. Run the server:
   ```
   mvn spring-boot:run
   ```
   Or run the built jar:
   ```
   java -jar target/sleepsense-backend-1.0.0.jar
   ```
5. Check it started — you should see `Started SleepSenseApplication` in the log.
   Then open `http://localhost:8080/api/thresholds?deviceId=test-device-01` in a
   browser; it should return JSON.

**Note:** after changing any Java file or `application.properties` you have to
**restart the server** (`Ctrl+C`, then `mvn spring-boot:run` again) before the
change takes effect. There is no hot reload.

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
- **Lombok** — reduces boilerplate

---

## API endpoints

### Sensor data (ESP32 → server)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/sensor/data` | the ESP32 posts a round of readings |
| GET | `/api/sensor/latest?deviceId=xxx` | latest values, for the real-time dashboard |
| GET | `/api/sensor/presleep?deviceId=xxx` | pre-sleep advice for the current reading |

### Morning reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/report/generate?deviceId=xxx&sleepStart=ms&sleepEnd=ms` | build a report for a sleep window |
| GET | `/api/report/latest?deviceId=xxx` | the most recent report |
| GET | `/api/report/history?deviceId=xxx&limit=30` | several nights of reports |
| DELETE | `/api/report/{reportId}` | delete one report |

### Smart suggestions
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/suggestions/smart?deviceId=xxx&nights=14` | multi-night pattern analysis: clustered nights, detected patterns and the advice derived from them |

### Alerts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/alerts/recent?deviceId=xxx&limit=20` | full alert history, including resolved |
| GET | `/api/alerts/active?deviceId=xxx` | only alerts that are still active |

### Thresholds
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/thresholds?deviceId=xxx` | effective thresholds, with a `customized` flag |
| PUT | `/api/thresholds?deviceId=xxx` | save custom thresholds |
| DELETE | `/api/thresholds?deviceId=xxx` | reset to the system defaults |

---

## ESP32 — example POST /api/sensor/data

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
    "...": "..."
  }
}
```

---

## Project structure
```
src/main/java/com/sleepsense/
├── SleepSenseApplication.java
├── alert/
│   ├── AlertDispatcher.java         ← sendAlert() interface (Test Plan ITC-01, STC-05)
│   ├── AlertNotification.java
│   └── FcmAlertDispatcher.java      ← one notification per critical factor
├── analysis/
│   ├── ThresholdAnalyzer.java       ← threshold-based analysis, produces Alert rows
│   ├── ThresholdChecker.java        ← checkThreshold() (Test Plan UTC-02)
│   ├── ThresholdResult.java
│   ├── FactorResult.java
│   ├── ReportHelper.java            ← calculateDailyAverage() (Test Plan UTC-03)
│   ├── DailyReport.java
│   ├── EnvironmentClusterer.java    ← within-night quality label
│   ├── PatternAnalyzer.java         ← k-means across nights (Test Plan STC-04)
│   ├── PatternAnalysisResult.java
│   └── MorningReportGenerator.java
├── config/
│   ├── FirebaseConfig.java
│   ├── CorsConfig.java
│   └── ThresholdConfig.java         ← tunable in application.properties
├── controller/
│   ├── SensorController.java
│   ├── MorningReportController.java
│   ├── SmartSuggestionController.java
│   ├── AlertController.java
│   ├── ThresholdController.java
│   └── GlobalExceptionHandler.java
├── dto/
│   ├── SensorDataRequest.java
│   └── ApiResponse.java
├── model/
│   ├── SensorData.java
│   ├── Alert.java
│   ├── MorningReport.java
│   └── ThresholdSettings.java
├── pipeline/
│   └── SensorPipeline.java          ← getSensorData → checkThreshold → sendAlert (ITC-01)
├── repository/
│   ├── SensorDataRepository.java
│   ├── AlertRepository.java
│   └── ThresholdSettingsRepository.java
└── service/
    ├── SensorService.java           ← getSensorData() (Test Plan UTC-01)
    ├── MorningReportService.java
    ├── SmartSuggestionService.java
    ├── ThresholdSettingsService.java
    └── DataCleanupService.java
```

---

## Tests

```
mvn test
```

| Test class | Test Plan case |
|------------|----------------|
| `service/SensorServiceTest` | UTC-01 getSensorData |
| `analysis/ThresholdCheckerTest` | UTC-02 checkThreshold |
| `analysis/ReportHelperTest` | UTC-03 calculateDailyAverage |
| `pipeline/SensorPipelineTest` | ITC-01 sensor pipeline, plus STC-05 TC-03 |
| `analysis/PatternAnalyzerTest` | STC-04 clustering and smart suggestions |

The matching client-side suite lives in the Flutter project under `test/`.

---

## Firestore collections
| Collection | Description |
|------------|-------------|
| `sensor_data` | raw sensor readings, every 30-60 seconds |
| `alerts` | alerts raised by threshold analysis |
| `morning_reports` | per-night summaries |
| `threshold_settings` | per-device custom thresholds |

---

## Default thresholds (tunable in application.properties)
| Factor | Warning | Critical |
|--------|---------|----------|
| CO₂ | 1000 ppm | 2000 ppm |
| Temperature | outside 18-26 °C | outside 15-32 °C |
| Humidity | outside 30-60 % | outside 20-70 % |
| PM2.5 | 35 µg/m³ | 75 µg/m³ |
| Light | 50 lux | 200 lux |
| Noise | 40 dB | 60 dB |
