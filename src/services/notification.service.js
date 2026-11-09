import Notification from '../database/models/notification.js';
import DevicePushToken from '../database/models/device_push_token.js';
import { sendPushToTokens } from './fcm.service.js';

const deliverPush = async (notification) => {
  try {
    const devices = await DevicePushToken.findAll({ where: { recipient_id: notification.recipient_id, recipient_type: notification.recipient_type } });
    await sendPushToTokens(devices, {
      title: String(notification.type || 'BookIt update').replaceAll('_', ' '),
      body: notification.message,
      data: { notification_id: notification.id, ...(notification.meta || {}) },
    });
  } catch (error) {
    // Persisted in-app notifications remain available even if FCM is temporarily unavailable.
    console.error('[Push] Notification delivery failed:', error.message);
  }
};

// Create a notification
export const createNotification = async ({ recipient_id, recipient_type, type, message, meta = null }) => {
  const notification = await Notification.create({ recipient_id, recipient_type, type, message, meta });
  await deliverPush(notification);
  return notification;
};

// Create multiple notifications at once
export const createMany = async (notifications) => {
  const created = await Notification.bulkCreate(notifications);
  await Promise.all(created.map(deliverPush));
  return created;
};

// Persist one update notice per recipient and version, then send it through FCM.
export const createAppUpdateNotice = async ({ recipient_id, recipient_type, version }) => {
  const existing = await Notification.findAll({
    where: { recipient_id, recipient_type, type: 'app_update_available' },
    order: [['createdAt', 'DESC']],
    limit: 20,
  });
  if (existing.some((item) => String(item.meta?.version || '') === version)) return null;
  return createNotification({
    recipient_id,
    recipient_type,
    type: 'app_update_available',
    message: `BookIt version ${version} is available. Open Profile → App updates to install it.`,
    meta: { version, action: 'app_update' },
  });
};

// Get all notifications for a recipient
export const getMyNotifications = async (recipient_id, recipient_type) => {
  return await Notification.findAll({
    where:  { recipient_id, recipient_type },
    order:  [['createdAt', 'DESC']],
    limit:  50,
  });
};

// Get unread count
export const getUnreadCount = async (recipient_id, recipient_type) => {
  return await Notification.count({
    where: { recipient_id, recipient_type, is_read: false },
  });
};

// Mark one as read. Scope by both owner ID and recipient role.
export const markAsRead = async (recipient_id, recipient_type, id) => {
  const notif = await Notification.findOne({ where: { id, recipient_id, recipient_type } });
  if (!notif) throw new Error('Notification not found');
  await notif.update({ is_read: true });
  return notif;
};

// Mark all as read for the authenticated recipient and role only.
export const markAllAsRead = async (recipient_id, recipient_type) => {
  await Notification.update(
    { is_read: true },
    { where: { recipient_id, recipient_type, is_read: false } }
  );
  return { message: 'All notifications marked as read' };
};

// Delete one. Scope by both owner ID and recipient role.
export const deleteNotification = async (recipient_id, recipient_type, id) => {
  const notif = await Notification.findOne({ where: { id, recipient_id, recipient_type } });
  if (!notif) throw new Error('Notification not found');
  await notif.destroy();
  return { message: 'Notification deleted' };
};
