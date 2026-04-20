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
router.get('/debug/search', async (req, res) => {
  const { from_location_id, to_location_id } = req.query;
  const RouteStop = (await import('../database/models/route_stop.js')).default;
  const Location  = (await import('../database/models/location.js')).default;

  const fromStops = await RouteStop.findAll({ where: { location_id: from_location_id } });
  const toStops   = await RouteStop.findAll({ where: { location_id: to_location_id   } });
  const allStops  = await RouteStop.findAll({ include: [{ model: Location, as: 'location' }] });

  res.json({ fromStops, toStops, allStops });
});

export default router;