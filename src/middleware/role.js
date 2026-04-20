const isAdminOrOperator = (req, res, next) => {
  if (req.user?.role === 'admin' || req.user?.role === 'operator') return next();
  return res.status(403).json({ message: 'Admin or operator access only' });
};

export default isAdminOrOperator;