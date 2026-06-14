import { Router }   from 'express';
import {
  create, login, updateProfile, assignBus,
  getMyDrivers, getDriverById, toggleDriver, remove,
  getMyPassengers, notifyExit, getMe, updateLocation,
} from '../controllers/driver.controller.js';
import authenticate from '../middleware/auth.js';
import isOperator   from '../middleware/operator.js';
import isDriver     from '../middleware/driver.js';
import { validateDriverLocation } from '../middleware/validate.js';
import rateLimit from 'express-rate-limit';

const locationLimiter = rateLimit({ windowMs: 30 * 1000, max: 10 }); // 10 updates per 30s

const router = Router();

// auth
router.post('/login',              login);

// driver self
router.get('/me',                  authenticate, isDriver,   getMe);
router.patch('/profile',           authenticate, isDriver,   updateProfile);
router.get('/passengers',          authenticate, isDriver,   getMyPassengers);
router.post('/notify/:ticket_id',  authenticate, isDriver,   notifyExit);
// driver updates their current GPS location (updates assigned bus location)
router.patch('/location',          authenticate, isDriver, locationLimiter, validateDriverLocation, updateLocation);

// operator manages drivers
router.get('/',                    authenticate, isOperator, getMyDrivers);
router.get('/:id',                 authenticate, isOperator, getDriverById);
router.post('/',                   authenticate, isOperator, create);
router.patch('/:id/assign-bus',    authenticate, isOperator, assignBus);
router.patch('/:id/toggle',        authenticate, isOperator, toggleDriver);
router.delete('/:id',              authenticate, isOperator, remove);

export default router;