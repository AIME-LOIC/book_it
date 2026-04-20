import { Router }   from 'express';
import { create, getAll, getById, update, changePassword, toggleActive, remove }
  from '../controllers/operator.controller.js';
import authenticate from '../middleware/auth.js';
import isAdmin      from '../middleware/admin.js';
import isOperator   from '../middleware/operator.js';

const router = Router();
router.get('/',             authenticate, isAdmin,    getAll);
router.get('/:id',          authenticate, isAdmin,    getById);
router.post('/',            authenticate, isAdmin,    create);
router.put('/:id',          authenticate, isAdmin,    update);
router.patch('/password',   authenticate, isOperator, changePassword);
router.patch('/:id/toggle', authenticate, isAdmin,    toggleActive);
router.delete('/:id',       authenticate, isAdmin,    remove);

export default router;