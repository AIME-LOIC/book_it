const isOperator = (req, res, next) => {
  if (req.user?.role !== 'operator') {
    return res.status(403).json({ message: 'Operator access only' });
  }
  next();
};

export default isOperator;