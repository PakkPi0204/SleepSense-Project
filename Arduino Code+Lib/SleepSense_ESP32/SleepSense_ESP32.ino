/*
 * SleepSense - ESP32 Sensor Node
 * ---------------------------------------------------
 * อ่านค่าจาก 6 sensors แล้วส่งไปที่ Spring Boot backend
 * ผ่าน HTTP POST ทุก 30 วินาที 
 *
 * Sensors:
 *  - DHT22    : Temperature + Humidity   (Digital, 1-wire)
 *  - BH1750   : Light intensity (lux)    (I2C)
 *  - KY-037   : Sound/Noise level        (Analog)
 *  - PIR      : Motion detection         (Digital)
 *  - PMS5003  : PM2.5                    (UART/Serial)
 *  - MH-Z19C  : CO2                      (UART/Serial)
 *
 * ต้องติดตั้ง Library (Library Manager ใน Arduino IDE):
 *  - DHT sensor library (Adafruit)
 *  - Adafruit Unified Sensor
 *  - BH1750 (claws/BH1750)
 *  - ArduinoJson (เวอร์ชัน 6.x)
 *  - MH-Z19 (by Jonathan Dempsey) -- หรือสื่อสารตรงผ่าน Serial ตามด้านล่าง
 *  - PMS Library (fu-hsi/PMS) -- หรือ parse เองตามด้านล่าง
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <DHT.h>
#include <BH1750.h>
#include <HardwareSerial.h>


const char* WIFI_SSID     = "Latcharit";
const char* WIFI_PASSWORD = "itimLOOK2547";


const char* SERVER_URL = "http://192.168.1.2:8080/api/sensor/data";

const char* DEVICE_ID = "test-device-01";

// ส่งข้อมูลทุกกี่มิลลิวินาที (default 30 วินาที ตาม proposal 3.8 Performance)
const unsigned long SEND_INTERVAL_MS = 30000;

// ─────────────────────────────────────────────
// PIN CONFIG 
// ─────────────────────────────────────────────
#define DHT_PIN       4      // DHT22 data pin
#define DHT_TYPE      DHT22
#define PIR_PIN       27     // PIR motion sensor output
#define SOUND_PIN     34     // KY-037 analog output (ADC1 ใช้ได้ตอน WiFi เปิดด้วย)

// BH1750 ใช้ I2C มาตรฐาน: SDA=21, SCL=22 (ESP32 default)

// PMS5003 และ MH-Z19C ใช้ Hardware Serial (UART2, UART1)
#define PMS_RX_PIN    16     // ESP32 RX <- PMS5003 TX
#define PMS_TX_PIN    17     // ESP32 TX -> PMS5003 RX
#define CO2_RX_PIN    25     // ESP32 RX <- MH-Z19C TX
#define CO2_TX_PIN    26     // ESP32 TX -> MH-Z19C RX

// ─────────────────────────────────────────────
// OBJECTS
// ─────────────────────────────────────────────
DHT dht(DHT_PIN, DHT_TYPE);
BH1750 lightMeter;

HardwareSerial pmsSerial(2);  // UART2 สำหรับ PMS5003
HardwareSerial co2Serial(1);  // UART1 สำหรับ MH-Z19C

unsigned long lastSendTime = 0;
float lastValidPm25 = 0;  // เก็บค่า PM2.5 ล่าสุดที่อ่านได้ถูกต้อง

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
  Wire.begin();
  if (!lightMeter.begin()) {
    Serial.println("[WARN] BH1750 not found! ตรวจสอบสาย I2C");
  }

  // PMS5003 (UART2)
  pmsSerial.begin(9600, SERIAL_8N1, PMS_RX_PIN, PMS_TX_PIN);

  // MH-Z19C (UART1)
  co2Serial.begin(9600, SERIAL_8N1, CO2_RX_PIN, CO2_TX_PIN);

  connectWiFi();
}

// ─────────────────────────────────────────────
void loop() {
  // Reconnect WiFi ถ้าหลุด
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
    Serial.println("[WARN] DHT22 read failed, using fallback values");
    temperature = 25.0;
    humidity = 50.0;
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
  // ถ้ารอบนี้อ่านไม่ได้ (-1) ใช้ค่าที่อ่านได้ล่าสุดแทน
  if (pm25 < 0) {
    pm25 = lastValidPm25;
  } else {
    lastValidPm25 = pm25; // เก็บค่าที่ดีไว้ใช้รอบหน้า
  }

  // ── MH-Z19C: CO2 ──
  float co2 = readCO2();

  // Debug print
  Serial.println("──────── Sensor Readings ────────");
  Serial.printf("Temp: %.1f C | Humidity: %.1f %%\n", temperature, humidity);
  Serial.printf("Light: %.1f lux | Noise: %.1f dB\n", lux, noiseLevel);
  Serial.printf("Motion: %s | PM2.5: %.1f ug/m3 | CO2: %.1f ppm\n",
                motionDetected ? "YES" : "NO", pm25, co2);

  sendToServer(temperature, humidity, co2, pm25, lux, noiseLevel, motionDetected);
}

// ─────────────────────────────────────────────
// KY-037: อ่านค่า analog แล้วแปลงเป็นค่าประมาณ dB
// (KY-037 ไม่ได้ให้ค่า dB จริงตรงๆ การ map นี้เป็นค่าประมาณสำหรับ prototype)
// ─────────────────────────────────────────────
float readNoiseLevel() {
  int raw = analogRead(SOUND_PIN);   // 0–4095 บน ESP32 (12-bit ADC)
  // Map ค่า raw analog (0-4095) ไปเป็นช่วง dB โดยประมาณ (30-90 dB)
  float db = map(raw, 0, 4095, 30, 90);
  return db;
}

// ─────────────────────────────────────────────
// PMS5003: อ่าน PM2.5 ผ่าน UART
// Protocol: เริ่มด้วย 0x42 0x4D แล้วตามด้วย frame 32 bytes
// PM2.5 (atmospheric) อยู่ที่ byte offset 12-13
// ─────────────────────────────────────────────
float readPM25() {
  // ต้องมีข้อมูลอย่างน้อย 1 เฟรม (32 byte)
  if (pmsSerial.available() < 32) {
    return -1; // ไม่มีข้อมูลใหม่พอ
  }

  // หา start byte 0x42 ตามด้วย 0x4D ให้ครบก่อนอ่านทั้งเฟรม
  while (pmsSerial.available() >= 32) {
    // byte แรกต้องเป็น 0x42
    if (pmsSerial.peek() != 0x42) {
      pmsSerial.read(); // ทิ้ง byte ที่ไม่ใช่ start
      continue;
    }

    uint8_t buffer[32];
    pmsSerial.readBytes(buffer, 32);

    // ยืนยัน header ครบทั้ง 2 byte
    if (buffer[0] != 0x42 || buffer[1] != 0x4D) {
      continue; // header ไม่ครบ ลองเฟรมถัดไป
    }

    // ── ตรวจ checksum ── (ผลรวม byte 0-29 ต้องเท่ากับ byte 30-31)
    uint16_t checksum = 0;
    for (int i = 0; i < 30; i++) {
      checksum += buffer[i];
    }
    uint16_t frameChecksum = (buffer[30] << 8) | buffer[31];
    if (checksum != frameChecksum) {
      continue; // เฟรมเสีย ข้อมูลไม่น่าเชื่อถือ ลองเฟรมถัดไป
    }

    // PM2.5 atmospheric environment value: byte 12-13 (high, low)
    uint16_t pm25 = (buffer[12] << 8) | buffer[13];

    // กันค่าเพี้ยน — PM2.5 ในห้องปกติไม่เกิน ~1000 µg/m³
    if (pm25 > 1000) {
      return -1; // ค่าผิดปกติ ทิ้งไป
    }

    return (float) pm25;
  }
  return -1;
}

// ─────────────────────────────────────────────
// MH-Z19C: ขอค่า CO2 ผ่าน UART command
// Command: FF 01 86 00 00 00 00 00 79
// Response: FF 86 [CO2_HIGH] [CO2_LOW] ... [checksum]
// ─────────────────────────────────────────────
float readCO2() {
  byte cmd[9] = {0xFF, 0x01, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00, 0x79};
  co2Serial.write(cmd, 9);

  byte response[9];
  unsigned long startTime = millis();

  // รอ response อย่างมาก 1 วินาที
  while (co2Serial.available() < 9) {
    if (millis() - startTime > 1000) {
      Serial.println("[WARN] MH-Z19C timeout, no response");
      return -1;
    }
  }

  co2Serial.readBytes(response, 9);

  if (response[0] == 0xFF && response[1] == 0x86) {
    int co2 = (response[2] << 8) | response[3];
    return (float) co2;
  }

  return -1;
}

// ─────────────────────────────────────────────
// ส่งข้อมูลไปที่ Spring Boot backend ผ่าน HTTP POST
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

  // สร้าง JSON payload
  StaticJsonDocument<256> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["co2"] = (co2 < 0) ? 400 : co2;       // ค่า fallback ถ้าอ่านไม่ได้
  doc["pm25"] = pm25;                       // จัดการค่า fallback แล้วใน collectAndSendData
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