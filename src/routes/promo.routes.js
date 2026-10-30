import express from 'express';
import authenticate from '../middleware/auth.js';
import isAdmin from '../middleware/admin.js';
import { generateDailyLoyaltyPromo } from '../services/promo.service.js';

const router = express.Router();

router.post('/generate', authenticate, isAdmin, async (req, res) => {
  try {
    const result = await generateDailyLoyaltyPromo(new Date());
    res.status(200).json({ ok: true, result });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

export default router;
