import { createHash } from 'node:crypto';
import DevicePushToken from '../database/models/device_push_token.js';

export const registerDevice = async (req, res) => {
  try {
    const token = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
    const platform = typeof req.body?.platform === 'string' ? req.body.platform.toLowerCase() : '';
    if (token.length < 20 || token.length > 4096 || !['android', 'ios'].includes(platform)) {
      return res.status(400).json({ message: 'A valid FCM token and android/ios platform are required.' });
    }
    const token_hash = createHash('sha256').update(token).digest('hex');
    const [device, created] = await DevicePushToken.findOrCreate({
      where: { token_hash },
      defaults: {
        recipient_id: req.user.id,
        recipient_type: req.user.role,
        token,
        token_hash,
        platform,
        last_seen_at: new Date(),
      },
    });
    if (!created) {
      await device.update({
        recipient_id: req.user.id,
        recipient_type: req.user.role,
        token,
        platform,
        last_seen_at: new Date(),
      });
    }
    return res.status(created ? 201 : 200).json({ message: 'Push notification device registered.' });
  } catch (error) {
    console.error('[Push] Device registration failed:', error.message);
    return res.status(500).json({ message: 'Could not register this device for push notifications.' });
  }
};

export const unregisterDevice = async (req, res) => {
  try {
    const token = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
    if (!token) return res.status(400).json({ message: 'Device token is required.' });
    const token_hash = createHash('sha256').update(token).digest('hex');
    await DevicePushToken.destroy({
      where: { token_hash, recipient_id: req.user.id, recipient_type: req.user.role },
    });
    return res.status(200).json({ message: 'Push notification device unregistered.' });
  } catch (error) {
    console.error('[Push] Device unregistration failed:', error.message);
    return res.status(500).json({ message: 'Could not unregister this device.' });
  }
};
