import * as authService from '../services/auth.service.js';

export const register       = async (req, res) => {
  try {
    res.status(201).json({ message: 'Account created', user: await authService.register(req.body) });
  } catch (err) { res.status(400).json({ message: err.message }); }
};

export const loginUser      = async (req, res) => {
  try {
    res.status(200).json(await authService.loginUser(req.body));
  } catch (err) { res.status(401).json({ message: err.message }); }
};

export const loginOperator  = async (req, res) => {
  try {
    res.status(200).json(await authService.loginOperator(req.body));
  } catch (err) { res.status(401).json({ message: err.message }); }
};

export const verifyPassword = async (req, res) => {
  try {
    res.status(200).json(await authService.verifyPassword(req.user, req.body.password));
  } catch (err) { res.status(401).json({ message: err.message }); }
};

export const getLocker = async (req, res) => {
  try {
    res.status(200).json(await authService.getLocker(req.user, req.body.password));
  } catch (err) { res.status(401).json({ message: err.message }); }
};