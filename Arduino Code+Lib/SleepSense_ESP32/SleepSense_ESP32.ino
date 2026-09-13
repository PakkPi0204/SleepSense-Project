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
 *  - SCD41    : CO2                      (I2C)
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
#include <SensirionI2cScd4x.h>
#include <HardwareSerial.h>


const char* WIFI_SSID     = "Latcharit";
const char* WIFI_PASSWORD = "itimLOOK2547";


const char* SERVER_URL = "http://192.168.1.5:8080/api/sensor/data";

const char* DEVICE_ID = "test-device-01";

// ส่งข้อมูลทุกกี่มิลลิวินาที (default 30 วินาที ตาม proposal 3.8 Performance)
const unsigned long SEND_INTERVAL_MS = 30000;

// ─────────────────────────────────────────────
// PIN CONFIG 
// ─────────────────────────────────────────────
#define DHT_PIN       4      // DHT22 data pin
#define DHT_TYPE      DHT22
#define PIR_PIN       27     // PIR motion sensor output
#define I2C_SDA_PIN   21     // I2C SDA (BH1750 + SCD41 ผ่าน breadboard)
#define I2C_SCL_PIN   22     // I2C SCL (BH1750 + SCD41 ผ่าน breadboard)
#define SOUND_PIN     34     // KY-037 analog output (ADC1 ใช้ได้ตอน WiFi เปิดด้วย)

// BH1750 ใช้ I2C มาตรฐาน: SDA=21, SCL=22 (ESP32 default)

// PMS5003 ใช้ Hardware Serial (UART2), SCD41 ใช้ I2C
#define PMS_RX_PIN    16     // ESP32 RX <- PMS5003 TX
#define PMS_TX_PIN    17     // ESP32 TX -> PMS5003 RX
// CO2 (SCD41) ใช้ I2C ร่วมกับ BH1750 — SDA=GPIO21, SCL=GPIO22 (ไม่ต้องกำหนด pin แยก)

// ─────────────────────────────────────────────
// OBJECTS
// ─────────────────────────────────────────────
DHT dht(DHT_PIN, DHT_TYPE);
BH1750 lightMeter;

HardwareSerial pmsSerial(2);  // UART2 สำหรับ PMS5003
SensirionI2cScd4x scd4x;      // SCD41 (CO2) ผ่าน I2C

unsigned long lastSendTime = 0;
float lastValidPm25 = 0;  // เก็บค่า PM2.5 ล่าสุดที่อ่านได้ถูกต้อง
float lastValidCo2 = 0;   // เก็บค่า CO2 ล่าสุดที่อ่านได้ถูกต้อง (SCD41)

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
    Serial.println("[WARN] BH1750 not found! ตรวจสอบสาย I2C");
  }

  // PMS5003 (UART2)
  pmsSerial.begin(9600, SERIAL_8N1, PMS_RX_PIN, PMS_TX_PIN);

  // SCD41 (CO2 via I2C)
  // SCD41 (CO2) ผ่าน I2C
  scd4x.begin(Wire, SCD41_I2C_ADDR_62);
  scd4x.wakeUp();
  scd4x.stopPeriodicMeasurement();   // หยุดก่อน (เผื่อค้างจากรอบก่อน)
  scd4x.startPeriodicMeasurement();  // เริ่มวัดต่อเนื่อง (ได้ค่าใหม่ทุก ~5 วิ)

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
  // ถ้ารอบนี้อ่านไม่ได้ (-1) ใช้ค่าที่อ่านได้ล่าสุดแทน
  if (pm25 < 0) {
    pm25 = lastValidPm25;
  } else {
    lastValidPm25 = pm25; // เก็บค่าที่ดีไว้ใช้รอบหน้า
  }

  // ── SCD41: CO2 ──
  float co2 = readCO2();
  // SCD41 อัปเดตทุก ~5 วิ ถ้าจังหวะนี้ยังไม่พร้อม ใช้ค่าล่าสุดแทน
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
// KY-037: อ่านค่าระดับเสียงแล้วแปลงเป็น dB โดยประมาณ
//
// ปัญหาของวิธีเดิม:
//  1) analogRead() ครั้งเดียวอ่านแค่ 1 sample ของสัญญาณเสียงที่เป็น AC
//     waveform (แกว่งขึ้นลงรอบจุดกึ่งกลาง ~Vcc/2) ค่าที่ได้จึงแทบเป็น
//     สุ่ม ไม่ได้สะท้อน "ความดัง" ของเสียง ณ ขณะนั้นจริงๆ
//  2) หน่วย dB เป็น log scale เทียบกับความดันเสียง แต่ map() เดิม
//     เป็นการแปลงเชิงเส้น (linear) ตรงๆ จากค่า ADC ไป dB ซึ่งไม่มี
//     ความสัมพันธ์ทางฟิสิกส์รองรับ ทำให้ค่าไม่แม่นยำ
//
// วิธีใหม่:
//  1) สุ่มตัวอย่างสัญญาณหลายจุดในช่วงสั้นๆ แล้วหา amplitude โดยประมาณ
//     จาก (max - min) / 2 ของ ADC ในช่วงนั้น (แทนการอ่านค่าเดียว)
//  2) แปลง amplitude -> dB ด้วยสูตร log: dB = A*log10(amplitude) + B
//     โดย A, B คำนวณจาก "จุด calibration" 2 จุดที่วัดจริงหน้างาน
//     (เทียบกับเครื่องวัดระดับเสียง หรือแอปวัด dB บนมือถือ)
//  3) ทำ EMA smoothing ระหว่างรอบ กันค่ากระโดดเพราะเสียงเปลี่ยนเร็ว
//
// *** ต้อง Calibrate ก่อนใช้งานจริง ***
// ขั้นตอน: 1) วัดในห้องเงียบ จด amplitude ที่ได้ (พิมพ์ debug ผ่าน Serial)
//          เทียบกับค่า dB จริงจากแอป/เครื่องวัด -> ใส่ใน NOISE_CAL_*_LOW
//          2) เปิดเสียง (พูดคุย/เพลงเบาๆ) วัดซ้ำแล้วใส่ใน NOISE_CAL_*_HIGH
//          ยิ่งจุด calibration ห่างกันมาก (เช่น 30dB กับ 70dB) ยิ่งแม่นยำ
//          ในช่วงนั้น ค่านอกช่วงจะเป็นการประมาณนอกกรอบ (extrapolation)
// ─────────────────────────────────────────────
const int   NOISE_SAMPLE_COUNT   = 200;   // จำนวน sample ต่อการวัด 1 ครั้ง
const float NOISE_CAL_DB_LOW     = 30.0f; // dB จริงที่วัดได้ตอน "เงียบ" (ต้อง calibrate)
const float NOISE_CAL_AMP_LOW    = 15.0f; // amplitude (ADC counts) ที่วัดได้ตอนเงียบ
const float NOISE_CAL_DB_HIGH    = 70.0f; // dB จริงที่วัดได้ตอน "มีเสียง" (ต้อง calibrate)
const float NOISE_CAL_AMP_HIGH   = 300.0f;// amplitude (ADC counts) ที่วัดได้ตอนมีเสียง
const float NOISE_EMA_ALPHA      = 0.3f;  // น้ำหนักค่าล่าสุดใน EMA (0-1) ยิ่งน้อยยิ่งนิ่งขึ้นแต่ตอบสนองช้าลง

