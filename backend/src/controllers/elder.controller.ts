import { Request, Response } from 'express';
import prisma from '../config/prisma';

// GET /elders/:id/vitals - Mengambil riwayat telemetri terkini
export const getElderVitals = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit as string) || 50;

    const device = await prisma.device.findUnique({
      where: { elderId: id },
    });

    if (!device) {
      return res.status(404).json({ message: 'Perangkat lansia tidak ditemukan' });
    }

    const vitals = await prisma.vitalTelemetry.findMany({
      where: { deviceId: device.deviceId },
      orderBy: { timestamp: 'desc' },
      take: limit,
    });

    return res.json({
      deviceStatus: {
        isOnline: device.isOnline,
        isWorn: device.isWorn,
        isCharging: device.isCharging,
        batteryLevel: device.batteryLevel,
        lastSeenAt: device.lastSeenAt,
      },
      vitals: vitals.reverse(),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Gagal mengambil data vitals', error });
  }
};

// GET /elders/:id/thresholds - Ambil batas threshold lansia
export const getElderThresholds = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const threshold = await prisma.thresholdConfig.findUnique({
      where: { elderId: id },
    });

    if (!threshold) {
      return res.status(404).json({ message: 'Threshold tidak ditemukan' });
    }

    return res.json(threshold);
  } catch (error) {
    return res.status(500).json({ message: 'Gagal mengambil threshold', error });
  }
};

// PUT /elders/:id/thresholds - Update threshold dengan Hard Safety Guardrails
export const updateElderThresholds = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { minSpo2, minBpm, maxBpm, maxTemp, userId } = req.body;

    // Hard Safety Guardrails Validation (Aturan Kritis SRS)
    if (minSpo2 != null && minSpo2 < 88) {
      return res.status(400).json({
        message: 'Pelanggaran Guardrail: Batas bawah SpO2 tidak boleh di bawah 88%.',
      });
    }
    if (minBpm != null && minBpm < 40) {
      return res.status(400).json({
        message: 'Pelanggaran Guardrail: Batas bawah BPM tidak boleh di bawah 40 BPM.',
      });
    }
    if (maxBpm != null && maxBpm > 130) {
      return res.status(400).json({
        message: 'Pelanggaran Guardrail: Batas atas BPM tidak boleh di atas 130 BPM.',
      });
    }
    if (maxTemp != null && maxTemp > 38.0) {
      return res.status(400).json({
        message: 'Pelanggaran Guardrail: Batas atas suhu tidak boleh di atas 38.0°C.',
      });
    }

    const currentConfig = await prisma.thresholdConfig.findUnique({
      where: { elderId: id },
    });

    const updatedConfig = await prisma.thresholdConfig.update({
      where: { elderId: id },
      data: {
        minSpo2: minSpo2 ?? currentConfig?.minSpo2,
        minBpm: minBpm ?? currentConfig?.minBpm,
        maxBpm: maxBpm ?? currentConfig?.maxBpm,
        maxTemp: maxTemp ?? currentConfig?.maxTemp,
        isDefault: false,
      },
    });

    // Catat Audit Log Perubahan Threshold
    if (userId && currentConfig) {
      await prisma.thresholdAuditLog.create({
        data: {
          elderId: id,
          changedBy: userId,
          oldValues: currentConfig as any,
          newValues: updatedConfig as any,
        },
      });
    }

    return res.json({
      message: 'Threshold berhasil diperbarui',
      data: updatedConfig,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Gagal memperbarui threshold', error });
  }
};

// GET /elders/:id/events - Log Riwayat Kejadian & Alarm
export const getElderEvents = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const events = await prisma.alertEvent.findMany({
      where: { elderId: id },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return res.json(events);
  } catch (error) {
    return res.status(500).json({ message: 'Gagal mengambil riwayat event', error });
  }
};