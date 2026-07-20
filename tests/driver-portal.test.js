import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const driverHtmlPath = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'frontend', 'driver.html');
const driverHtml = fs.readFileSync(driverHtmlPath, 'utf8');

test('driver login reveals the dashboard by switching its display style', () => {
  assert.match(driverHtml, /const showDashboardView = \(\) => \{/);
  assert.match(driverHtml, /dashboard\.style\.display = 'flex';/);
});
