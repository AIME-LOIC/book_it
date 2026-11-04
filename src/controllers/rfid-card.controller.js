import { QueryTypes } from 'sequelize';
import sequelize from '../config/sequelize.js';

const DEFAULT_DEVICE_ID = 'bookit-bus-reader-001';
const SESSION_MINUTES = 2;
const normalizeUid = (value) => String(value || '').replace(/[^a-fA-F0-9]/g, '').toUpperCase();
const requireAdmin = (req, res) => {
  if (req.user?.role !== 'admin') { res.status(403).json({ message: 'Administrator access required.' }); return false; }
  return true;
};

export const listMyCards = async (req, res) => {
  try {
    const cards = await sequelize.query(
      `SELECT id, card_uid AS "cardUid", status, registered_at AS "registeredAt"
       FROM rfid_cards WHERE user_id = :userId AND status = 'active' ORDER BY registered_at DESC`,
      { replacements: { userId: req.user.id }, type: QueryTypes.SELECT },
    );
    res.json({ cards });
  } catch (error) {
    console.error('[RFID] list cards:', error.message);
    res.status(500).json({ message: 'Could not load RFID cards.' });
  }
};

export const startRegistration = async (req, res) => {
  try {
    const deviceId = String(req.body?.deviceId || process.env.RFID_DEFAULT_DEVICE_ID || DEFAULT_DEVICE_ID).trim();
    if (!deviceId || deviceId.length > 100) return res.status(400).json({ message: 'Invalid reader device ID.' });
    const result = await sequelize.transaction(async (transaction) => {
      await sequelize.query(
        `UPDATE rfid_registration_sessions SET status = 'expired', updated_at = CURRENT_TIMESTAMP
         WHERE device_id = :deviceId AND status = 'pending' AND expires_at <= CURRENT_TIMESTAMP`,
        { replacements: { deviceId }, transaction },
      );
      await sequelize.query(
        `UPDATE rfid_registration_sessions SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
         WHERE device_id = :deviceId AND status = 'pending'`,
        { replacements: { deviceId }, transaction },
      );
      const rows = await sequelize.query(
        `INSERT INTO rfid_registration_sessions (device_id, user_id, status, expires_at)
         VALUES (:deviceId, :userId, 'pending', CURRENT_TIMESTAMP + INTERVAL '2 minutes')
         RETURNING id, expires_at AS "expiresAt"`,
        { replacements: { deviceId, userId: req.user.id }, type: QueryTypes.SELECT, transaction },
      );
      return rows[0];
    });
    res.status(201).json({ sessionId: result.id, status: 'pending', expiresAt: result.expiresAt, message: 'Tap your RFID card on the BookIt reader within 2 minutes.' });
  } catch (error) {
    console.error('[RFID] start registration:', error.message);
    res.status(500).json({ message: 'Could not start card registration.' });
  }
};

export const getRegistrationStatus = async (req, res) => {
  try {
    const rows = await sequelize.query(
      `SELECT id, status, card_uid AS "cardUid", expires_at AS "expiresAt"
       FROM rfid_registration_sessions WHERE id = :id AND user_id = :userId LIMIT 1`,
      { replacements: { id: req.params.id, userId: req.user.id }, type: QueryTypes.SELECT },
    );
    if (!rows.length) return res.status(404).json({ message: 'Registration session not found.' });
    const session = rows[0];
    if (session.status === 'pending' && new Date(session.expiresAt) <= new Date()) {
      await sequelize.query(
        `UPDATE rfid_registration_sessions SET status = 'expired', updated_at = CURRENT_TIMESTAMP WHERE id = :id AND status = 'pending'`,
        { replacements: { id: session.id } },
      );
      session.status = 'expired';
    }
    res.json(session);
  } catch (error) {
    console.error('[RFID] registration status:', error.message);
    res.status(500).json({ message: 'Could not check registration status.' });
  }
};

export const unlinkCard = async (req, res) => {
  try {
    const deleted = await sequelize.query(
      'DELETE FROM rfid_cards WHERE id = :id AND user_id = :userId RETURNING id',
      { replacements: { id: req.params.id, userId: req.user.id }, type: QueryTypes.SELECT },
    );
    if (!deleted.length) return res.status(404).json({ message: 'RFID card not found.' });
    res.json({ message: 'RFID card unlinked.' });
  } catch (error) {
    console.error('[RFID] unlink card:', error.message);
    res.status(500).json({ message: 'Could not unlink RFID card.' });
  }
};

