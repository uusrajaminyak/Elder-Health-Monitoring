import prisma from '../config/prisma';
import { sendTelegramAlert } from './telegram.service';
import { AlertType, AlertStatus } from '@prisma/client';

// Map untuk menyimpan active timeout timer per alertId
const activeAlertTimers = new Map<string, NodeJS.Timeout>();

// Durasi timer eskalasi (3 menit sesuai SRS, bisa disesuaikan via ENV)
const ESCALATION_TIMEOUT_MS = process.env.ESCALATION_TIMEOUT_MS 
  ? parseInt(process.env.ESCALATION_TIMEOUT_MS, 10) 
  : 3 * 60 * 1000;

export interface TelemetryData {
  device_id: string;
  bpm: number;
  spo2: number;
  temp?: number | null;
  signal_quality: number;
  battery: number;
  charging: boolean;
  worn: boolean;
}

export interface FallCandidateEvent {
  device_id: string;
  event: string;
  peak_g: number;
  still_duration_s: number;
  pre_bpm: number;
  post_bpm: number;
}

/**
 * Memproses data telemetri rutin dari MQTT
 */
export const processTelemetryAlerts = async (data: TelemetryData) => {
  // 1. Hard Safety Rule: Abaikan data jika kualitas sinyal < 2
  if (data.signal_quality < 2) {
    return;
  }

  // 2. Ambil data device & threshold lansia dari DB
  const device = await prisma.device.findUnique({
    where: { deviceId: data.device_id },
    include: {
      elder: {
        include: { thresholdConfig: true },
      },
    },
  });

  if (!device || !device.elder) return;

  const threshold = device.elder.thresholdConfig;
  const minSpo2 = threshold?.minSpo2 ?? 95;
  const minBpm = threshold?.minBpm ?? 60;
  const maxBpm = threshold?.maxBpm ?? 100;
  const maxTemp = threshold?.maxTemp ?? 37.5;

  // 3. Deteksi Anomali SpO2 (Penurunan Oksigen)
  if (data.spo2 < minSpo2 && data.worn) {
    await createAlertAndScheduleEscalation({
      deviceId: device.deviceId,
      elderId: device.elder.id,
      type: AlertType.SPO2_DROP,
      title: 'Indikasi Penurunan SpO2',
      description: `Saturasi oksigen ${device.elder.name} terdeteksi ${data.spo2}% (Batas aman: ${minSpo2}%).`,
    });
  }

  // 4. Deteksi Anomali BPM (Detak Jantung Abnormal)
  if ((data.bpm < minBpm || data.bpm > maxBpm) && data.worn && data.bpm > 0) {
    await createAlertAndScheduleEscalation({
      deviceId: device.deviceId,
      elderId: device.elder.id,
      type: AlertType.BPM_ABNORMAL,
      title: 'Indikasi Detak Jantung Abnormal',
      description: `Detak jantung ${device.elder.name} terdeteksi ${data.bpm} BPM (Rentang normal: ${minBpm}-${maxBpm} BPM).`,
    });
  }

  // 5. Deteksi Suhu Tubuh Tinggi
  if (data.temp && data.temp > maxTemp && data.worn) {
    await createAlertAndScheduleEscalation({
      deviceId: device.deviceId,
      elderId: device.elder.id,
      type: AlertType.TEMP_ABNORMAL,
      title: 'Indikasi Suhu Tubuh Tinggi',
      description: `Suhu kulit ${device.elder.name} terdeteksi ${data.temp.toFixed(1)}°C (Batas normal: ${maxTemp}°C).`,
    });
  }
};

/**
 * Memproses event kandidat jatuh dari MPU6050
 */
export const processFallEvent = async (eventData: FallCandidateEvent) => {
  const device = await prisma.device.findUnique({
    where: { deviceId: eventData.device_id },
    include: { elder: true },
  });

  if (!device || !device.elder) return;

  // Validasi: Peak G > 2.5g dan durasi diam >= 3 detik
  if (eventData.peak_g >= 2.5) {
    await createAlertAndScheduleEscalation({
      deviceId: device.deviceId,
      elderId: device.elder.id,
      type: AlertType.FALL_CANDIDATE,
      title: 'Kemungkinan Insiden Jatuh!',
      description: `Lonjakan g-force (${eventData.peak_g}g) terdeteksi pada ${device.elder.name}. Lansia tampak tidak bergerak selama ${eventData.still_duration_s} detik.`,
      peakG: eventData.peak_g,
      stillDurationS: eventData.still_duration_s,
      preBpm: eventData.pre_bpm,
      postBpm: eventData.post_bpm,
    });
  }
};

