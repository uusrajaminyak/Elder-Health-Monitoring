import mqtt from 'mqtt';
import prisma from '../config/prisma';
import { processTelemetryAlerts, processFallEvent } from './alert.engine';
import { broadcastWebSocket } from './websocket.service';

const brokerUrl = process.env.MQTT_BROKER_URL || 'mqtt://broker.hivemq.com:1883';
const targetDeviceId = process.env.DEVICE_ID || 'BAND-001';

export const initMqttWorker = () => {
  const client = mqtt.connect(brokerUrl);

  client.on('connect', () => {
    console.log(`📡 [MQTT WORKER] Terhubung ke Broker: ${brokerUrl}`);

    const topics = [
      `lansia/${targetDeviceId}/telemetry`,
      `lansia/${targetDeviceId}/event`,
      `lansia/${targetDeviceId}/status`,
    ];

    client.subscribe(topics, (err) => {
      if (!err) {
        console.log(`📥 Subscribed ke topik: ${topics.join(', ')}`);
      }
    });
  });

  client.on('message', async (topic, message) => {
    const payloadStr = message.toString();

    try {
      // 1. Handling Telemetri Rutin
      if (topic.endsWith('/telemetry')) {
        const data = JSON.parse(payloadStr);

        // Update status device di DB
        await prisma.device.upsert({
          where: { deviceId: data.device_id },
          update: {
            isOnline: true,
            isWorn: data.worn ?? true,
            isCharging: data.charging ?? false,
            batteryLevel: data.battery ?? 100,
            lastSeenAt: new Date(),
          },
          create: {
            deviceId: data.device_id,
            isOnline: true,
            isWorn: data.worn ?? true,
            isCharging: data.charging ?? false,
            batteryLevel: data.battery ?? 100,
            lastSeenAt: new Date(),
          },
        });

        // Simpan log telemetri ke DB
        await prisma.vitalTelemetry.create({
          data: {
            deviceId: data.device_id,
            bpm: data.bpm ?? 0,
            spo2: data.spo2 ?? 0,
            temp: data.temp != null ? parseFloat(data.temp) : null,
            signalQuality: data.signal_quality ?? 0,
          },
        });

        // Oper ke Alert Engine untuk analisis
        await processTelemetryAlerts(data);

        // Broadcast ke Mobile App via WebSocket
        broadcastWebSocket({
          type: 'TELEMETRY_UPDATE',
          data,
        });
      }

      // 2. Handling Event Kandidat Jatuh
      else if (topic.endsWith('/event')) {
        const data = JSON.parse(payloadStr);

        if (data.event === 'fall_candidate') {
          await processFallEvent(data);
          broadcastWebSocket({
            type: 'FALL_EVENT',
            data,
          });
        }
      }

      // 3. Handling Status Device (Last Will / Online / Offline)
      else if (topic.endsWith('/status')) {
        const isOnline = payloadStr.trim() === 'online';

        await prisma.device.updateMany({
          where: { deviceId: targetDeviceId },
          data: {
            isOnline,
            lastSeenAt: new Date(),
          },
        });

        broadcastWebSocket({
          type: 'DEVICE_STATUS',
          deviceId: targetDeviceId,
          isOnline,
        });
      }
    } catch (err) {
      console.error(`❌ [MQTT ERROR] Gagal memproses pesan topik ${topic}:`, err);
    }
  });

  client.on('error', (err) => {
    console.error('❌ [MQTT CLIENT ERROR]:', err);
  });
};