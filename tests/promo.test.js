import test from 'node:test';
import assert from 'node:assert/strict';
import { buildPromoCodeValue } from '../src/services/promo.service.js';

test('buildPromoCodeValue creates a date-time based random code', () => {
  const code = buildPromoCodeValue(new Date('2026-07-16T15:45:00Z'));
  assert.match(code, /^BK-20260716-1545-[A-Z0-9]{6}$/);
});

test('buildPromoCodeValue is unique across calls', () => {
  const first = buildPromoCodeValue(new Date('2026-07-16T15:45:00Z'));
  const second = buildPromoCodeValue(new Date('2026-07-16T15:45:00Z'));
  assert.notEqual(first, second);
});
