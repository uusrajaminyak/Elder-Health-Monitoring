#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// ==================== KONFIGURASI PIN ====================
#define PIN_POT_BPM       0   // pot1:SIG -> esp:0  (ADC1_CH0)
#define PIN_POT_SPO2      1   // pot2:SIG -> esp:1  (ADC1_CH1)
#define PIN_DS18B20       10  // temp1:DQ -> esp:10 (+ pull-up 4.7k ke 3V3)
#define PIN_BUZZER        3   // bz1:2    -> esp:3  (bz1:1 ke GND)
#define PIN_BTN_WORN      4   // btn1 -> esp:4, sisi lain ke GND (ditekan = LOW)
#define PIN_BTN_CHARGE    5   // btn2 -> esp:5, sisi lain ke GND (ditekan = LOW)
#define PIN_I2C_SDA       8   // imu1:SDA -> esp:8
#define PIN_I2C_SCL       9   // imu1:SCL -> esp:9

#define BUZZER_FREQ       2000
#define BTN_TOGGLE_MODE   1   // 1 = Toggle (tekan sekali ganti status)

// ==================== KONFIGURASI NETWORK & MQTT ====================
const char* WIFI_SSID = "Wokwi-GUEST";
const char* WIFI_PASS = "";

const char* MQTT_SERVER = "broker.hivemq.com";
const int   MQTT_PORT   = 1883;
const char* DEVICE_ID   = "BAND-001";

String TOPIC_TELEMETRY = "lansia/" + String(DEVICE_ID) + "/telemetry";
String TOPIC_EVENT     = "lansia/" + String(DEVICE_ID) + "/event";
String TOPIC_STATUS    = "lansia/" + String(DEVICE_ID) + "/status";

// ==================== OBJEK SENSOR & NETWORK ====================
WiFiClient espClient;
PubSubClient mqttClient(espClient);

Adafruit_MPU6050 mpu;
bool mpuReady = false;

// ==================== STATE & STRUCT ====================
struct Reading {
  int   bpm = 0, spo2 = 0, sigQual = 0, rawPot1 = 0, rawPot2 = 0;
  float temp = 0.0;
  bool  tempOk = false;
  bool  worn = true;
  bool  charging = false;
  float accelG = 1.0;
};

struct Button {
  uint8_t pin;
  bool lastRaw;
  bool pressed;
  unsigned long changedAt;
  explicit Button(uint8_t p) : pin(p), lastRaw(false), pressed(false), changedAt(0) {}
};
Button btnWorn(PIN_BTN_WORN);
Button btnCharge(PIN_BTN_CHARGE);
bool wornState = true, chargingState = false;

unsigned long lastTelemetryTime = 0;
unsigned long lastLivePrint     = 0;
unsigned long unwornStartTime   = 0;
unsigned long fallDetectTime    = 0;

uint32_t sequenceNumber = 1000;
int batteryLevel = 85;

// Suhu (non-blocking)
float lastTemp = 0.0;
bool  lastTempOk = false;
bool  tempRequested = false;
unsigned long lastTempRequestTime = 0;
unsigned long lastTempInitTry     = 0;
int   tempFailCount = 0;
const unsigned long TEMP_INTERVAL_MS = 2000;
const unsigned long TEMP_CONVERT_MS  = 1000;

// Deteksi Jatuh
bool isFallCandidate     = false;
float peakG              = 0.0;
int preBPM               = 75;
unsigned long stillSince = 0;
float lastAccelG         = 1.0;

// Buzzer
bool buzzerOn = false;
const unsigned long UNWORN_TIMEOUT_MS = 15000;

// State Trigger
bool forcePublish = true;
bool prevAnomaly = false, prevWorn = true, prevCharging = false;

// ==================== DEKLARASI FUNGSI ====================
void setupWiFi();
void reconnectMQTT();
bool updateButton(Button &b);
void readSensors(Reading &r);
void initTempSensor();
void checkFallDetection(const Reading &r);
void handleFindMyBand(bool worn, bool charging);
void setBuzzer(bool on);
void publishTelemetry(const Reading &r, bool isAnomaly);
void printLive(const Reading &r, bool isAnomaly);
void printFormattedDashboard(int seq, const Reading &r, bool isAnomaly, const char* jsonPayload);

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.print("\r\n--------------------------------------------------\r\n");
  Serial.print("[*] ZERO-INTERACTION SMARTBAND (ESP32-C3) INIT\r\n");
  Serial.print("--------------------------------------------------\r\n");

  pinMode(PIN_BTN_WORN, INPUT_PULLUP);
  pinMode(PIN_BTN_CHARGE, INPUT_PULLUP);

