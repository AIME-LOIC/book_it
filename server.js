import sequelize, { isLocal } from './src/config/sequelize.js';
import './src/app.js';
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
    // The app is started in src/app.js
    console.log('database connected');
})
.catch((error)=>{
    console.error("failed to connect ", error)
    process.exit(1)
})
