import { Router } from 'express';
import { register, loginUser, loginOperator, logout, verifyPassword, getLocker, getMe, updateMe }
  from '../controllers/auth.controller.js';
import { validateRegister, validateLogin, validateOperatorLogin } from '../middleware/validate.js';
import authenticate from '../middleware/auth.js';
import rateLimit from 'express-rate-limit';
import { createPersistentRateLimiter } from '../middleware/persistent-rate-limit.js';

const lockerLimiter = process.env.NODE_ENV === 'production'
  ? createPersistentRateLimiter({ name: 'locker-password', windowMs: 10 * 60 * 1000, max: 3, key: (req) => req.user?.id || 'anonymous' })
  : rateLimit({ windowMs: 10 * 60 * 1000, max: 3, standardHeaders: true, legacyHeaders: false, message: { message: 'Too many attempts. Please try again later.' } });

const router = Router();
router.post('/register',        validateRegister,      register);
router.post('/login',           validateLogin,         loginUser);
router.post('/operator/login',  validateOperatorLogin, loginOperator);
router.post('/logout',          logout);
router.post('/verify-password', authenticate, lockerLimiter, verifyPassword);
router.post('/locker',          authenticate, lockerLimiter, getLocker);
router.get('/me',               authenticate,          getMe);
router.patch('/me',             authenticate,          updateMe);

export default router;
