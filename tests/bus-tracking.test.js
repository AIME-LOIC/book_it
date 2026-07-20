import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const routesPath = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'routes', 'bus.routes.js');
const routesSource = fs.readFileSync(routesPath, 'utf8');

test('bus routes expose a dedicated location update endpoint for live tracking', () => {
  assert.match(routesSource, /router\.patch\('\/:id\/location'/);
});
test('bus location updates require the driver middleware before permission checks', () => {
  assert.match(routesSource, /isDriver/);
  assert.match(routesSource, /router\.patch\('\\/:id\\/location'.*authenticate.*isDriver/s);
});