#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(PIN_BUZZER, BUZZER_FREQ, 8);
#else
  ledcSetup(0, BUZZER_FREQ, 8);
  ledcAttachPin(PIN_BUZZER, 0);
#endif
  setBuzzer(false);

  analogReadResolution(12);
  analogSetPinAttenuation(PIN_POT_BPM,  ADC_11db);
  analogSetPinAttenuation(PIN_POT_SPO2, ADC_11db);

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  if (!mpu.begin()) {
    Serial.print("[!] MPU6050 Tidak Terdeteksi!\r\n");
  } else {
    mpuReady = true;
    Serial.print("[*] MPU6050 Berhasil Ditemukan!\r\n");
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
  }

  initTempSensor();
  setupWiFi();
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
}

// ==================== LOOP ====================
void loop() {
  if (WiFi.status() != WL_CONNECTED) setupWiFi();
  if (!mqttClient.connected()) reconnectMQTT();
  mqttClient.loop();

  Reading r;
  readSensors(r);

  handleFindMyBand(r.worn, r.charging);
  checkFallDetection(r);

  bool isAnomaly = false;
  if (r.worn) {
    isAnomaly = (r.bpm < 60 || r.bpm > 100 || r.spo2 < 95);
    if (r.tempOk && (r.temp < 36.0 || r.temp > 37.5)) isAnomaly = true;
  }

  if (isAnomaly != prevAnomaly || r.worn != prevWorn || r.charging != prevCharging) {
    forcePublish = true;
    prevAnomaly = isAnomaly; prevWorn = r.worn; prevCharging = r.charging;
  }

  unsigned long now = millis();
  unsigned long currentInterval = isAnomaly ? 5000 : 10000;
  if (forcePublish || now - lastTelemetryTime >= currentInterval) {
    forcePublish = false;
    lastTelemetryTime = now;
    publishTelemetry(r, isAnomaly);
  }

  if (now - lastLivePrint >= 1000) {
    lastLivePrint = now;
    printLive(r, isAnomaly);
  }

  delay(50);
}

// ==================== NETWORK ====================
void setupWiFi() {
  delay(10);
  Serial.printf("[*] Menghubungkan WiFi: %s\r\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\r\n[*] WiFi Terhubung! IP: %s\r\n", WiFi.localIP().toString().c_str());
}

void reconnectMQTT() {
  while (!mqttClient.connected()) {
    if (WiFi.status() != WL_CONNECTED) setupWiFi();
    Serial.print("[*] Menghubungkan MQTT Broker...");
    if (mqttClient.connect(DEVICE_ID, TOPIC_STATUS.c_str(), 1, true, "offline")) {
      Serial.print(" Terhubung!\r\n");
      mqttClient.publish(TOPIC_STATUS.c_str(), "online", true);
    } else {
      Serial.printf(" Gagal, rc=%d. Coba lagi 3 detik...\r\n", mqttClient.state());
      delay(3000);
    }
  }
}

// ==================== DRIVER DS18B20 LOW-LEVEL ====================
static inline void owLow()     { digitalWrite(PIN_DS18B20, LOW); }
static inline void owRelease() { digitalWrite(PIN_DS18B20, HIGH); }
static inline int  owRead()    { return digitalRead(PIN_DS18B20); }

bool IRAM_ATTR owReset() {
  owRelease();
  uint8_t retries = 125;
  while (!owRead()) {
    if (--retries == 0) return false;
    delayMicroseconds(2);
  }
  noInterrupts();
  owLow();
  delayMicroseconds(480);
  owRelease();
  delayMicroseconds(70);
  bool presence = (owRead() == 0);
  interrupts();
  delayMicroseconds(410);
  return presence;
}

void IRAM_ATTR owWriteBit(bool b) {
  noInterrupts();
  owLow();
  if (b) { delayMicroseconds(6);  owRelease(); delayMicroseconds(64); }
  else   { delayMicroseconds(60); owRelease(); delayMicroseconds(10); }
  interrupts();
}

