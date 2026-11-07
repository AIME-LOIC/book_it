import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const cronRoute = fs.readFileSync(path.join(root, 'src/routes/internal.routes.js'), 'utf8');
const workflow = fs.readFileSync(path.join(root, '.github/workflows/bookit-scheduler.yml'), 'utf8');
const migrationRunner = fs.readFileSync(path.join(root, 'scripts/migrate.js'), 'utf8');

test('scheduler endpoint requires a constant-time checked bearer secret', () => {
  assert.match(cronRoute, /timingSafeEqual/);
  assert.match(cronRoute, /process\.env\.CRON_SECRET/);
  assert.match(cronRoute, /status\(401\)/);
});

test('only retry-safe frequent jobs are exposed to the scheduled endpoint', () => {
  assert.match(cronRoute, /checkDepartedBuses/);
  assert.match(cronRoute, /checkPendingTicketHolds/);
  assert.match(cronRoute, /notifyUpcomingDepartures/);
  assert.match(cronRoute, /archiveOldTickets/);
  assert.match(cronRoute, /checkPromoCodeGeneration/);
  assert.match(cronRoute, /cleanupOldNotifications/);
  assert.match(cronRoute, /checkMidnightReactivation/);
});

test('scheduled workflow uses repository secrets and checks HTTP failures', () => {
  assert.match(workflow, /BOOKIT_API_URL/);
  assert.match(workflow, /BOOKIT_CRON_SECRET/);
  assert.match(workflow, /curl --fail-with-body/);
});

test('migration runner tracks applied files and refuses non-Postgres databases', () => {
  assert.match(migrationRunner, /bookit_schema_migrations/);
  assert.match(migrationRunner, /applied/);
  assert.match(migrationRunner, /getDialect\(\) !== 'postgres'/);
});

import { getRwandaDateKey, getRwandaTimeParts } from '../src/utils/rwanda-time.util.js';

test('scheduler date and time calculations use Rwanda local time', () => {
  const afterRwandaMidnight = new Date('2026-10-31T22:30:00.000Z');
  assert.equal(getRwandaDateKey(afterRwandaMidnight), '2026-11-01');
  assert.deepEqual(getRwandaTimeParts(afterRwandaMidnight), { hour: 0, minute: 30 });
});


test('notification and loyalty-promo tables are provisioned for production', () => {
  const migration = fs.readFileSync(
    path.join(root, 'src/database/migrations/20261102_create_scheduler_tables.sql'),
    'utf8',
  );
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.notifications/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.promo_codes/);
  assert.match(migration, /recipient_id UUID NOT NULL/);
  assert.match(migration, /metadata JSON/);
  assert.match(migration, /CREATE INDEX IF NOT EXISTS/);
});


test('scheduler notification enum includes reminder and loyalty-promo values', () => {
  const migration = fs.readFileSync(
    path.join(root, 'src/database/migrations/20261102_add_scheduler_notification_types.sql'),
    'utf8',
  );
  assert.match(migration, /trip_departure_reminder/);
  assert.match(migration, /promo_code_generated/);
  assert.match(migration, /ADD VALUE IF NOT EXISTS/);
});
