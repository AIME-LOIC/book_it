import { Router }   from 'express';
import {
  create, login, updateProfile, assignBus,
  getMyDrivers, getDriverById, toggleDriver, remove,
  getMyPassengers, notifyExit,
} from '../controllers/driver.controller.js';
import authenticate from '../middleware/auth.js';
import isOperator   from '../middleware/operator.js';
import isDriver     from '../middleware/driver.js';

const router = Router();

// auth
router.post('/login',              login);

// driver self
router.patch('/profile',           authenticate, isDriver,   updateProfile);
router.get('/passengers',          authenticate, isDriver,   getMyPassengers);
router.post('/notify/:ticket_id',  authenticate, isDriver,   notifyExit);

// operator manages drivers
router.get('/',                    authenticate, isOperator, getMyDrivers);
router.get('/:id',                 authenticate, isOperator, getDriverById);
router.post('/',                   authenticate, isOperator, create);
router.patch('/:id/assign-bus',    authenticate, isOperator, assignBus);
router.patch('/:id/toggle',        authenticate, isOperator, toggleDriver);
router.delete('/:id',              authenticate, isOperator, remove);

export default router;