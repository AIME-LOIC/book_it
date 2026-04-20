import * as svc from '../services/bus.service.js';

export const create     = async (req, res) => {
  try { res.status(201).json(await svc.createBus(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const getMine    = async (req, res) => {
  try { res.status(200).json(await svc.getMyBuses(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getAll     = async (req, res) => {
  try { res.status(200).json(await svc.getAllBuses()); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getByRoute = async (req, res) => {
  try { res.status(200).json(await svc.getBusesByRoute(req.params.route_id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const getById    = async (req, res) => {
  try { res.status(200).json(await svc.getBusById(req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const update     = async (req, res) => {
  try { res.status(200).json(await svc.updateBus(req.user.id, req.params.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const remove     = async (req, res) => {
  try {
    await svc.deleteBus(req.user.id, req.params.id);
    res.status(200).json({ message: 'Bus deleted' });
  } catch (err) { res.status(404).json({ message: err.message }); }
};
export const getAvailable = async (req, res) => {
  try { res.status(200).json(await svc.getAllAvailableBuses()); }
  catch (err) { res.status(500).json({ message: err.message }); }
};