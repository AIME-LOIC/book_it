import { Router }   from 'express';
import {
  addStops, getRouteWithStops, updateStop, deleteStop,
  getSettings, updateSettings,
} from '../controllers/route_stop.controller.js';
import authenticate from '../middleware/auth.js';
import isOperator   from '../middleware/operator.js';

const router = Router();

router.get('/settings',              authenticate, isOperator, getSettings);
router.patch('/settings',            authenticate, isOperator, updateSettings);
router.get('/:route_id',             getRouteWithStops);
router.post('/:route_id/stops',      authenticate, isOperator, addStops);
router.patch('/stops/:stop_id',      authenticate, isOperator, updateStop);
router.delete('/stops/:stop_id',     authenticate, isOperator, deleteStop);
// (former `/debug/search` route removed — it was unauthenticated and dumped
// the entire stops/locations dataset to anyone; use the normal search API)

export default router;