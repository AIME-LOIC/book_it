import * as svc from '../services/operator.service.js';

export const create         = async (req, res) => {
  try { res.status(201).json(await svc.createOperator(req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const getAll         = async (req, res) => {
  try { res.status(200).json(await svc.getAllOperators()); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getById        = async (req, res) => {
  try { res.status(200).json(await svc.getOperatorById(req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const update         = async (req, res) => {
  try { res.status(200).json(await svc.updateOperator(req.params.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const changePassword = async (req, res) => {
  try { res.status(200).json(await svc.changePassword(req.user.id, req.body)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const toggleActive   = async (req, res) => {
  try { res.status(200).json(await svc.toggleActive(req.params.id)); }
  catch (err) { res.status(400).json({ message: err.message }); }
};

export const remove         = async (req, res) => {
  try {
    await svc.deleteOperator(req.params.id);
    res.status(200).json({ message: 'Operator deleted' });
  } catch (err) { res.status(404).json({ message: err.message }); }
};