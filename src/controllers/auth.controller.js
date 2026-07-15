import * as authService from '../services/auth.service.js';

const authCookieOptions = {
  httpOnly: true,
  sameSite: 'lax',
  secure: process.env.NODE_ENV === 'production',
  path: '/',
  maxAge: 7 * 24 * 60 * 60 * 1000,
};

export const register = async (req, res) => {
  try {
    res.status(201).json({ message: 'Account created', user: await authService.register(req.body) });
  } catch (err) { res.status(400).json({ message: err.message }); }
};

export const loginUser = async (req, res) => {
  try {
    const { token, user } = await authService.loginUser(req.body);
    res.cookie('bookit_token', token, authCookieOptions);
    res.status(200).json({ user });
  } catch (err) { res.status(401).json({ message: err.message }); }
};

export const loginOperator = async (req, res) => {
  try {
    const { token, operator } = await authService.loginOperator(req.body);
    res.cookie('bookit_token', token, authCookieOptions);
    res.status(200).json({ operator });
  } catch (err) { res.status(401).json({ message: err.message }); }
};

export const logout = async (req, res) => {
  res.clearCookie('bookit_token', { ...authCookieOptions, maxAge: undefined });
  res.status(200).json({ message: 'Logged out' });
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

export const getMe = async (req, res) => {
  try {
    res.status(200).json(await authService.getMe(req.user));
  } catch (err) { res.status(404).json({ message: err.message }); }
};

export const updateMe = async (req, res) => {
  try {
    res.status(200).json(await authService.updateMe(req.user, req.body));
  } catch (err) { res.status(400).json({ message: err.message }); }
};
