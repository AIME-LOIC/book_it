import * as svc from '../services/notification.service.js';

export const getAll        = async (req, res) => {
  try { res.status(200).json(await svc.getMyNotifications(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const getUnreadCount = async (req, res) => {
  try { res.status(200).json({ unread: await svc.getUnreadCount(req.user.id) }); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const markAsRead    = async (req, res) => {
  try { res.status(200).json(await svc.markAsRead(req.user.id, req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};

export const markAllAsRead = async (req, res) => {
  try { res.status(200).json(await svc.markAllAsRead(req.user.id)); }
  catch (err) { res.status(500).json({ message: err.message }); }
};

export const remove        = async (req, res) => {
  try { res.status(200).json(await svc.deleteNotification(req.user.id, req.params.id)); }
  catch (err) { res.status(404).json({ message: err.message }); }
};