/**
 * Helper: Buat record AlertEvent & Pasang Timer Eskalasi Telegram
 */

interface CreateAlertInput {
  deviceId: string;
  elderId: string;
  type: AlertType;
  title: string;
  description: string;
  peakG?: number;
  stillDurationS?: number;
  preBpm?: number;
  postBpm?: number;
}

const createAlertAndScheduleEscalation = async (input: CreateAlertInput) => {
  // Cegah spam: Cek apakah sudah ada alert sejenis yang berstatus PENDING dalam 2 menit terakhir
  const recentPending = await prisma.alertEvent.findFirst({
    where: {
      deviceId: input.deviceId,
      type: input.type,
      status: AlertStatus.PENDING,
      createdAt: { gte: new Date(Date.now() - 2 * 60 * 1000) },
    },
  });

  if (recentPending) return;

  // Simpan Alert Baru ke DB
  const alert = await prisma.alertEvent.create({
    data: {
      deviceId: input.deviceId,
      elderId: input.elderId,
      type: input.type,
      status: AlertStatus.PENDING,
      title: input.title,
      description: input.description,
      peakG: input.peakG,
      stillDurationS: input.stillDurationS,
      preBpm: input.preBpm,
      postBpm: input.postBpm,
    },
  });

  console.log(`🚨 [ALERT CREATED] ID: ${alert.id} | ${input.title}`);

  // Pasang Timer Eskalasi 3 Menit
  const timer = setTimeout(async () => {
    await executeTelegramEscalation(alert.id);
  }, ESCALATION_TIMEOUT_MS);

  activeAlertTimers.set(alert.id, timer);
};

/**
 * Eksekusi Eskalasi Telegram jika tidak di-ACK dalam batas waktu
 */
const executeTelegramEscalation = async (alertId: string) => {
  const alert = await prisma.alertEvent.findUnique({
    where: { id: alertId },
    include: {
      elder: {
        include: { emergencyContacts: true },
      },
    },
  });

  if (!alert || alert.status !== AlertStatus.PENDING) {
    activeAlertTimers.delete(alertId);
    return;
  }

  // Update status alert di DB ke ESCALATED_TELEGRAM
  await prisma.alertEvent.update({
    where: { id: alertId },
    data: {
      status: AlertStatus.ESCALATED_TELEGRAM,
      escalatedAt: new Date(),
    },
  });

  // Susun Pesan Eskalasi Telegram
  const message = `🚨 *[ESKALASI DARURAT - ZERO-BAND]* 🚨\n\n` +
    `*Jenis Kejadian:* ${alert.title}\n` +
    `*Lansia:* ${alert.elder?.name || 'Oma Mary'}\n` +
    `*Waktu:* ${alert.createdAt.toLocaleString('id-ID')}\n\n` +
    `*Rincian:* ${alert.description}\n\n` +
    `⚠️ _Tidak ada konfirmasi dari anggota keluarga dalam ${Math.round(ESCALATION_TIMEOUT_MS / 60000)} menit. Mohon bantuan kontak darurat terdekat untuk mengecek keadaan!_`;

  // Kirim ke Telegram Group
  await sendTelegramAlert(message);

  activeAlertTimers.delete(alertId);
};

/**
 * Dipanggil oleh Controller ketika keluarga klik "Saya Tangani" / "Alarm Palsu"
 */
export const acknowledgeAlert = async (
  alertId: string,
  handledBy: string,
  isFalseAlarm: Boolean
) => {
  // Hapus timer eskalasi yang sedang berjalan di memory
  if (activeAlertTimers.has(alertId)) {
    clearTimeout(activeAlertTimers.get(alertId));
    activeAlertTimers.delete(alertId);
  }

  const status = isFalseAlarm
    ? AlertStatus.ACKNOWLEDGED_FALSE_ALARM
    : AlertStatus.ACKNOWLEDGED_HANDLED;

  const updatedAlert = await prisma.alertEvent.update({
    where: { id: alertId },
    data: {
      status,
      handledBy,
      handledAt: new Date(),
    },
  });

  console.log(`✅ [ALERT ACKNOWLEDGED] ID: ${alertId} | Handled By: ${handledBy} | Status: ${status}`);
  return updatedAlert;
};