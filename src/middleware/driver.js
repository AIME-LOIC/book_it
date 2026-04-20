const isDriver = (req, res, next) => {
  if (req.user?.role !== 'driver') {
    return res.status(403).json({ message: 'Driver access only' });
  }
  next();
};

export default isDriver;