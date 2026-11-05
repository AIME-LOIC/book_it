import test from 'node:test';
import assert from 'node:assert/strict';
import { isValidRfidUid, normalizeRfidUid } from '../src/utils/rfid-uid.js';

test('normalizes separated card UIDs to uppercase hexadecimal', () => {
  assert.equal(normalizeRfidUid('04:a1 0b-ff'), '04A10BFF');
});

test('rejects empty, odd-length, and out-of-range UIDs', () => {
  assert.equal(isValidRfidUid(normalizeRfidUid('')), false);
  assert.equal(isValidRfidUid(normalizeRfidUid('ABC')), false);
  assert.equal(isValidRfidUid(normalizeRfidUid('12345678')), true);
  assert.equal(isValidRfidUid(normalizeRfidUid('1234567890ABCDEF1234567890')), true);
  assert.equal(isValidRfidUid(normalizeRfidUid('1234567890ABCDEF123456789012345678901234')), false);
});

test('normalization strips non-hex separators without changing hex data', () => {
  assert.equal(normalizeRfidUid('  04-00:AB cd  '), '0400ABCD');
});
