/*
 * SleepSense - ESP32 Sensor Node
 * ---------------------------------------------------
 * Reads all six sensors and posts them to the Spring Boot backend
 * over HTTP POST every 30 seconds.
 *
 * Sensors:
 *  - DHT22    : Temperature + Humidity   (Digital, 1-wire)
 *  - BH1750   : Light intensity (lux)    (I2C)
 *  - KY-037   : Sound/Noise level        (Analog)
 *  - PIR      : Motion detection         (Digital)
 *  - PMS5003  : PM2.5                    (UART/Serial)
 *  - SCD41    : CO2                      (I2C)
 *
 * Libraries to install (Library Manager in the Arduino IDE):
 *  - DHT sensor library (Adafruit)
 *  - Adafruit Unified Sensor
 *  - BH1750 (claws/BH1750)
 *  - ArduinoJson (version 6.x)
 *  - MH-Z19 (by Jonathan Dempsey) -- or talk to it over Serial directly, as below
 *  - PMS Library (fu-hsi/PMS) -- or parse the frames yourself, as below
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <DHT.h>
#include <BH1750.h>
#include <SensirionI2cScd4x.h>
#include <HardwareSerial.h>


const char* WIFI_SSID     = "Latcharit";
const char* WIFI_PASSWORD = "itimLOOK2547";


const char* SERVER_URL = "http://192.168.1.2:8080/api/sensor/data";

const char* DEVICE_ID = "test-device-01";

// Posting interval in milliseconds (30s by default, per proposal 3.8 Performance)
const unsigned long SEND_INTERVAL_MS = 30000;

// ─────────────────────────────────────────────
// PIN CONFIG 
// ─────────────────────────────────────────────
#define DHT_PIN       4      // DHT22 data pin
#define DHT_TYPE      DHT22
#define PIR_PIN       27     // PIR motion sensor output
#define I2C_SDA_PIN   21     // I2C SDA (BH1750 + SCD41 via the breadboard)
#define I2C_SCL_PIN   22     // I2C SCL (BH1750 + SCD41 via the breadboard)
#define SOUND_PIN     34     // KY-037 analog output (ADC1 still works with Wi-Fi on)

// BH1750 uses standard I2C: SDA=21, SCL=22 (the ESP32 defaults)

// PMS5003 uses hardware serial (UART2); SCD41 uses I2C
#define PMS_RX_PIN    16     // ESP32 RX <- PMS5003 TX
#define PMS_TX_PIN    17     // ESP32 TX -> PMS5003 RX
// CO2 (SCD41) shares I2C with the BH1750 — SDA=GPIO21, SCL=GPIO22, no separate pins needed

// ─────────────────────────────────────────────
// OBJECTS
// ─────────────────────────────────────────────
DHT dht(DHT_PIN, DHT_TYPE);
BH1750 lightMeter;

HardwareSerial pmsSerial(2);  // UART2, for the PMS5003
SensirionI2cScd4x scd4x;      // SCD41 (CO2) over I2C

unsigned long lastSendTime = 0;
float lastValidPm25 = 0;  // last PM2.5 value that read cleanly
float lastValidCo2 = 0;   // last CO2 value that read cleanly (SCD41)

// ─────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("=== SleepSense ESP32 Starting ===");

  // PIR
  pinMode(PIR_PIN, INPUT);

  // DHT22
  dht.begin();

  // BH1750 (I2C)
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  if (!lightMeter.begin()) {
    Serial.println("[WARN] BH1750 not found! Check the I2C wiring");
  }

  // PMS5003 (UART2)
  pmsSerial.begin(9600, SERIAL_8N1, PMS_RX_PIN, PMS_TX_PIN);

  // SCD41 (CO2 via I2C)
  // SCD41 (CO2) over I2C
  scd4x.begin(Wire, SCD41_I2C_ADDR_62);
  scd4x.wakeUp();
  scd4x.stopPeriodicMeasurement();   // stop first, in case it is still running from before
  scd4x.startPeriodicMeasurement();  // start continuous measurement (a new value every ~5s)

  connectWiFi();
}

// ─────────────────────────────────────────────
void loop() {
  // Reconnect Wi-Fi if it dropped
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  unsigned long now = millis();
  if (now - lastSendTime >= SEND_INTERVAL_MS) {
    lastSendTime = now;
    collectAndSendData();
  }

  delay(100);
}

// ─────────────────────────────────────────────
void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("WiFi connected. IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println();
    Serial.println("[ERROR] WiFi connection failed, will retry in loop()");
  }
}

// ─────────────────────────────────────────────
void collectAndSendData() {
  // ── DHT22: Temperature + Humidity ──
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("[WARN] DHT22 read failed, sending -1 (app will show N/A)");
    temperature = -1;
    humidity = -1;
  }

  // ── BH1750: Light intensity ──
  float lux = lightMeter.readLightLevel();
  if (lux < 0) lux = 0;

  // ── KY-037: Noise level (analog -> approximate dB) ──
  float noiseLevel = readNoiseLevel();

  // ── PIR: Motion ──
  bool motionDetected = digitalRead(PIR_PIN) == HIGH;

  // ── PMS5003: PM2.5 ──
  float pm25 = readPM25();
  // If this round failed to read (-1), fall back to the last good value
  if (pm25 < 0) {
    pm25 = lastValidPm25;
  } else {
    lastValidPm25 = pm25; // keep this good value for next time
  }

  // ── SCD41: CO2 ──
  float co2 = readCO2();
  // The SCD41 updates every ~5s; if it is not ready yet, reuse the last value
  if (co2 < 0) {
    co2 = lastValidCo2;
  } else {
    lastValidCo2 = co2;
  }

  // Debug print
  Serial.println("──────── Sensor Readings ────────");
  Serial.printf("Temp: %.1f C | Humidity: %.1f %%\n", temperature, humidity);
  Serial.printf("Light: %.1f lux | Noise: %.1f dB\n", lux, noiseLevel);
  Serial.printf("Motion: %s | PM2.5: %.1f ug/m3 | CO2: %.1f ppm\n",
                motionDetected ? "YES" : "NO", pm25, co2);

  sendToServer(temperature, humidity, co2, pm25, lux, noiseLevel, motionDetected);
}

// ─────────────────────────────────────────────
// KY-037: read the sound level and convert it to an approximate dB figure.
//
//
// What was wrong with the previous approach:
//  1) A single analogRead() samples an AC waveform swinging around ~Vcc/2 at
//     one instant, so the number is close to random and says little about
//     how loud the room actually is.
//  2) dB is a log scale against sound pressure, but the old map() was a plain
//     linear conversion from ADC counts to dB, with no physical basis behind
//     it, so the result was inaccurate.
//
//
// What this does instead:
//  1) Take many samples over a short window and estimate amplitude from
//     (max - min) / 2 of the ADC readings, rather than a single read.
//  2) Convert amplitude to dB with a log formula: dB = A*log10(amplitude) + B,
//     where A and B come from two calibration points measured in the room
//     against a sound level meter or a phone dB app.
//  3) Smooth across rounds with an EMA, so the value does not jump around as
//     sound changes quickly.
//
// *** Calibrate before relying on these readings ***
// Steps: 1) Measure in a quiet room and note the amplitude (printed over
//           Serial). Pair it with the real dB from the meter or app and put
//           both into NOISE_CAL_*_LOW.
//        2) Make some noise (talking, quiet music), measure again, and put the
//           pair into NOISE_CAL_*_HIGH.
//        The further apart the two calibration points are (30dB vs 70dB, say),
//        the more accurate the range between them. Outside it, the figure is
//        extrapolated and less trustworthy.
// ─────────────────────────────────────────────
const int   NOISE_SAMPLE_COUNT   = 200;   // samples per measurement
const float NOISE_CAL_DB_LOW     = 30.0f; // real dB measured when quiet (calibrate this)
const float NOISE_CAL_AMP_LOW    = 15.0f; // amplitude (ADC counts) measured when quiet
const float NOISE_CAL_DB_HIGH    = 70.0f; // real dB measured when noisy (calibrate this)
const float NOISE_CAL_AMP_HIGH   = 300.0f;// amplitude (ADC counts) measured when noisy
const float NOISE_EMA_ALPHA      = 0.3f;  // weight of the newest sample in the EMA (0-1); lower is steadier but slower

float noiseEmaDb = -1.0f;  // EMA state across rounds (resets on every boot)

float readNoiseLevel() {
  // 1) Sample the mic's AC signal briefly, tracking min/max to estimate amplitude
  int minVal = 4095;
  int maxVal = 0;
  for (int i = 0; i < NOISE_SAMPLE_COUNT; i++) {
    int v = analogRead(SOUND_PIN);
    if (v < minVal) minVal = v;
    if (v > maxVal) maxVal = v;
    delayMicroseconds(100); // spaced so the window spans several cycles of speech-range audio
  }
  float amplitude = (maxVal - minVal) / 2.0f;
  if (amplitude < 1.0f) amplitude = 1.0f; // guards against log10(0) and negatives

  // 2) Amplitude to dB, using the two-point log calibration
  //    dB = A * log10(amplitude) + B
  static const float logLow  = log10(NOISE_CAL_AMP_LOW);
  static const float logHigh = log10(NOISE_CAL_AMP_HIGH);
  static const float calA = (NOISE_CAL_DB_HIGH - NOISE_CAL_DB_LOW) / (logHigh - logLow);
  static const float calB = NOISE_CAL_DB_LOW - calA * logLow;

  float db = calA * log10(amplitude) + calB;

  // Clamp to what this microphone can plausibly report
  if (db < 25.0f) db = 25.0f;
  if (db > 100.0f) db = 100.0f;

  // 3) EMA smoothing across rounds, so a brief sound does not spike the reading
  if (noiseEmaDb < 0) {
    noiseEmaDb = db; // the first value after boot is used as-is
  } else {
    noiseEmaDb = NOISE_EMA_ALPHA * db + (1.0f - NOISE_EMA_ALPHA) * noiseEmaDb;
  }

  return noiseEmaDb;
}

// ─────────────────────────────────────────────
// PMS5003: read PM2.5 over UART.
// Protocol: 0x42 0x4D, followed by a 32-byte frame.
// PM2.5 (atmospheric) sits at byte offset 12-13.
// ─────────────────────────────────────────────
float readPM25() {
  // At least one full frame (32 bytes) has to be buffered
  if (pmsSerial.available() < 32) {
    return -1; // not enough new data
  }

  // Find the 0x42 0x4D start sequence before reading a whole frame
  while (pmsSerial.available() >= 32) {
    // the first byte has to be 0x42
    if (pmsSerial.peek() != 0x42) {
      pmsSerial.read(); // discard anything that is not a start byte
      continue;
    }

    uint8_t buffer[32];
    pmsSerial.readBytes(buffer, 32);

    // confirm both header bytes
    if (buffer[0] != 0x42 || buffer[1] != 0x4D) {
      continue; // incomplete header, try the next frame
    }

    // ── Checksum ── (bytes 0-29 must sum to the value in bytes 30-31)
    uint16_t checksum = 0;
    for (int i = 0; i < 30; i++) {
      checksum += buffer[i];
    }
    uint16_t frameChecksum = (buffer[30] << 8) | buffer[31];
    if (checksum != frameChecksum) {
      continue; // corrupt frame, not trustworthy, try the next one
    }

    // PM2.5 atmospheric environment value: byte 12-13 (high, low)
    uint16_t pm25 = (buffer[12] << 8) | buffer[13];

    // Sanity check — indoor PM2.5 does not exceed ~1000 µg/m³
    if (pm25 > 1000) {
      return -1; // implausible value, discard it
    }

    return (float) pm25;
  }
  return -1;
}

// ─────────────────────────────────────────────
// SCD41: read CO2 over I2C
// Command: FF 01 86 00 00 00 00 00 79
// Response: FF 86 [CO2_HIGH] [CO2_LOW] ... [checksum]
// ─────────────────────────────────────────────
float readCO2() {
  uint16_t co2 = 0;
  float temp = 0.0f, humidity = 0.0f;
  bool isDataReady = false;

  // Is a new measurement ready?
  int16_t error = scd4x.getDataReadyStatus(isDataReady);
  if (error || !isDataReady) {
    return -1;  // nothing new yet (the SCD41 updates every ~5s)
  }

  error = scd4x.readMeasurement(co2, temp, humidity);
  if (error || co2 == 0) {
    Serial.println("[WARN] SCD41 read failed");
    return -1;
  }

  return (float) co2;
}

// ─────────────────────────────────────────────
// Post the readings to the Spring Boot backend over HTTP
// ─────────────────────────────────────────────
void sendToServer(float temperature, float humidity, float co2,
                   float pm25, float lux, float noiseLevel, bool motionDetected) {

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] WiFi not connected, skipping send");
    return;
  }

  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);

  // Build the JSON payload
  StaticJsonDocument<256> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["co2"] = (co2 < 0) ? 0 : co2;         // send 0 when unreadable; the app shows N/A
  doc["pm25"] = pm25;                       // fallback already handled in collectAndSendData
  doc["lightIntensity"] = lux;
  doc["noiseLevel"] = noiseLevel;
  doc["motionDetected"] = motionDetected;

  String jsonPayload;
  serializeJson(doc, jsonPayload);

  Serial.println("Sending: " + jsonPayload);

  int httpResponseCode = http.POST(jsonPayload);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.printf("[HTTP %d] %s\n", httpResponseCode, response.c_str());
  } else {
    Serial.printf("[ERROR] POST failed: %s\n", http.errorToString(httpResponseCode).c_str());
  }

  http.end();
}