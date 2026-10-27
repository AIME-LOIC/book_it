import * as svc from '../services/route.service.js';

import { clientMessage } from '../utils/error.util.js';
const normalizeRoutePayload = (body = {}) => {
  const price = body.price === undefined || body.price === null || body.price === ''
    ? undefined
    : Number(body.price);

  return {
    ...body,
    ...(price !== undefined && Number.isFinite(price) ? { price } : {}),
  };
};

export const create = async (req, res) => {
  try {
    const payload = normalizeRoutePayload(req.body);
    res.status(201).json(await svc.createRoute(req.user.id, payload));
  } catch (err) {
    res.status(400).json({ message: clientMessage(err) });
  }
};

export const getMine = async (req, res) => {
  try { res.status(200).json(await svc.getMyRoutes(req.user.id)); }
  catch (err) { res.status(500).json({ message: clientMessage(err) }); }
};

export const getAll  = async (req, res) => {
  try { res.status(200).json(await svc.getAllRoutes()); }
  catch (err) { res.status(500).json({ message: clientMessage(err) }); }
};

export const getDirections = async (req, res) => {
  const { origin, destination, waypoints } = req.query;
  if (!origin || !destination) {
    return res.status(400).json({ message: 'origin and destination are required' });
  }
  const key = process.env.GOOGLE_MAPS_SERVER_API_KEY;
  if (!key) {
    return res.status(503).json({ message: 'Google Maps Directions is not configured on the server.' });
  }
  try {
    const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
    url.searchParams.set('origin', String(origin));
    url.searchParams.set('destination', String(destination));
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('key', key);
    if (waypoints) url.searchParams.set('waypoints', 'optimize:false|' + String(waypoints));
    const response = await fetch(url);
    const data = await response.json();
    if (!response.ok || data.status !== 'OK') {
      console.error('[MAPS] Directions request failed:', data.status, data.error_message || '');
      return res.status(502).json({ message: 'Google Maps could not calculate this route.', status: data.status });
    }
    return res.status(200).json(data);
  } catch (err) {
    console.error('[MAPS] Directions request error:', err?.stack || err);
    return res.status(502).json({ message: 'Could not retrieve directions from Google Maps.' });
  }
};

export const getById = async (req, res) => {
  try {
    res.status(200).json(await svc.getRouteById(req.params.id));
  } catch (err) {
    res.status(404).json({ message: clientMessage(err) });
  }
};

export const getRuraSuggestion = async (req, res) => {
  try {
    const { from_location_id, to_location_id } = req.query;
    if (!from_location_id || !to_location_id) {
      throw new Error('from_location_id and to_location_id are required');
    }
    res.status(200).json(await svc.getRuraSuggestion(from_location_id, to_location_id));
  } catch (err) {
    res.status(400).json({ message: clientMessage(err) });
  }
};

export const update = async (req, res) => {
  try {
    const payload = normalizeRoutePayload(req.body);
    res.status(200).json(await svc.updateRoute(req.user.id, req.params.id, payload));
  } catch (err) {
    res.status(400).json({ message: clientMessage(err) });
  }
};

export const remove = async (req, res) => {
  try {
    await svc.deleteRoute(req.user.id, req.params.id);
    res.status(200).json({ message: 'Route deleted' });
  } catch (err) {
    res.status(404).json({ message: clientMessage(err) });
  }
};