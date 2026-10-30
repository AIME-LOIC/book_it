import { Router }   from 'express';
import { create, getMine, getAll, getAvailable, getByRoute, getById, update, remove, updateLocation }
  from '../controllers/bus.controller.js';
import authenticate from '../middleware/auth.js';
import isOperator   from '../middleware/operator.js';
import isDriver     from '../middleware/driver.js';
import { validateCreateBus, validateDriverLocation } from '../middleware/validate.js';

const router = Router();
router.get('/',                getAll);
router.get('/mine',            authenticate, isOperator, getMine);
router.get('/available',       getAvailable);
router.get('/route/:route_id', getByRoute);
// GPS updates: drivers may only move THEIR assigned bus (isDriver also
// refreshes bus_id from the DB and enforces role/suspension). Previously
// `authenticate` alone let any logged-in user spoof any bus's position.
router.patch('/:id/location',  authenticate, isDriver, validateDriverLocation, updateLocation);
router.get('/:id',             getById);
router.post('/',               authenticate, isOperator, validateCreateBus, create);
router.put('/:id',             authenticate, isOperator, update);
router.delete('/:id',          authenticate, isOperator, remove);

export default router;