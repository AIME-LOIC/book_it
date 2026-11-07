import { Router } from 'express';
import authenticateRfidDevice from '../middleware/rfid-device-auth.js';
import { scanFromReader } from '../controllers/rfid-card.controller.js';

const router = Router();
router.post('/scan', authenticateRfidDevice, scanFromReader);
export default router;
