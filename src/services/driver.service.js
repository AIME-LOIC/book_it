import bcrypt   from 'bcrypt';
import jwt      from 'jsonwebtoken';
import crypto   from 'crypto';
import Driver   from '../database/models/driver.js';
import Bus      from '../database/models/bus.js';
import Operator from '../database/models/operator.js';

const driverIncludes = [
  { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
  { model: Bus,      as: 'bus',      attributes: ['id', 'plate_number', 'departure_time'] },
];

export const createDriver = async (operator_id, { name, phone, bus_id }) => {
  if (await Driver.findOne({ where: { phone } })) throw new Error('Phone already in use');

  if (bus_id) {
    const existing = await Driver.findOne({ where: { bus_id } });
    if (existing) throw new Error('Bus already has a driver assigned');
  }

  const plainPassword = crypto.randomBytes(4).toString('hex').toUpperCase();
  const password_hash = await bcrypt.hash(plainPassword, 10);

  const driver = await Driver.create({
    operator_id,
    bus_id: bus_id || null,
    name,
    phone,
    password_hash,
    default_password: plainPassword,
    must_update_profile: true,
  });

  return {
    id:               driver.id,
    name:             driver.name,
    phone:            driver.phone,
    bus_id:           driver.bus_id,
    default_password: plainPassword,
  };
};

export const loginDriver = async ({ phone, password }) => {
  const { checkLockout, recordFailure, clearFailures, MAX_ATTEMPTS, failedAttempts } = await import('./auth.service.js');
  checkLockout(phone);
  const driver = await Driver.findOne({ where: { phone }, include: driverIncludes });
  if (!driver || !await bcrypt.compare(password, driver.password_hash)) {
    recordFailure(phone);
    const record = failedAttempts.get(phone);
    const remaining = MAX_ATTEMPTS - (record?.count || 0);
    throw new Error(remaining > 0
      ? `Invalid credentials. ${remaining} attempt${remaining > 1 ? 's' : ''} remaining.`
      : 'Account locked for 15 minutes.');
  }
  if (!driver.is_active) throw new Error('Account suspended');
  clearFailures(phone);

  const token = jwt.sign(
    { id: driver.id, phone: driver.phone, role: 'driver' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );

  return {
    token,
    driver: {
      id:                  driver.id,
      name:                driver.name,
      phone:               driver.phone,
      bus:                 driver.bus,
      operator:            driver.operator,
      must_update_profile: driver.must_update_profile,
    },
  };
};

export const updateProfile = async (driver_id, { name, email, phone, old_password, new_password }) => {
  const driver = await Driver.findByPk(driver_id);
  if (!driver) throw new Error('Driver not found');

  if (new_password) {
    if (!old_password) throw new Error('Old password required');
    if (!await bcrypt.compare(old_password, driver.password_hash)) throw new Error('Old password incorrect');
    driver.password_hash = await bcrypt.hash(new_password, 10);
    driver.default_password = null;
  }

  if (email && email !== driver.email) {
    if (await Driver.findOne({ where: { email } })) throw new Error('Email already in use');
    driver.email = email;
  }

  if (phone && phone !== driver.phone) {
    if (await Driver.findOne({ where: { phone } })) throw new Error('Phone already in use');
    driver.phone = phone;
  }

  if (name) driver.name = name;
  driver.must_update_profile = false;
  await driver.save();

  return { id: driver.id, name: driver.name, email: driver.email, phone: driver.phone };
};

export const assignBus = async (operator_id, driver_id, bus_id) => {
  const driver = await Driver.findOne({ where: { id: driver_id, operator_id } });
  if (!driver) throw new Error('Driver not found or not yours');

  const existing = await Driver.findOne({ where: { bus_id } });
  if (existing && existing.id !== driver_id) throw new Error('Bus already has a driver');

  await driver.update({ bus_id });
  return await Driver.findByPk(driver_id, { include: driverIncludes });
};

export const getMyDrivers = async (operator_id) => {
  return await Driver.findAll({
    where:   { operator_id },
    include: driverIncludes,
    attributes: { exclude: ['password_hash'] },
  });
};

export const getDriverById = async (operator_id, id) => {
  const driver = await Driver.findOne({
    where:   { id, operator_id },
    include: driverIncludes,
    attributes: { exclude: ['password_hash'] },
  });
  if (!driver) throw new Error('Driver not found');
  return driver;
};

export const toggleDriver = async (operator_id, id) => {
  const driver = await Driver.findOne({ where: { id, operator_id } });
  if (!driver) throw new Error('Driver not found or not yours');
  await driver.update({ is_active: !driver.is_active });
  return { id: driver.id, is_active: driver.is_active };
};

export const deleteDriver = async (operator_id, id) => {
  const driver = await Driver.findOne({ where: { id, operator_id } });
  if (!driver) throw new Error('Driver not found or not yours');
  await driver.destroy();
};