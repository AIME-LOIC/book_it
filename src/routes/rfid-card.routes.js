import { Router } from 'express';
import authenticate from '../middleware/auth.js';
import {
  listMyCards, startRegistration, getRegistrationStatus, unlinkCard,
  searchUsersForAdmin, startAdminRegistration,
} from '../controllers/rfid-card.controller.js';

const router = Router();
router.get('/', authenticate, listMyCards);
router.post('/registration-sessions', authenticate, startRegistration);
router.get('/registration-sessions/:id', authenticate, getRegistrationStatus);
router.delete('/:id', authenticate, unlinkCard);
router.get('/admin/users', authenticate, searchUsersForAdmin);
router.post('/admin/registration-sessions', authenticate, startAdminRegistration);
export default router;