export const searchUsersForAdmin = async (req, res) => {
  if (!requireAdmin(req, res)) return;
  try {
    const search = String(req.query.search || '').trim();
    const users = await sequelize.query(
      `SELECT id, name, email FROM users
       WHERE role = 'user' AND (:search = '' OR name ILIKE :pattern OR email ILIKE :pattern)
       ORDER BY name ASC LIMIT 25`,
      { replacements: { search, pattern: '%' + search + '%' }, type: QueryTypes.SELECT },
    );
    res.json({ users });
  } catch (error) {
    console.error('[RFID] admin user search:', error.message);
    res.status(500).json({ message: 'Could not search passengers.' });
  }
};

export const startAdminRegistration = async (req, res) => {
  if (!requireAdmin(req, res)) return;
  try {
    const userId = String(req.body?.userId || '').trim();
    const deviceId = String(req.body?.deviceId || process.env.RFID_DEFAULT_DEVICE_ID || DEFAULT_DEVICE_ID).trim();
    if (!userId || !deviceId || deviceId.length > 100) return res.status(400).json({ message: 'Passenger and reader are required.' });
    const users = await sequelize.query(
      "SELECT id FROM users WHERE id = :userId AND role = 'user' LIMIT 1",
      { replacements: { userId }, type: QueryTypes.SELECT },
    );
    if (!users.length) return res.status(404).json({ message: 'Passenger account not found.' });
    const result = await sequelize.transaction(async (transaction) => {
      await sequelize.query(
        `UPDATE rfid_registration_sessions SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
         WHERE device_id = :deviceId AND status = 'pending'`,
        { replacements: { deviceId }, transaction },
      );
      const rows = await sequelize.query(
        `INSERT INTO rfid_registration_sessions (device_id, user_id, status, expires_at)
         VALUES (:deviceId, :userId, 'pending', CURRENT_TIMESTAMP + INTERVAL '2 minutes')
         RETURNING id, expires_at AS "expiresAt"`,
        { replacements: { deviceId, userId }, type: QueryTypes.SELECT, transaction },
      );
      return rows[0];
    });
    res.status(201).json({ sessionId: result.id, status: 'pending', expiresAt: result.expiresAt, message: 'Ask the passenger to tap their card on the selected reader.' });
  } catch (error) {
    console.error('[RFID] admin registration:', error.message);
    res.status(500).json({ message: 'Could not start passenger card registration.' });
  }
};

export const scanFromReader = async (req, res) => {
  const uid = normalizeUid(req.body?.uid);
  if (uid.length < 8 || uid.length > 40 || uid.length % 2 !== 0) {
    return res.status(400).json({ approved: false, message: 'Invalid RFID card UID.' });
  }
  try {
    const result = await sequelize.transaction(async (transaction) => {
      const sessions = await sequelize.query(
        `SELECT id, user_id FROM rfid_registration_sessions
         WHERE device_id = :deviceId AND status = 'pending' AND expires_at > CURRENT_TIMESTAMP
         ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
        { replacements: { deviceId: req.rfidDevice.id }, type: QueryTypes.SELECT, transaction },
      );
      if (!sessions.length) return { kind: 'no-session' };
      const session = sessions[0];
      const existing = await sequelize.query(
        'SELECT id, user_id, status FROM rfid_cards WHERE card_uid = :uid LIMIT 1 FOR UPDATE',
        { replacements: { uid }, type: QueryTypes.SELECT, transaction },
      );
      if (existing.length && existing[0].status === 'active') {
        return { kind: existing[0].user_id === session.user_id ? 'already-owned' : 'duplicate' };
      }
      if (existing.length) {
        await sequelize.query(
          `UPDATE rfid_cards SET user_id = :userId, status = 'active', registered_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = :id`,
          { replacements: { userId: session.user_id, id: existing[0].id }, transaction },
        );
      } else {
        await sequelize.query(
          `INSERT INTO rfid_cards (user_id, card_uid, status) VALUES (:userId, :uid, 'active')`,
          { replacements: { userId: session.user_id, uid }, transaction },
        );
      }
      await sequelize.query(
        `UPDATE rfid_registration_sessions SET status = 'completed', card_uid = :uid, updated_at = CURRENT_TIMESTAMP WHERE id = :id`,
        { replacements: { uid, id: session.id }, transaction },
      );
      return { kind: 'registered' };
    });
    if (result.kind === 'no-session') return res.status(409).json({ approved: false, message: 'No active card-registration session. Start Add RFID Card in BookIt first. Boarding validation is not enabled yet.' });
    if (result.kind === 'duplicate') return res.status(409).json({ approved: false, message: 'This card is already linked to another passenger.' });
    if (result.kind === 'already-owned') return res.status(200).json({ approved: true, message: 'This card is already linked to this passenger.' });
    res.status(200).json({ approved: true, message: 'RFID card registered to the passenger account.' });
  } catch (error) {
    console.error('[RFID] reader scan:', error.message);
    res.status(500).json({ approved: false, message: 'RFID scan could not be processed.' });
  }
};
