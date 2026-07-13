import crypto from 'crypto';

const ALGO    = 'aes-256-gcm';
// Deliberately a separate secret from JWT_SECRET/QR_SECRET: those are for
// auth tokens and QR tickets. Reusing them here meant a JWT_SECRET rotation
// (e.g. after a leak) would break decryption of every stored default
// password, and a leak of either secret would compromise BOTH auth tokens
// and stored passwords at once. Falls back to QR_SECRET only for existing
// deployments that haven't set DEFAULT_PW_SECRET yet — set it and rotate.
const SECRET  = process.env.DEFAULT_PW_SECRET || process.env.QR_SECRET || process.env.JWT_SECRET;
if (!SECRET) {
  throw new Error(
    'crypto.utils: none of DEFAULT_PW_SECRET, QR_SECRET, or JWT_SECRET are set. ' +
    'Check that your env file is actually being loaded (e.g. DOTENV_CONFIG_PATH for local dev).'
  );
}
if (!process.env.DEFAULT_PW_SECRET) {
  console.warn('[crypto.utils] DEFAULT_PW_SECRET not set — falling back to QR_SECRET/JWT_SECRET. Set DEFAULT_PW_SECRET explicitly.');
}
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