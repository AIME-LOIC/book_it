import Driver from '../database/models/driver.js';

const isDriver = async (req, res, next) => {
  if (req.user?.role !== 'driver') {
    return res.status(403).json({ message: 'Driver access only' });
  }
  try {
    // fetch fresh driver data — don't trust bus_id from JWT
    const driver = await Driver.findByPk(req.user.id, {
      attributes: ['id', 'bus_id', 'operator_id', 'is_active'],
    });
    if (!driver)          return res.status(403).json({ message: 'Driver not found' });
    if (!driver.is_active) return res.status(403).json({ message: 'Account suspended' });
    // attach fresh data to req.user
    req.user.bus_id      = driver.bus_id;
    req.user.operator_id = driver.operator_id;
    next();
  } catch (err) {
    return res.status(500).json({ message: 'Server error' });
  }
};

export default isDriver;
