import bcrypt   from 'bcryptjs';
import jwt      from 'jsonwebtoken';
import User     from '../database/models/user.js';
import Operator from '../database/models/operator.js';
import { decryptPassword } from '../utils/crypto.utils.js';

// Authentication throttling is enforced by the shared database-backed middleware in app.js.

// ── REGISTER ──────────────────────────────────────────────────────
export const register = async ({ name, email, phone, password }) => {
  if (await User.findOne({ where: { email } })) throw new Error('Email already in use');
  const password_hash = await bcrypt.hash(password, 10);
  const user = await User.create({ name, email, phone, password_hash });
  return { id: user.id, name: user.name, email: user.email };
};

// ── LOGIN ─────────────────────────────────────────────────────────
export const loginUser = async ({ email, password }) => {
  const user = await User.findOne({ where: { email } });
  if (!user || !await bcrypt.compare(password, user.password_hash)) {
    throw new Error('Invalid credentials');
  }
  const token = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
};

export const loginOperator = async ({ company_name, password }) => {
  const operator = await Operator.findOne({ where: { company_name } });
  if (!operator || !operator.is_active || !await bcrypt.compare(password, operator.password_hash)) {
    throw new Error('Invalid credentials');
  }
  const token = jwt.sign(
    { id: operator.id, company_name: operator.company_name, role: 'operator' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return { token, operator: { id: operator.id, company_name: operator.company_name } };
};

// ── VERIFY PASSWORD ──────────────────────────────────────────────
// Attempt throttling is enforced after authentication by auth.routes.js.
export const verifyPassword = async (user, password) => {
  if (!password) throw new Error('Password required');
  let valid = false;
  if (user.role === 'operator') {
    const op = await Operator.findByPk(user.id);
    valid = !!(op && await bcrypt.compare(password, op.password_hash));
  } else {
    const u = await User.findByPk(user.id);
    valid = !!(u && await bcrypt.compare(password, u.password_hash));
  }
  if (!valid) throw new Error('Password verification failed.');
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
