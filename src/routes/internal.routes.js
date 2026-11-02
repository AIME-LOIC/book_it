import { Router } from 'express';
import { timingSafeEqual } from 'node:crypto';
import Notification from '../database/models/notification.js';
import PromoCode from '../database/models/promo_code.js';
import sequelize from '../config/sequelize.js';
import {
  checkDepartedBuses,
  checkPendingTicketHolds,
  notifyUpcomingDepartures,
  archiveOldTickets,
  checkPromoCodeGeneration,
  cleanupOldNotifications,
  checkMidnightReactivation,
} from '../services/scheduler.service.js';

const router = Router();
let schedulerSchemaReady = false;

// Production databases may predate these Sequelize models. Create only missing
// tables (never alter or drop existing production data) before scheduled jobs
// query them. Cache the successful check for the lifetime of this function.
const ensureSchedulerTables = async () => {
  if (schedulerSchemaReady) return;
  await Notification.sync();
  await PromoCode.sync();
  // The deployed notifications table uses a PostgreSQL ENUM even though the
  // current Sequelize model declares STRING. Extend it for newly introduced
  // scheduler notification types without rebuilding or replacing the enum.
  await sequelize.query(
    "ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'trip_departure_reminder'",
  );
  await sequelize.query(
    "ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'promo_code_generated'",
  );
  schedulerSchemaReady = true;
};

const safeSecretMatch = (provided, expected) => {
  if (!provided || !expected) return false;
  const left = Buffer.from(provided);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
};

// Called by a trusted scheduler (e.g. GitHub Actions) every five minutes.
// Exposes frequent and daily maintenance jobs. Manual operator disables are
// protected by a separate database flag before midnight reactivation runs.
router.post('/run', async (req, res) => {
  const expected = process.env.CRON_SECRET;
  const authorization = req.get('authorization') || '';
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';

  if (!safeSecretMatch(token, expected)) {
    return res.status(401).json({ message: 'Unauthorized scheduler request' });
  }

  try {
    await ensureSchedulerTables();
  } catch (error) {
    console.error('[Cron] Scheduler database setup failed:', error?.stack || error);
    return res.status(500).json({ message: 'Scheduler database setup failed' });
  }

  const results = [];
  const jobs = [
    ['departed-buses', checkDepartedBuses],
    ['pending-ticket-holds', checkPendingTicketHolds],
    ['upcoming-departure-reminders', notifyUpcomingDepartures],
    ['ticket-archive', archiveOldTickets],
    ['daily-loyalty-promo', checkPromoCodeGeneration],
    ['notification-retention', cleanupOldNotifications],
    ['midnight-bus-reactivation', checkMidnightReactivation],
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
