import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const controller = fs.readFileSync(path.join(root, 'src/controllers/bus.controller.js'), 'utf8');

test('driver bus ownership compares UUIDs without numeric coercion', () => {
  assert.match(controller, /String\(req\.user\.bus_id\) !== String\(id\)/);
  assert.doesNotMatch(controller, /Number\(req\.user\.bus_id\)/);
});
