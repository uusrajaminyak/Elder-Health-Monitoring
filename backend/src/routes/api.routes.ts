import { Router } from 'express';
import {
  getElderVitals,
  getElderThresholds,
  updateElderThresholds,
  getElderEvents,
} from '../controllers/elder.controller';
import { handleAcknowledgeAlert } from '../controllers/alert.controller';

const router = Router();

// Routes Lansia & Telemetri
router.get('/elders/:id/vitals', getElderVitals);
router.get('/elders/:id/thresholds', getElderThresholds);
router.put('/elders/:id/thresholds', updateElderThresholds);
router.get('/elders/:id/events', getElderEvents);

// Routes Alarm & Ack
router.post('/alerts/:id/ack', handleAcknowledgeAlert);

export default router;