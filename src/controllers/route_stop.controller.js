import * as svc from '../services/route_stop.service.js';

export const addStops          = async (req, res) => {
  try { res.status(201).json(await svc.addStops(req.user.id, req.params.route_id, req.body.stops)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const getRouteWithStops = async (req, res) => {
  try { res.status(200).json(await svc.getRouteWithStops(req.params.route_id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const updateStop        = async (req, res) => {
  try { res.status(200).json(await svc.updateStop(req.user.id, req.params.stop_id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const deleteStop        = async (req, res) => {
  try {
    await svc.deleteStop(req.user.id, req.params.stop_id);
    res.status(200).json({ message: 'Stop deleted' });
  } catch (err) { res.status(404).json({ message: err.message }); }
};

export const getSettings       = async (req, res) => {
  try { res.status(200).json(await svc.getOperatorSettings(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const updateSettings    = async (req, res) => {
  try { res.status(200).json(await svc.updateOperatorSettings(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};