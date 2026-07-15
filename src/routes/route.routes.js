import { Router } from 'express';
import {
  create,
  getMine,
  getAll,
  getById,
  update,
  remove,
  getRuraSuggestion,
} from '../controllers/route.controller.js';
import authenticate from '../middleware/auth.js';
import isOperator from '../middleware/operator.js';
import { validateCreateRoute } from '../middleware/validate.js';

const router = Router();

router.get('/mine', authenticate, isOperator, getMine);
router.get('/rura-suggestion', authenticate, isOperator, getRuraSuggestion);
router.get('/', getAll);
router.get('/:id', getById);
router.post('/', authenticate, isOperator, validateCreateRoute, create);
router.put('/:id', authenticate, isOperator, update);
router.delete('/:id', authenticate, isOperator, remove);

export default router;