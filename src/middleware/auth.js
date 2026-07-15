import jwt from 'jsonwebtoken';

const parseCookieHeader = (cookieHeader = '') => {
  return cookieHeader.split(';').reduce((cookies, pair) => {
    const index = pair.indexOf('=');
    if (index < 0) return cookies;
    const key = pair.slice(0, index).trim();
    const value = pair.slice(index + 1).trim();
    if (key) cookies[key] = decodeURIComponent(value);
    return cookies;
  }, {});
};

const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const cookies = parseCookieHeader(req.headers.cookie || '');
  const token = authHeader?.startsWith('Bearer ')
    ? authHeader.split(' ')[1]
    : cookies.bookit_token;

  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
};

export default authenticate;
