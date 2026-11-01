import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const service = fs.readFileSync(path.join(root, 'src/services/notification.service.js'), 'utf8');
const controller = fs.readFileSync(path.join(root, 'src/controllers/notification.controller.js'), 'utf8');

test('notification mutations are scoped to recipient ID and role', () => {
  assert.match(service, /markAsRead = async \(recipient_id, recipient_type, id\)/);
  assert.match(service, /deleteNotification = async \(recipient_id, recipient_type, id\)/);
  assert.match(service, /where: \{ id, recipient_id, recipient_type \}/);
  assert.match(service, /where: \{ recipient_id, recipient_type, is_read: false \}/);
});

test('notification controllers pass the authenticated role to every mutation', () => {
  assert.match(controller, /svc\.markAsRead\(req\.user\.id, req\.user\.role, req\.params\.id\)/);
  assert.match(controller, /svc\.markAllAsRead\(req\.user\.id, req\.user\.role\)/);
  assert.match(controller, /svc\.deleteNotification\(req\.user\.id, req\.user\.role, req\.params\.id\)/);
});
