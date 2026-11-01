import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const model = fs.readFileSync(path.join(root, 'src/database/models/bus.js'), 'utf8');
const service = fs.readFileSync(path.join(root, 'src/services/bus.service.js'), 'utf8');
const scheduler = fs.readFileSync(path.join(root, 'src/services/scheduler.service.js'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'src/database/migrations/20261101_add_manual_bus_disable_flag.sql'), 'utf8');

test('operator bus updates cannot overwrite ownership or scheduler-only fields', () => {
  assert.match(service, /allowedFields = \['route_id', 'plate_number', 'driver_name', 'capacity', 'departure_time', 'amenities', 'is_active'\]/);
  assert.doesNotMatch(service, /allowedFields.*operator_id/s);
});

test('operator disables are distinguished from automatic daily departure', () => {
  assert.match(model, /is_manually_disabled/);
  assert.match(service, /updates\.is_manually_disabled = updates\.is_active === false/);
  assert.match(scheduler, /where: \{ is_active: false, is_manually_disabled: false \}/);
  assert.match(migration, /UPDATE public\.buses[\s\S]*WHERE is_active = FALSE/);
});