bool IRAM_ATTR owReadBit() {
  noInterrupts();
  owLow();
  delayMicroseconds(3);
  owRelease();
  delayMicroseconds(10);
  bool b = owRead();
  interrupts();
  delayMicroseconds(53);
  return b;
}

void IRAM_ATTR owWriteByte(uint8_t v) { for (int i = 0; i < 8; i++) { owWriteBit(v & 1); v >>= 1; } }
uint8_t IRAM_ATTR owReadByte() { uint8_t v = 0; for (int i = 0; i < 8; i++) { if (owReadBit()) v |= (1 << i); } return v; }

uint8_t owCrc8(const uint8_t *d, uint8_t len) {
  uint8_t crc = 0;
  while (len--) {
    uint8_t in = *d++;
    for (uint8_t i = 8; i; i--) {
      uint8_t mix = (crc ^ in) & 1;
      crc >>= 1;
      if (mix) crc ^= 0x8C;
      in >>= 1;
    }
  }
  return crc;
}

uint8_t dsRom[8];
bool dsHaveRom       = false;
bool dsUseMatchStart = false;
bool dsUseMatchRead  = false;
bool dsCalibrated    = false;

void dsSelect(bool match) {
  if (match && dsHaveRom) {
    owWriteByte(0x55);
    for (int i = 0; i < 8; i++) owWriteByte(dsRom[i]);
  } else {
    owWriteByte(0xCC);
  }
}

bool dsStartConversion() {
  if (!owReset()) return false;
  dsSelect(dsUseMatchStart);
  owWriteByte(0x44);
  return true;
}

int dsReadScratch(uint8_t sp[9], bool match) {
  if (!owReset()) return 1;
  dsSelect(match);
  owWriteByte(0xBE);
  for (int i = 0; i < 9; i++) sp[i] = owReadByte();
  return (owCrc8(sp, 8) == sp[8]) ? 0 : 2;
}

bool dsReadTemperature(float &t) {
  uint8_t sp[9] = {0};
  int rc = 1;
  for (int attempt = 0; attempt < 2; attempt++) {
    rc = dsReadScratch(sp, dsUseMatchRead);
    if (rc == 0) {
      int16_t raw = (int16_t)((sp[1] << 8) | sp[0]);
      t = raw / 16.0f;
      return true;
    }
  }
  return false;
}

void dsCalibrate() {
  dsCalibrated = true;
  for (int combo = 0; combo < 4; combo++) {
    bool mStart = (combo & 1);
    bool mRead  = (combo & 2);
    dsUseMatchStart = mStart;
    bool started = dsStartConversion();
    delay(800);
    uint8_t sp[9] = {0};
    int rc = started ? dsReadScratch(sp, mRead) : 1;
    if (rc == 0) {
      dsUseMatchStart = mStart;
      dsUseMatchRead  = mRead;
      float testT = (int16_t)((sp[1] << 8) | sp[0]) / 16.0f;
      Serial.printf("[*] DS18B20 Mode : Start=%s | Read=%s | Suhu Uji = %.2f C\r\n",
                    mStart ? "MATCH" : "SKIP", mRead ? "MATCH" : "SKIP", testT);
      lastTemp = testT;
      lastTempOk = true;
      tempFailCount = 0;
      lastTempRequestTime = millis();
      return;
    }
  }
  dsUseMatchStart = dsUseMatchRead = false;
  Serial.print("[!] DS18B20 Gagal membaca scratchpad\r\n");
}

void initTempSensor() {
  static bool firstReport = true; // Penanda agar log cetak sekali saja
  lastTempInitTry = millis();
  pinMode(PIN_DS18B20, OUTPUT_OPEN_DRAIN);
  owRelease();
  delay(20);

  bool found = false;
  uint8_t foundRom[8] = {0};
  for (int attempt = 1; attempt <= 5 && !found; attempt++) {
    bool presence = owReset();
    uint8_t rom[8] = {0};
    bool crcOk = false;
    if (presence && owReset()) {
      owWriteByte(0x33);
      for (int i = 0; i < 8; i++) rom[i] = owReadByte();
      crcOk = (owCrc8(rom, 7) == rom[7]);
    }
    found = crcOk && rom[0] == 0x28;
    if (found) memcpy(foundRom, rom, 8);
    if (!found) delay(100);
  }
  if (found) {
    memcpy(dsRom, foundRom, 8);
    dsHaveRom = true;
    if (!dsCalibrated) dsCalibrate();
    
    // Hanya cetak pesan jika baru pertama kali dipanggil saat startup
    if (firstReport) {
      Serial.print("[*] DS18B20 Berhasil Terdeteksi!\r\n");
      firstReport = false;
    }
  } else {
    if (firstReport) {
      Serial.print("[!] DS18B20 Tidak Terdeteksi di GPIO10!\r\n");
      firstReport = false;
    }
  }
}

