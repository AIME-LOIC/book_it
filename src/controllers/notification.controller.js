import * as svc from '../services/notification.service.js';
import { clientMessage } from '../utils/error.util.js';

export const createAppUpdateNotice = async (req, res) => {
  try {
    const version = String(req.body?.version || '').trim();
    if (!/^\d+\.\d+\.\d+$/.test(version)) {
      return res.status(400).json({ message: 'A valid update version is required.' });
    }
    const notification = await svc.createAppUpdateNotice({
      recipient_id: req.user.id,
      recipient_type: req.user.role,
      version,
    });
    res.status(200).json({ created: Boolean(notification), notification });
  } catch (err) {
    res.status(500).json({ message: clientMessage(err) });
  }
};

export const getAll = async (req, res) => {
  try { res.status(200).json(await svc.getMyNotifications(req.user.id, req.user.role)); }
  catch (err) { res.status(500).json({ message: clientMessage(err) }); }
};

export const getUnreadCount = async (req, res) => {
  try { res.status(200).json({ unread: await svc.getUnreadCount(req.user.id, req.user.role) }); }
  catch (err) { res.status(500).json({ message: clientMessage(err) }); }
};

export const markAsRead = async (req, res) => {
  try {
    res.status(200).json(await svc.markAsRead(req.user.id, req.user.role, req.params.id));
  } catch (err) { res.status(404).json({ message: clientMessage(err) }); }
};

export const markAllAsRead = async (req, res) => {
  try {
    res.status(200).json(await svc.markAllAsRead(req.user.id, req.user.role));
  } catch (err) { res.status(500).json({ message: clientMessage(err) }); }
};

export const remove = async (req, res) => {
  try {
    res.status(200).json(await svc.deleteNotification(req.user.id, req.user.role, req.params.id));
  } catch (err) { res.status(404).json({ message: clientMessage(err) }); }
};
