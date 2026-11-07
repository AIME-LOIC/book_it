export const normalizeRfidUid = (value) =>
  String(value ?? '').replace(/[^a-fA-F0-9]/g, '').toUpperCase();

export const isValidRfidUid = (uid) =>
  typeof uid === 'string' && uid.length >= 8 && uid.length <= 40 && uid.length % 2 === 0;
