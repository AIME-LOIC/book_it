const isUser = (req, res, next) => {
  if (req.user?.role !== 'user' && req.user?.role !== 'admin') {
    return res.status(403).json({ message: 'User access only' });
  }
  next();
};

export default isUser;

