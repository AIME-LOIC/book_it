import crypto from 'crypto';

const ALGO    = 'aes-256-gcm';
const SECRET  = process.env.QR_SECRET || process.env.JWT_SECRET;
// derive a 32-byte key from the secret
const KEY     = crypto.createHash('sha256').update(SECRET).digest();

export const encryptPassword = (plain) => {
  if (!plain) return null;
  const iv         = crypto.randomBytes(12);
  const cipher     = crypto.createCipheriv(ALGO, KEY, iv);
  const encrypted  = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const authTag    = cipher.getAuthTag();
  // store as iv:authTag:encrypted — all hex
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted.toString('hex')}`;
};

export const decryptPassword = (stored) => {
  if (!stored) return null;
  // support plain-text passwords that were saved before encryption was added
  if (!stored.includes(':')) return stored;
  try {
    const [ivHex, tagHex, encHex] = stored.split(':');
    const iv         = Buffer.from(ivHex, 'hex');
    const authTag    = Buffer.from(tagHex, 'hex');
    const encrypted  = Buffer.from(encHex, 'hex');
    const decipher   = crypto.createDecipheriv(ALGO, KEY, iv);
    decipher.setAuthTag(authTag);
    return decipher.update(encrypted) + decipher.final('utf8');
  } catch {
    return null; // tampered or wrong key
  }
};
