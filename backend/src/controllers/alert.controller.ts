import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const acknowledgeAlert = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { handledBy, isFalseAlarm } = req.body;

    const status = isFalseAlarm ? 'ACKNOWLEDGED_FALSE_ALARM' : 'ACKNOWLEDGED_HANDLED';

    // Gunakan upsert agar ID alarm lokal/transient tidak memicu Error 500
    const alert = await prisma.alertEvent.upsert({
      where: { id },
      update: {
        status,
        handledBy: handledBy || 'Keluarga',
      },
      create: {
        id,
        deviceId: 'BAND-001',
        type: 'FALL_CANDIDATE',
        status,
        title: 'Kemungkinan Jatuh Terdeteksi!',
        description: 'Insiden jatuh dikonfirmasi melalui Mobile App',
        handledBy: handledBy || 'Keluarga',
      },
    });

    return res.status(200).json({
      success: true,
      data: alert,
    });
  } catch (error) {
    console.error('[ERROR ACK ALERT]:', error);
    return res.status(500).json({
      message: 'Gagal mengonfirmasi alarm',
      error: String(error),
    });
  }
};