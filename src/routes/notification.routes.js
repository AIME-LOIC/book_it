import { Router }   from 'express';
import { getAll, getUnreadCount, markAsRead, markAllAsRead, remove }
  from '../controllers/notification.controller.js';
import authenticate from '../middleware/auth.js';

const router = Router();

// works for both users and operators — authenticate checks token, id works for both
router.get('/',              authenticate, getAll);
router.get('/unread',        authenticate, getUnreadCount);
router.patch('/:id/read',    authenticate, markAsRead);
router.patch('/read-all',    authenticate, markAllAsRead);
router.delete('/:id',        authenticate, remove);

export default router;