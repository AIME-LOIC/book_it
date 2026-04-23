import { Router } from 'express';
import { register, loginUser, loginOperator, verifyPassword, getLocker, getMe, updateMe }
  from '../controllers/auth.controller.js';
import { validateRegister, validateLogin, validateOperatorLogin } from '../middleware/validate.js';
import authenticate from '../middleware/auth.js';

const router = Router();
router.post('/register',        validateRegister,      register);
router.post('/login',           validateLogin,         loginUser);
router.post('/operator/login',  validateOperatorLogin, loginOperator);
router.post('/verify-password', authenticate,          verifyPassword);
router.post('/locker',          authenticate,          getLocker);
router.get('/me',               authenticate,          getMe);
router.patch('/me',             authenticate,          updateMe);

export default router;
