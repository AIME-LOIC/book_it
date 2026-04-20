import Notification from '../database/models/notification.js';

// Create a notification
export const createNotification = async ({ recipient_id, recipient_type, type, message, meta = null }) => {
  return await Notification.create({ recipient_id, recipient_type, type, message, meta });
};

// Create multiple notifications at once
export const createMany = async (notifications) => {
  return await Notification.bulkCreate(notifications);
};

// Get all notifications for a recipient
export const getMyNotifications = async (recipient_id) => {
  return await Notification.findAll({
    where:  { recipient_id },
    order:  [['createdAt', 'DESC']],
  });
};

// Get unread count
export const getUnreadCount = async (recipient_id) => {
  return await Notification.count({
    where: { recipient_id, is_read: false },
  });
};

// Mark one as read
export const markAsRead = async (recipient_id, id) => {
  const notif = await Notification.findOne({ where: { id, recipient_id } });
  if (!notif) throw new Error('Notification not found');
  await notif.update({ is_read: true });
  return notif;
};

// Mark all as read
export const markAllAsRead = async (recipient_id) => {
  await Notification.update(
    { is_read: true },
    { where: { recipient_id, is_read: false } }
  );
  return { message: 'All notifications marked as read' };
};

// Delete one
export const deleteNotification = async (recipient_id, id) => {
  const notif = await Notification.findOne({ where: { id, recipient_id } });
  if (!notif) throw new Error('Notification not found');
  await notif.destroy();
  return { message: 'Notification deleted' };
};