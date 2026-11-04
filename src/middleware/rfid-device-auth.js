import crypto from 'node:crypto';

const safeEqual = (left, right) => {
  if (!left || !right) return false;
  const a = Buffer.from(String(left));
  const b = Buffer.from(String(right));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};

export default function authenticateRfidDevice(req, res, next) {
  const expectedId = process.env.RFID_DEVICE_ID;
  const expectedToken = process.env.RFID_DEVICE_TOKEN;
  if (!expectedId || !expectedToken) {
    return res.status(503).json({ approved: false, message: 'RFID reader is not configured on the server.' });
  }
  if (!safeEqual(req.get('X-Device-Id'), expectedId) || !safeEqual(req.get('X-Device-Token'), expectedToken)) {
    return res.status(401).json({ approved: false, message: 'RFID reader authentication failed.' });
  }
  req.rfidDevice = { id: expectedId };
  next();
}