float noiseEmaDb = -1.0f;  // เก็บสถานะ EMA ข้ามรอบ (reset ทุกครั้งที่ ESP32 บูตใหม่)

float readNoiseLevel() {
  // 1) สุ่มตัวอย่างสัญญาณ AC จากไมค์ในช่วงสั้นๆ หา min/max เพื่อประมาณ amplitude
  int minVal = 4095;
  int maxVal = 0;
  for (int i = 0; i < NOISE_SAMPLE_COUNT; i++) {
    int v = analogRead(SOUND_PIN);
    if (v < minVal) minVal = v;
    if (v > maxVal) maxVal = v;
    delayMicroseconds(100); // เว้นจังหวะเล็กน้อยให้ครอบคลุมหลายไซเคิลของย่านเสียงพูด
  }
  float amplitude = (maxVal - minVal) / 2.0f;
  if (amplitude < 1.0f) amplitude = 1.0f; // กัน log10(0) และค่าติดลบ

  // 2) แปลง amplitude -> dB ด้วยสูตร log แบบ 2-point calibration
  //    dB = A * log10(amplitude) + B
  static const float logLow  = log10(NOISE_CAL_AMP_LOW);
  static const float logHigh = log10(NOISE_CAL_AMP_HIGH);
  static const float calA = (NOISE_CAL_DB_HIGH - NOISE_CAL_DB_LOW) / (logHigh - logLow);
  static const float calB = NOISE_CAL_DB_LOW - calA * logLow;

  float db = calA * log10(amplitude) + calB;

  // กันค่าหลุดขอบเขตที่เป็นไปได้จริงของไมค์รุ่นนี้
  if (db < 25.0f) db = 25.0f;
  if (db > 100.0f) db = 100.0f;

  // 3) EMA smoothing ข้ามรอบการวัด กันค่ากระโดดเพราะเสียงเปลี่ยนแปลงเร็วมาก
  if (noiseEmaDb < 0) {
    noiseEmaDb = db; // ค่าแรกหลัง boot ใช้ค่าที่วัดได้ตรงๆ
  } else {
    noiseEmaDb = NOISE_EMA_ALPHA * db + (1.0f - NOISE_EMA_ALPHA) * noiseEmaDb;
  }

  return noiseEmaDb;
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
// SCD41: อ่านค่า CO2 ผ่าน I2C
// Command: FF 01 86 00 00 00 00 00 79
// Response: FF 86 [CO2_HIGH] [CO2_LOW] ... [checksum]
// ─────────────────────────────────────────────
float readCO2() {
  uint16_t co2 = 0;
  float temp = 0.0f, humidity = 0.0f;
  bool isDataReady = false;

  // เช็คว่ามีข้อมูลใหม่พร้อมไหม
  int16_t error = scd4x.getDataReadyStatus(isDataReady);
  if (error || !isDataReady) {
    return -1;  // ยังไม่มีข้อมูลใหม่ (SCD41 อัปเดตทุก ~5 วิ)
  }

  error = scd4x.readMeasurement(co2, temp, humidity);
  if (error || co2 == 0) {
    Serial.println("[WARN] SCD41 read failed");
    return -1;
  }

  return (float) co2;
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
  doc["co2"] = (co2 < 0) ? 0 : co2;         // ส่ง 0 เมื่ออ่านไม่ได้ (แอปจะแสดง N/A)
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