import * as svc from '../services/route.service.js';

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
    res.status(400).json({ message: err.message });
  }
};

export const getMine = async (req, res) => {
  try { res.status(200).json(await svc.getMyRoutes(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getAll  = async (req, res) => {
  try { res.status(200).json(await svc.getAllRoutes()); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getById = async (req, res) => {
  try {
    res.status(200).json(await svc.getRouteById(req.params.id));
  } catch (err) {
    res.status(404).json({ message: err.message });
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
    res.status(400).json({ message: err.message });
  }
};

export const update = async (req, res) => {
  try {
    const payload = normalizeRoutePayload(req.body);
    res.status(200).json(await svc.updateRoute(req.user.id, req.params.id, payload));
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

export const remove = async (req, res) => {
  try {
    await svc.deleteRoute(req.user.id, req.params.id);
    res.status(200).json({ message: 'Route deleted' });
  } catch (err) {
    res.status(404).json({ message: err.message });
  }
};