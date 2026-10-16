import { Request, Response } from 'express';
import { acknowledgeAlert } from '../services/alert.engine';

// POST /alerts/:id/ack - Konfirmasi alarm oleh keluarga
export const handleAcknowledgeAlert = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { handledBy, isFalseAlarm } = req.body;

    if (!handledBy) {
      return res.status(400).json({ message: 'Nama penangan (handledBy) wajib diisi' });
    }

    const updatedAlert = await acknowledgeAlert(
      id,
      handledBy,
      Boolean(isFalseAlarm)
    );

    return res.json({
      message: 'Alarm berhasil dikonfirmasi dan eskalasi dihentikan',
      data: updatedAlert,
    });
  } catch (error) {
    return res.status(500).json({ message: 'Gagal mengonfirmasi alarm', error });
  }
};