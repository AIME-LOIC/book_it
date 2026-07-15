import * as svc from '../services/driver.service.js';
import * as ticketSvc from '../services/ticket.service.js';
import * as busSvc from '../services/bus.service.js';

const authCookieOptions = {
  httpOnly: true,
  sameSite: 'lax',
  secure: process.env.NODE_ENV === 'production',
  path: '/',
  maxAge: 7 * 24 * 60 * 60 * 1000,
};

export const getMe = async (req, res) => {
  try { res.status(200).json(await svc.getDriverMe(req.user.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const create           = async (req, res) => {
  try { res.status(201).json(await svc.createDriver(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const login            = async (req, res) => {
  try {
    const { token, driver } = await svc.loginDriver(req.body);
    res.cookie('bookit_token', token, authCookieOptions);
    res.status(200).json({ driver });
  }
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

export const updateLocation = async (req, res) => {
  try {
    const { last_lat, last_lng } = req.body;
    if (!req.user.bus_id) return res.status(400).json({ message: 'No bus assigned to driver' });
    // update both driver and assigned bus location
    await svc.updateDriverLocation(req.user.id, { last_lat, last_lng });
    const updated = await busSvc.updateBusLocation(req.user.bus_id, { last_lat, last_lng });
    res.status(200).json(updated);
  } catch (err) { res.status(400).json({ message: err.message }); }
};
