import { Router } from 'express';
import {
  search, book, pay, payStatus, flutterwaveWebhook, cancel,
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

// Flutterwave webhook — no auth middleware; Flutterwave calls this
// directly and it's verified via the verif-hash header instead.
// NOTE: make sure this route is mounted with express.json() (raw JSON
// body, not urlencoded) so req.body.data.id / status parse correctly.
router.post('/webhooks/flutterwave', flutterwaveWebhook);

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
router.get('/:id/pay/status',   authenticate, isUser, payStatus);
router.patch('/:id/cancel',     authenticate, isUser, cancel);

export default router;