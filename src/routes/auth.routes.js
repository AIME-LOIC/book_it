import { Router } from 'express';
import { register, loginUser, loginOperator, verifyPassword, getLocker } from '../controllers/auth.controller.js';
import { validateRegister, validateLogin, validateOperatorLogin } from '../middleware/validate.js';
import authenticate from '../middleware/auth.js';
import isOperator   from '../middleware/operator.js';
import isAdmin      from '../middleware/admin.js';

const router = Router();
router.post('/register',        validateRegister,      register);
router.post('/login',           validateLogin,         loginUser);
router.post('/operator/login',  validateOperatorLogin, loginOperator);
router.post('/verify-password', authenticate,          verifyPassword);
router.post('/locker',          authenticate,          getLocker);

export default router;