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

const router = Router();

// public
router.get('/search',           search);

// validate
router.post('/validate/qr',     authenticate, isOperator, validateByQR);
router.post('/validate/number', authenticate, isOperator, validateByNumber);

// operator
router.get('/operator',         authenticate, isOperator, getOperatorTickets);

// admin
router.get('/all',              authenticate, isAdmin, getAllTickets);

// user — put specific routes BEFORE param routes
router.get('/my',               authenticate, getMyTickets);
router.get('/my/:id',           authenticate, getTicketById);  // ← must be after /my
router.post('/',                authenticate, book);
router.patch('/:id/pay',        authenticate, pay);
router.patch('/:id/cancel',     authenticate, cancel);

export default router;