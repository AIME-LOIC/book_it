import { Router }   from 'express';
import { create, getMine, getAll, getAvailable, getByRoute, getById, update, remove }
  from '../controllers/bus.controller.js';
import authenticate from '../middleware/auth.js';
import isOperator   from '../middleware/operator.js';

const router = Router();
router.get('/',                getAll);
router.get('/mine',            authenticate, isOperator, getMine);
router.get('/available', getAvailable); 
router.get('/route/:route_id', getByRoute);
router.get('/:id',             getById);
router.post('/',               authenticate, isOperator, create);
router.put('/:id',             authenticate, isOperator, update);
router.delete('/:id',          authenticate, isOperator, remove);

export default router;