// ==================== BACA SENSOR ====================
bool updateButton(Button &b) {
  bool raw = (digitalRead(b.pin) == LOW);
  unsigned long now = millis();
  if (raw != b.lastRaw) {
    b.lastRaw = raw;
    b.changedAt = now;
  }
  if (now - b.changedAt >= 30 && raw != b.pressed) {
    b.pressed = raw;
    return raw;
  }
  return false;
}

void readSensors(Reading &r) {
  long s1 = 0, s2 = 0;
  for (int i = 0; i < 8; i++) {
    s1 += analogRead(PIN_POT_BPM);
    s2 += analogRead(PIN_POT_SPO2);
  }
  r.rawPot1 = s1 / 8;
  r.rawPot2 = s2 / 8;
  r.bpm  = map(r.rawPot1, 0, 4095, 40, 180);
  r.spo2 = map(r.rawPot2, 0, 4095, 70, 100);

  unsigned long now = millis();
  if (!tempRequested && now - lastTempRequestTime >= TEMP_INTERVAL_MS) {
    if (!lastTempOk && tempFailCount >= 1 && now - lastTempInitTry >= 3000) {
      initTempSensor();
    }
    lastTempRequestTime = now;
    if (dsStartConversion()) {
      tempRequested = true;
    } else {
      lastTempOk = false;
      tempFailCount++;
    }
  } else if (tempRequested && now - lastTempRequestTime >= TEMP_CONVERT_MS) {
    float t = 0;
    if (!dsReadTemperature(t) || t < -55.0 || t > 125.0) {
      lastTempOk = false;
      tempFailCount++;
    } else {
      lastTemp = t;
      lastTempOk = true;
      tempFailCount = 0;
    }
    tempRequested = false;
  }
  r.temp   = lastTemp;
  r.tempOk = lastTempOk;

  bool wornPressed   = updateButton(btnWorn);
  bool chargePressed = updateButton(btnCharge);

#if BTN_TOGGLE_MODE
  if (wornPressed)   { wornState = !wornState;         Serial.printf("[*] [BTN] Gelang -> %s\r\n", wornState ? "DIPAKAI" : "DILEPAS"); }
  if (chargePressed) { chargingState = !chargingState; Serial.printf("[*] [BTN] Charger -> %s\r\n", chargingState ? "TERHUBUNG" : "TERLEPAS"); }
#else
  wornState     = btnWorn.pressed;
  chargingState = btnCharge.pressed;
#endif

  r.worn     = wornState;
  r.charging = chargingState;
  r.sigQual  = r.worn ? 3 : 0;
  r.accelG   = lastAccelG;

  // Zero Out Semua Parameter jika Gelang Dilepas
  if (!r.worn) {
    r.bpm    = 0;
    r.spo2   = 0;
    r.temp   = 0.0;
    r.tempOk = true;
  }
}

// ==================== DETEKSI JATUH ====================
void checkFallDetection(const Reading &r) {
  if (!mpuReady) return;

  sensors_event_t a, g, t;
  mpu.getEvent(&a, &g, &t);

  float accelG = sqrt(a.acceleration.x * a.acceleration.x +
                      a.acceleration.y * a.acceleration.y +
                      a.acceleration.z * a.acceleration.z) / 9.81;
  lastAccelG = accelG;

  if (fabs(accelG - 1.0) < 0.15) {
    if (stillSince == 0) stillSince = millis();
  } else {
    stillSince = 0;
  }

  if (accelG > 2.5 && !isFallCandidate) {
    isFallCandidate = true;
    peakG           = accelG;
    fallDetectTime  = millis();
    preBPM          = r.bpm;
    stillSince      = 0;
    Serial.printf("\r\n[!] KLIEN TERDETEKSI JATUH! Peak G: %.2f\r\n", peakG);
  }
  if (isFallCandidate && accelG > peakG) peakG = accelG;

  if (isFallCandidate && (millis() - fallDetectTime >= 3000)) {
    JsonDocument doc;
    doc["device_id"]        = DEVICE_ID;
    doc["seq"]              = sequenceNumber++;
    doc["ts"]               = millis() / 1000;
    doc["event"]            = "fall_candidate";
    doc["peak_g"]           = serialized(String(peakG, 2));
    doc["still_duration_s"] = (stillSince == 0) ? 0 : (int)((millis() - stillSince) / 1000);
    doc["pre_bpm"]          = preBPM;
    doc["post_bpm"]         = r.bpm;

    char buffer[256];
    serializeJson(doc, buffer);
    mqttClient.publish(TOPIC_EVENT.c_str(), buffer);

    isFallCandidate = false;
  }
}

