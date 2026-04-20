import { Router }          from 'express';
import { create, getAll, getById, remove } from '../controllers/location.controller.js';
import authenticate        from '../middleware/auth.js';
import isAdmin             from '../middleware/admin.js';
import isAdminOrOperator   from '../middleware/role.js';

const router = Router();

router.get('/',       getAll);
router.get('/:id',    getById);
router.post('/',      authenticate, isAdminOrOperator, create);
router.delete('/:id', authenticate, isAdmin,           remove);

export default router;