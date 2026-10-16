# Zero-Interaction Smartband: Elder Health Monitoring & Early Warning System

Sistem pemantauan kesehatan pasif (*zero-interaction*) berbasis IoT, Mobile App, dan Backend Alert Engine untuk deteksi dini anomali tanda vital lansia serta eskalasi darurat otomatis.

---

## Deskripsi Sistem

Sistem ini dirancang khusus untuk pemantauan lansia secara berkelanjutan tanpa menuntut interaksi aktif. Data telemetri mencakup denyut jantung (BPM), saturasi oksigen (SpO2), suhu kulit, dan percepatan (G-force dari akselerometer). Data dibaca oleh mikrokontroler ESP32-C3 pada gelang pintar, dikirim melalui protokol MQTT ke broker Cloud, diolah oleh Backend Alert Engine menggunakan aturan Hard Safety Guardrails, dan dipancarkan secara real-time ke Aplikasi Mobile Keluarga berbasis Flutter.

---

## Tech Stack dan Arsitektur

* **Firmware (IoT Node):** ESP32-C3 (C++ / Arduino Framework), PubSubClient MQTT, Adafruit MPU6050, DS18B20, MAX30100.
* **Backend Engine:** Node.js (TypeScript, Express.js), Prisma ORM, PostgreSQL (Docker Container), MQTT Client, WebSocket Server (`ws`), Node-Telegram-Bot-API / WhatsApp Integration.
* **Mobile App:** Flutter, Riverpod (State Management), WebSocket Channel, `fl_chart`, `http`, `flutter_secure_storage`.
* **Transport Protocol:** MQTT (QoS 1 via HiveMQ Broker Cloud) dan WebSocket (Server to Mobile).

---

## Instalasi Lokal
* #### Prasyarat
```powershell
Node.js (v18+)
Docker & Docker Desktop
Flutter SDK (v3.20+)
Git
```
* #### Konfigurasi Backend
```powershell
cd backend
npm install
docker compose up -d
```
* #### Environtment Variables
```text
PORT=3000
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/zero_band?schema=public"
MQTT_BROKER_URL="mqtt://broker.hivemq.com:1883"
DEVICE_ID="BAND-001"
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
```
* #### Run Migration & DB Seeding
```powershell
npx prisma migrate dev --name init
npx prisma db seed
```
* #### Run Server
```powershell
npm run dev
```
* #### Konfigurasi Mobile App
```powershell
cd ../mobile
flutter pub get
```
* #### Run Flutter (Pilih salah satu)
```powershell
- Chrome
flutter run -d chrome

- Windows
flutter run -d windows

- Android Emulator
flutter run
```