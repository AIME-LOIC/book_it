import bcrypt   from 'bcrypt';
import jwt      from 'jsonwebtoken';
import User     from '../database/models/user.js';
import Operator from '../database/models/operator.js';
import { decryptPassword } from '../utils/crypto.utils.js';

// ── LOCKOUT STORE ─────────────────────────────────────────────────
const MAX_ATTEMPTS = 5;
const LOCKOUT_MS   = 15 * 60 * 1000;
const LOCKER_MAX   = 3;
const LOCKER_MS    = 10 * 60 * 1000;
const failedAttempts = new Map();

const checkLockout = (key) => {
  const record = failedAttempts.get(key);
  if (!record) return;
  if (record.lockedUntil && Date.now() < record.lockedUntil) {
    const mins = Math.ceil((record.lockedUntil - Date.now()) / 60000);
    throw new Error(`Locked. Try again in ${mins} minute${mins > 1 ? 's' : ''}.`);
  }
  if (record.lockedUntil && Date.now() >= record.lockedUntil) {
    failedAttempts.delete(key);
  }
};

const recordFailure = (key, max = MAX_ATTEMPTS, lockMs = LOCKOUT_MS) => {
  const record = failedAttempts.get(key) || { count: 0 };
  record.count += 1;
  if (record.count >= max) {
    record.lockedUntil = Date.now() + lockMs;
    record.count = 0;
  }
  failedAttempts.set(key, record);
  return record;
};

const clearFailures = (key) => failedAttempts.delete(key);

export { checkLockout, recordFailure, clearFailures, MAX_ATTEMPTS, failedAttempts };

// ── REGISTER ──────────────────────────────────────────────────────
export const register = async ({ name, email, phone, password }) => {
  if (await User.findOne({ where: { email } })) throw new Error('Email already in use');
  const password_hash = await bcrypt.hash(password, 10);
  const user = await User.create({ name, email, phone, password_hash });
  return { id: user.id, name: user.name, email: user.email };
};

// ── LOGIN ─────────────────────────────────────────────────────────
export const loginUser = async ({ email, password }) => {
  checkLockout(email);
  const user = await User.findOne({ where: { email } });
  if (!user || !await bcrypt.compare(password, user.password_hash)) {
    const record = recordFailure(email);
    const remaining = MAX_ATTEMPTS - (record?.count || 0);
    throw new Error(remaining > 0
      ? `Invalid credentials. ${remaining} attempt${remaining > 1 ? 's' : ''} remaining.`
      : 'Account locked for 15 minutes.');
  }
  clearFailures(email);
  const token = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
};

export const loginOperator = async ({ company_name, password }) => {
  checkLockout(company_name);
  const operator = await Operator.findOne({ where: { company_name } });
  if (!operator || !await bcrypt.compare(password, operator.password_hash)) {
    const record = recordFailure(company_name);
    const remaining = MAX_ATTEMPTS - (record?.count || 0);
    throw new Error(remaining > 0
      ? `Invalid credentials. ${remaining} attempt${remaining > 1 ? 's' : ''} remaining.`
      : 'Account locked for 15 minutes.');
  }
  if (!operator.is_active) throw new Error('Account suspended');
  clearFailures(company_name);
  const token = jwt.sign(
    { id: operator.id, company_name: operator.company_name, role: 'operator' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return { token, operator: { id: operator.id, company_name: operator.company_name } };
};

// ── VERIFY PASSWORD (locker — 3 attempts, 10 min lock) ────────────
export const verifyPassword = async (user, password) => {
  if (!password) throw new Error('Password required');
  const lockKey = `locker:${user.id}`;
  checkLockout(lockKey);
  let valid = false;
  if (user.role === 'operator') {
    const op = await Operator.findByPk(user.id);
    valid = !!(op && await bcrypt.compare(password, op.password_hash));
  } else {
    const u = await User.findByPk(user.id);
    valid = !!(u && await bcrypt.compare(password, u.password_hash));
  }
  if (!valid) {
    const record = recordFailure(lockKey, LOCKER_MAX, LOCKER_MS);
    const remaining = LOCKER_MAX - (record?.count || 0);
    if (remaining <= 0) throw new Error('Locker locked for 10 minutes after 3 failed attempts.');
    throw new Error(`Incorrect password. ${remaining} attempt${remaining !== 1 ? 's' : ''} remaining before locker locks.`);
  }
  clearFailures(lockKey);
  return { verified: true };
};

// ── GET ME ────────────────────────────────────────────────────────
export const getMe = async (user) => {
  if (user.role === 'operator') {
    const op = await Operator.findByPk(user.id, {
      attributes: ['id', 'company_name', 'contact', 'is_active', 'createdAt'],
    });
    if (!op) throw new Error('Not found');
    return { role: 'operator', ...op.toJSON() };
  }
  const u = await User.findByPk(user.id, {
    attributes: ['id', 'name', 'email', 'phone', 'role', 'createdAt'],
  });
  if (!u) throw new Error('Not found');
  return { role: u.role, ...u.toJSON() };
};

// ── UPDATE ME ─────────────────────────────────────────────────────
export const updateMe = async (user, { name, phone, old_password, new_password }) => {
  if (user.role === 'operator') {
    const op = await Operator.findByPk(user.id);
    if (!op) throw new Error('Not found');
    if (new_password) {
      if (!old_password) throw new Error('Old password required');
      if (!await bcrypt.compare(old_password, op.password_hash)) throw new Error('Old password incorrect');
      await op.update({ password_hash: await bcrypt.hash(new_password, 10), default_password: null });
    }
    if (name !== undefined) await op.update({ company_name: name });
    if (phone !== undefined) await op.update({ contact: phone });
    return getMe(user);
  }
  const u = await User.findByPk(user.id);
  if (!u) throw new Error('Not found');
  if (new_password) {
    if (!old_password) throw new Error('Old password required');
    if (!await bcrypt.compare(old_password, u.password_hash)) throw new Error('Old password incorrect');
    await u.update({ password_hash: await bcrypt.hash(new_password, 10) });
  }
  if (name !== undefined) await u.update({ name });
  if (phone !== undefined) await u.update({ phone });
  return getMe(user);
};

// ── LOCKER ────────────────────────────────────────────────────────
export const getLocker = async (user, password) => {
  await verifyPassword(user, password);

  if (user.role === 'operator') {
    const Driver = (await import('../database/models/driver.js')).default;
    const Bus    = (await import('../database/models/bus.js')).default;
    const drivers = await Driver.findAll({
      where: { operator_id: user.id },
      attributes: ['id', 'name', 'phone', 'bus_id', 'default_password', 'must_update_profile'],
      include: [{ model: Bus, as: 'bus', attributes: ['plate_number'] }],
    });
    return drivers.map(d => ({
      id:               d.id,
      name:             d.name,
      phone:            d.phone,
      plate:            d.bus?.plate_number || null,
      default_password: decryptPassword(d.default_password),
      changed_password: !d.must_update_profile,
    }));
  }

  if (user.role === 'admin') {
    const operators = await Operator.findAll({
      attributes: ['id', 'company_name', 'contact', 'default_password', 'is_active'],
    });
    return operators.map(o => ({
      id:               o.id,
      company_name:     o.company_name,
      contact:          o.contact,
      default_password: decryptPassword(o.default_password),
      changed_password: !o.default_password,
    }));
  }

  throw new Error('Not authorized');
};
