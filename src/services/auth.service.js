import bcrypt   from 'bcrypt';
import jwt      from 'jsonwebtoken';
import User     from '../database/models/user.js';
import Operator from '../database/models/operator.js';

// ── LOCKOUT STORE (in-memory) ─────────────────────────────────────
const MAX_ATTEMPTS  = 5;
const LOCKOUT_MS    = 15 * 60 * 1000; // 15 minutes
const failedAttempts = new Map(); // key: email/company_name

const checkLockout = (key) => {
  const record = failedAttempts.get(key);
  if (!record) return;
  if (record.lockedUntil && Date.now() < record.lockedUntil) {
    const mins = Math.ceil((record.lockedUntil - Date.now()) / 60000);
    throw new Error(`Account locked. Try again in ${mins} minute${mins > 1 ? 's' : ''}.`);
  }
  if (record.lockedUntil && Date.now() >= record.lockedUntil) {
    failedAttempts.delete(key); // reset after lockout expires
  }
};

const recordFailure = (key) => {
  const record = failedAttempts.get(key) || { count: 0 };
  record.count += 1;
  if (record.count >= MAX_ATTEMPTS) {
    record.lockedUntil = Date.now() + LOCKOUT_MS;
    record.count = 0;
  }
  failedAttempts.set(key, record);
};

const clearFailures = (key) => failedAttempts.delete(key);

export { checkLockout, recordFailure, clearFailures, MAX_ATTEMPTS, failedAttempts };

export const register = async ({ name, email, phone, password }) => {
  if (await User.findOne({ where: { email } })) throw new Error('Email already in use');
  const password_hash = await bcrypt.hash(password, 10);
  const user = await User.create({ name, email, phone, password_hash });
  return { id: user.id, name: user.name, email: user.email };
};

export const loginUser = async ({ email, password }) => {
  checkLockout(email);
  const user = await User.findOne({ where: { email } });
  if (!user || !await bcrypt.compare(password, user.password_hash)) {
    recordFailure(email);
    const record = failedAttempts.get(email);
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
    recordFailure(company_name);
    const record = failedAttempts.get(company_name);
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