// ==================== AKTUATOR ====================
void setBuzzer(bool on) {
  if (on == buzzerOn) return;
  buzzerOn = on;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWriteTone(PIN_BUZZER, on ? BUZZER_FREQ : 0);
#else
  ledcWriteTone(0, on ? BUZZER_FREQ : 0);
#endif
}

void handleFindMyBand(bool worn, bool charging) {
  if (charging || worn) {
    unwornStartTime = 0;
    setBuzzer(false);
    return;
  }
  if (unwornStartTime == 0) {
    unwornStartTime = millis();
  } else if (millis() - unwornStartTime >= UNWORN_TIMEOUT_MS) {
    setBuzzer((millis() / 500) % 2 == 0);
  }
}

// ==================== OUTPUT LOG ====================
void publishTelemetry(const Reading &r, bool isAnomaly) {
  JsonDocument doc;
  doc["device_id"]      = DEVICE_ID;
  doc["seq"]            = sequenceNumber;
  doc["ts"]             = millis() / 1000;
  doc["bpm"]            = r.bpm;
  doc["spo2"]           = r.spo2;
  if (r.tempOk) doc["temp"] = serialized(String(r.temp, 1));
  else          doc["temp"] = nullptr;
  doc["temp_ok"]        = r.tempOk;
  doc["signal_quality"] = r.sigQual;
  doc["battery"]        = batteryLevel;
  doc["charging"]       = r.charging;
  doc["worn"]           = r.worn;

  char buffer[300];
  serializeJson(doc, buffer);
  mqttClient.publish(TOPIC_TELEMETRY.c_str(), buffer);

  printFormattedDashboard(sequenceNumber, r, isAnomaly, buffer);
  sequenceNumber++;
}

void printLive(const Reading &r, bool isAnomaly) {
  char tbuf[16];
  if (r.tempOk) snprintf(tbuf, sizeof(tbuf), "%.1f C", r.temp);
  else          snprintf(tbuf, sizeof(tbuf), "ERROR");

  Serial.printf("[*] [LIVE] BPM:%3d | SpO2:%3d%% | Suhu:%s | G:%.2f | Gelang:%s | Daya:%s %s\r\n",
                r.bpm, r.spo2, tbuf, r.accelG,
                r.worn ? "Dipakai" : "Dilepas",
                r.charging ? "Charging" : "Baterai",
                isAnomaly ? "| [BAHAYA]" : "");
}

void printFormattedDashboard(int seq, const Reading &r, bool isAnomaly, const char* jsonPayload) {
  Serial.print("\r\n--------------------------------------------------\r\n");
  Serial.printf("[*] TELEMETRI SMARTBAND #%d | Status: %s\r\n", seq, isAnomaly ? "BAHAYA" : "NORMAL");
  Serial.printf("[*] BPM            : %d bpm\r\n", r.bpm);
  Serial.printf("[*] SpO2           : %d %%\r\n", r.spo2);
  if (r.tempOk) Serial.printf("[*] Suhu Tubuh     : %.1f C\r\n", r.temp);
  else          Serial.print("[*] Suhu Tubuh     : SENSOR ERROR\r\n");
  Serial.printf("[*] Status Gelang  : %s\r\n", r.worn ? "Dipakai" : "Dilepas");
  if (r.charging) Serial.print("[*] Status Daya    : Charging\r\n");
  else            Serial.printf("[*] Status Daya    : Baterai %d%%\r\n", batteryLevel);
  Serial.printf("[*] Kualitas Sinyal: %d/3\r\n", r.sigQual);
  Serial.print("--------------------------------------------------\r\n");
}