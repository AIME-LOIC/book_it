import * as svc from '../services/location.service.js';

export const create  = async (req, res) => {
  try { res.status(201).json(await svc.createLocation(req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const getAll  = async (req, res) => {
  try { res.status(200).json(await svc.getAllLocations()); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getById = async (req, res) => {
  try { res.status(200).json(await svc.getLocationById(req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const remove  = async (req, res) => {
  try {
    await svc.deleteLocation(req.params.id);
    res.status(200).json({ message: 'Location deleted' });
  } catch (err) { res.status(404).json({ message: err.message }); }
};