import { Router } from 'express';
import {
  search, book, pay, cancel,
  getMyTickets, getTicketById,
  getOperatorTickets, getAllTickets,
  validateByQR, validateByNumber,
} from '../controllers/ticket.controller.js';
import authenticate from '../middleware/auth.js';
import isAdmin      from '../middleware/admin.js';
import isOperator   from '../middleware/operator.js';
import isDriver     from '../middleware/driver.js';
import isUser       from '../middleware/user.js';
import { validateBookTicket } from '../middleware/validate.js';

const router = Router();

// public
router.get('/search',           search);

// validate
router.post('/validate/qr',     authenticate, isDriver, validateByQR);
router.post('/validate/number', authenticate, isDriver, validateByNumber);

// operator
router.get('/operator',         authenticate, isOperator, getOperatorTickets);

// admin
router.get('/all',              authenticate, isAdmin, getAllTickets);

// user
router.get('/my',               authenticate, isUser, getMyTickets);
router.get('/my/:id',           authenticate, isUser, getTicketById);
router.post('/',                authenticate, isUser, validateBookTicket, book);
router.patch('/:id/pay',        authenticate, isUser, pay);
router.patch('/:id/cancel',     authenticate, isUser, cancel);

export default router;
