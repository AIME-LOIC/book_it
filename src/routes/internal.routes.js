import { Router } from 'express';
import { timingSafeEqual } from 'node:crypto';
import {
  checkDepartedBuses,
  checkPendingTicketHolds,
  notifyUpcomingDepartures,
  archiveOldTickets,
  checkPromoCodeGeneration,
  cleanupOldNotifications,
} from '../services/scheduler.service.js';

const router = Router();

const safeSecretMatch = (provided, expected) => {
  if (!provided || !expected) return false;
  const left = Buffer.from(provided);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
};

// Called by a trusted scheduler (e.g. GitHub Actions) every five minutes.
// Exposes retry-safe frequent and daily maintenance jobs. The midnight
// reactivation job is excluded because it cannot distinguish manual disables.
router.post('/run', async (req, res) => {
  const expected = process.env.CRON_SECRET;
  const authorization = req.get('authorization') || '';
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';

  if (!safeSecretMatch(token, expected)) {
    return res.status(401).json({ message: 'Unauthorized scheduler request' });
  }

  const results = [];
  const jobs = [
    ['departed-buses', checkDepartedBuses],
    ['pending-ticket-holds', checkPendingTicketHolds],
    ['upcoming-departure-reminders', notifyUpcomingDepartures],
    ['ticket-archive', archiveOldTickets],
    ['daily-loyalty-promo', checkPromoCodeGeneration],
    ['notification-retention', cleanupOldNotifications],
  ];

  for (const [name, run] of jobs) {
    try {
      await run();
      results.push({ job: name, status: 'success' });
    } catch (error) {
      console.error(`[Cron] ${name} failed:`, error?.stack || error);
      results.push({ job: name, status: 'failed' });
    }
  }

  const failed = results.some((result) => result.status === 'failed');
  return res.status(failed ? 500 : 200).json({
    message: failed ? 'One or more scheduler jobs failed' : 'Scheduler jobs completed',
    results,
    executed_at: new Date().toISOString(),
  });
});

export default router;
