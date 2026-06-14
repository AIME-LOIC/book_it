import sequelize from './src/config/db.js';
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

sequelize.authenticate()
.then(()=> sequelize.sync())
.then(async () => {
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
