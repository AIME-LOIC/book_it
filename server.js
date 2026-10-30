import sequelize, { isLocal } from './src/config/sequelize.js';
import app from './src/app.js';
import os from 'node:os';
import { checkDepartedBuses, checkMidnightReactivation, checkPromoCodeGeneration, archiveOldTickets, checkPendingTicketHolds, notifyUpcomingDepartures, cleanupOldNotifications } from './src/services/scheduler.service.js';
import { seedDatabase } from './src/database/seed.js';

// ── GLOBAL ERROR HANDLERS ─────────────────────────────────────
process.on('uncaughtException', (err) => {
  console.error('[FATAL] Uncaught Exception:', err);
  console.error(err.stack);
  process.exit(1); // crash and let pm2 restart
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[ERROR] Unhandled Promise Rejection at:', promise);
  console.error('Reason:', reason);
  // don't crash — log and continue
});

process.on('SIGTERM', () => {
  console.log('[INFO] SIGTERM received, shutting down gracefully...');
  sequelize.close().then(() => {
    console.log('[INFO] Database connection closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[INFO] SIGINT received, shutting down gracefully...');
  sequelize.close().then(() => {
    console.log('[INFO] Database connection closed');
    process.exit(0);
  });
});

const ensureNotificationTypeColumn = async () => {
  if (!isLocal) return;
  try {
    await sequelize.query('ALTER TABLE notifications MODIFY COLUMN type VARCHAR(50) NOT NULL');
    console.log('[DB] notifications.type column normalized to VARCHAR(50)');
  } catch (err) {
    const msg = err?.message || '';
    if (!msg.includes('Unknown column') && !msg.includes('doesn\'t exist')) {
      console.warn('[DB] notification type column update skipped:', msg);
    }
  }
};

sequelize.authenticate()
.then(async ()=> {
  await ensureNotificationTypeColumn();
  // Apply schema changes automatically in local/dev environments so new columns/types
  // (such as promo-code notification types) are reflected in the local DB.
  return isLocal ? sequelize.sync({ alter: true }) : Promise.resolve();
})
.then(async () => {
  // Only seed automatically in local/dev environments to avoid schema mismatch on managed DBs
  if (!isLocal) return;
  if (process.env.SEED_ON_START === 'false') return;
  await seedDatabase();
})
.then(()=>{
    console.log('database connected');
    const PORT = process.env.PORT || 2000;
    const HOST = '0.0.0.0';
    app.listen(PORT, HOST, () => {
      const nets = os.networkInterfaces();
      let lanIP = 'localhost';
      for (const iface of Object.values(nets)) {
        for (const net of iface || []) {
          if (net.family === 'IPv4' && !net.internal) { lanIP = net.address; break; }
        }
      }
      console.log('BookIt running on:');
      console.log('  Local: http://localhost:' + PORT);
      console.log('  Network: http://' + lanIP + ':' + PORT);
      const runJobs = () => {
        checkDepartedBuses().catch(err => console.error('[Scheduler] departed buses:', err));
        checkMidnightReactivation().catch(err => console.error('[Scheduler] midnight reactivation:', err));
        checkPromoCodeGeneration().catch(err => console.error('[Scheduler] promo generation:', err));
        archiveOldTickets().catch(err => console.error('[Scheduler] ticket archive:', err));
        checkPendingTicketHolds().catch(err => console.error('[Scheduler] pending holds:', err));
        notifyUpcomingDepartures().catch(err => console.error('[Scheduler] departure reminders:', err));
        cleanupOldNotifications().catch(err => console.error('[Scheduler] notification cleanup:', err));
      };
      runJobs();
      setInterval(runJobs, 60 * 1000);
    });
})
.catch((error)=>{
    console.error("failed to connect ", error)
    process.exit(1)
})
