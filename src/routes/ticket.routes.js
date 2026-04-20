import { Router }   from 'express';
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
router.get('/search',              search);

// validate — operator scans or types at gate
router.post('/validate/qr',        authenticate, isOperator, validateByQR);
router.post('/validate/number',    authenticate, isOperator, validateByNumber);

// user
router.post('/',                   authenticate, book);
router.patch('/:id/pay',           authenticate, pay);
router.patch('/:id/cancel',        authenticate, cancel);
router.get('/my',                  authenticate, getMyTickets);
router.get('/my/:id',              authenticate, getTicketById);

// operator
router.get('/operator',            authenticate, isOperator, getOperatorTickets);

// admin
router.get('/',                    authenticate, isAdmin, getAllTickets);

export default router;