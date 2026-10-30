import sequelize, { isLocal } from './src/config/sequelize.js';
import app from './src/app.js';
import {
  checkDepartedBuses,
  checkMidnightReactivation,
  checkPromoCodeGeneration,
  archiveOldTickets,
  checkPendingTicketHolds,
  notifyUpcomingDepartures,
  cleanupOldNotifications,
} from './src/services/scheduler.service.js';
import os from 'node:os';

process.on('uncaughtException', (err) => {
  console.error('[FATAL] Uncaught Exception:', err);
  console.error(err.stack);
  if (process.env.VERCEL !== '1') process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[ERROR] Unhandled Promise Rejection at:', promise);
  console.error('Reason:', reason);
});

process.on('SIGTERM', () => {
  sequelize.close().finally(() => process.exit(0));
});

process.on('SIGINT', () => {
  sequelize.close().finally(() => process.exit(0));
});

async function startLocalServer() {
  await sequelize.authenticate();

  if (isLocal && process.env.SEED_ON_START !== 'false') {
    await sequelize.sync({ alter: true });
    const { seedDatabase } = await import('./src/database/seed.js');
    await seedDatabase();
  }

  const port = process.env.PORT || 2000;
  app.listen(port, '0.0.0.0', () => {
    let lanIP = 'localhost';
    for (const iface of Object.values(os.networkInterfaces())) {
      for (const net of iface || []) {
        if (net.family === 'IPv4' && !net.internal) {
          lanIP = net.address;
          break;
        }
      }
    }
    console.log('BookIt running on:');
    console.log(`  Local:   http://localhost:${port}`);
    console.log(`  Network: http://${lanIP}:${port}`);

    const runSchedulers = () => {
      checkDepartedBuses();
      checkMidnightReactivation();
      checkPromoCodeGeneration();
      archiveOldTickets();
      checkPendingTicketHolds();
      notifyUpcomingDepartures();
      cleanupOldNotifications();
    };
    runSchedulers();
    setInterval(runSchedulers, 60 * 1000);
  });
}

// Vercel imports this file as an Express entrypoint and handles HTTP requests.
// Only run a persistent listener and interval schedulers in local/Render mode.
if (process.env.VERCEL !== '1') {
  startLocalServer().catch((error) => {
    console.error('[DB] Failed to start BookIt:', error);
    process.exit(1);
  });
}

export default app;
