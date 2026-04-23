import { Router } from 'express';
import { register, loginUser, loginOperator } from '../controllers/auth.controller.js';
import { validateRegister, validateLogin, validateOperatorLogin } from '../middleware/validate.js';

const router = Router();
router.post('/register',       validateRegister,       register);
router.post('/login',          validateLogin,          loginUser);
router.post('/operator/login', validateOperatorLogin,  loginOperator);

export default router;