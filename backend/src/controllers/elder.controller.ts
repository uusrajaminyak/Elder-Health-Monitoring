import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const getElderVitals = async (req: Request, res: Response) => {
  try {
    const { id } = req.params; // String ID (misal "1" atau UUID)

    const vitals = await prisma.vitalTelemetry.findMany({
      where: {
        device: {
          elderId: id,
        },
      },
      orderBy: { timestamp: 'desc' },
      take: 50,
    });

    return res.status(200).json({ success: true, data: vitals });
  } catch (error) {
    console.error('[ERROR GET VITALS]:', error);
    return res.status(500).json({ message: 'Gagal mengambil data vitals', error: String(error) });
  }
};

export const getElderThresholds = async (req: Request, res: Response) => {
  try {
    const { id } = req.params; // String ID

    // Pastikan data Elder ada di DB agar tidak melanggar Foreign Key Constraint
    const elder = await prisma.elder.upsert({
      where: { id },
      update: {},
      create: {
        id,
        name: 'Nenek',
        age: 75,
      },
    });

    const threshold = await prisma.thresholdConfig.upsert({
      where: { elderId: elder.id },
      update: {},
      create: {
        elderId: elder.id,
        minSpo2: 95,
        minBpm: 60,
        maxBpm: 100,
        maxTemp: 37.5,
      },
    });

    return res.status(200).json({ success: true, data: threshold });
  } catch (error) {
    console.error('[ERROR GET THRESHOLDS]:', error);
    return res.status(500).json({ message: 'Gagal mengambil data threshold', error: String(error) });
  }
};

export const updateElderThresholds = async (req: Request, res: Response) => {
  try {
    const { id } = req.params; // String ID
    const { minSpo2, minBpm, maxBpm, maxTemp } = req.body;

    // Pastikan record Elder tersedia
    const elder = await prisma.elder.upsert({
      where: { id },
      update: {},
      create: {
        id,
        name: 'Nenek',
        age: 75,
      },
    });

    const updated = await prisma.thresholdConfig.upsert({
      where: { elderId: elder.id },
      update: {
        minSpo2: Number(minSpo2),
        minBpm: Number(minBpm),
        maxBpm: Number(maxBpm),
        maxTemp: Number(maxTemp),
      },
      create: {
        elderId: elder.id,
        minSpo2: Number(minSpo2),
        minBpm: Number(minBpm),
        maxBpm: Number(maxBpm),
        maxTemp: Number(maxTemp),
      },
    });

    return res.status(200).json({ success: true, data: updated });
  } catch (error) {
    console.error('[ERROR UPDATE THRESHOLD]:', error);
    return res.status(500).json({ message: 'Gagal memperbarui threshold', error: String(error) });
  }
};

export const getElderEvents = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const events = await prisma.alertEvent.findMany({
      where: {
        OR: [
          { elderId: id },
          { device: { elderId: id } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return res.status(200).json({ success: true, data: events });
  } catch (error) {
    console.error('[ERROR GET EVENTS]:', error);
    return res.status(500).json({ message: 'Gagal mengambil data events', error: String(error) });
  }
};