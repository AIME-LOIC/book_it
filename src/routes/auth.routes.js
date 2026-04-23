import { Router } from 'express';
import { register, loginUser, loginOperator, verifyPassword } from '../controllers/auth.controller.js';
import { validateRegister, validateLogin, validateOperatorLogin } from '../middleware/validate.js';
import authenticate from '../middleware/auth.js';

const router = Router();
router.post('/register',       validateRegister,       register);
router.post('/login',          validateLogin,          loginUser);
router.post('/operator/login', validateOperatorLogin,  loginOperator);
router.post('/verify-password', authenticate,          verifyPassword);

export default router;