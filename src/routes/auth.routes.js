import { Router } from 'express';
import { register, loginUser, loginOperator } from '../controllers/auth.controller.js';

const router = Router();
router.post('/register',       register);
router.post('/login',          loginUser);
router.post('/operator/login', loginOperator);

export default router;