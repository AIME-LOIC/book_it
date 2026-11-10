import { Router } from 'express';
import authenticate from '../middleware/auth.js';
import isUser from '../middleware/user.js';
import { linkTicketToCard } from '../controllers/travel-card.controller.js';
const router=Router();
router.post('/:cardId/tickets',authenticate,isUser,linkTicketToCard);
export default router;
