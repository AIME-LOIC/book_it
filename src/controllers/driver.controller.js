import * as svc from '../services/driver.service.js';
import * as ticketSvc from '../services/ticket.service.js';

export const getMe = async (req, res) => {
  try { res.status(200).json(await svc.getDriverMe(req.user.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const create           = async (req, res) => {
  try { res.status(201).json(await svc.createDriver(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const login            = async (req, res) => {
  try { res.status(200).json(await svc.loginDriver(req.body)); }
  catch (err) { res.status(401).json({ message: err.message }); }
};

export const updateProfile    = async (req, res) => {
  try { res.status(200).json(await svc.updateProfile(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const assignBus        = async (req, res) => {
  try { res.status(200).json(await svc.assignBus(req.user.id, req.params.id, req.body.bus_id)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const getMyDrivers     = async (req, res) => {
  try { res.status(200).json(await svc.getMyDrivers(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getDriverById    = async (req, res) => {
  try { res.status(200).json(await svc.getDriverById(req.user.id, req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const toggleDriver     = async (req, res) => {
  try { res.status(200).json(await svc.toggleDriver(req.user.id, req.params.id)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const remove           = async (req, res) => {
  try {
    await svc.deleteDriver(req.user.id, req.params.id);
    res.status(200).json({ message: 'Driver deleted' });
  } catch (err) { res.status(404).json({ message: err.message }); }
};

export const getMyPassengers  = async (req, res) => {
  try {
    res.status(200).json(await ticketSvc.getBusPassengers(req.user.bus_id, req.query.date));
  } catch (err) { res.status(500).json({ message: err.message }); }
};

export const notifyExit       = async (req, res) => {
  try {
    res.status(200).json(await ticketSvc.notifyPassengerExit(req.user.id, req.params.ticket_id));
  } catch (err) { res.status(400).json({ message: err.message }); }
};