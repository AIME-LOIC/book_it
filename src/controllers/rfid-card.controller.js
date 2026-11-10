import { QueryTypes } from 'sequelize';
import sequelize from '../config/sequelize.js';
import { isValidRfidUid, normalizeRfidUid } from '../utils/rfid-uid.js';

const DEFAULT_DEVICE_ID = 'bookit-bus-reader-001';
const SESSION_MINUTES = 2;
const requireAdmin = (req, res) => {
  if (req.user?.role !== 'admin') { res.status(403).json({ message: 'Administrator access required.' }); return false; }
  return true;
};

export const listMyCards = async (req, res) => {
  try {
    const cards = await sequelize.query(
      `SELECT c.id, c.card_uid AS "cardUid", c.card_token AS "cardToken", c.status, c.registered_at AS "registeredAt",
              rct.ticket_id AS "ticketId", t.ticket_number AS "ticketNumber", rct.travel_date AS "travelDate"
       FROM rfid_cards c
       LEFT JOIN rfid_card_tickets rct ON rct.card_id = c.id
       LEFT JOIN tickets t ON t.id = rct.ticket_id
       WHERE c.user_id = :userId AND c.status = 'active' ORDER BY c.registered_at DESC`,
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
       FROM rfid_registration_sessions WHERE id = :id AND (user_id = :userId OR :isAdmin = TRUE) LIMIT 1`,
      { replacements: { id: req.params.id, userId: req.user.id, isAdmin: req.user.role === 'admin' }, type: QueryTypes.SELECT },
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

export const registerFromPhone = async (req, res) => {
  if (!req.user?.id || !['user', 'admin'].includes(req.user.role)) {
    return res.status(403).json({ message: 'Passenger account access is required to register a card.' });
  }

  const uid = normalizeRfidUid(req.body?.cardUid ?? req.body?.uid);
  if (!isValidRfidUid(uid)) {
    return res.status(400).json({ message: 'Invalid RFID card UID.' });
  }

  try {
    const result = await sequelize.transaction(async (transaction) => {
      const existing = await sequelize.query(
        `SELECT id, user_id, card_uid AS "cardUid", status, registered_at AS "registeredAt"
         FROM rfid_cards WHERE card_uid = :uid LIMIT 1 FOR UPDATE`,
        { replacements: { uid }, type: QueryTypes.SELECT, transaction },
      );

      if (existing.length && existing[0].status === 'active') {
        if (String(existing[0].user_id) !== String(req.user.id)) {
          return { kind: 'duplicate' };
        }
        return { kind: 'already-owned', card: existing[0] };
      }

      let cards;
      if (existing.length) {
        cards = await sequelize.query(
          `UPDATE rfid_cards
           SET user_id = :userId, status = 'active',
               registered_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
           WHERE id = :id
           RETURNING id, card_uid AS "cardUid", card_token AS "cardToken", status, registered_at AS "registeredAt"`,
          {
            replacements: { userId: req.user.id, id: existing[0].id },
            type: QueryTypes.SELECT,
            transaction,
          },
        );
      } else {
        cards = await sequelize.query(
          `INSERT INTO rfid_cards (user_id, card_uid, status)
           VALUES (:userId, :uid, 'active')
           RETURNING id, card_uid AS "cardUid", card_token AS "cardToken", status, registered_at AS "registeredAt"`,
          {
            replacements: { userId: req.user.id, uid },
            type: QueryTypes.SELECT,
            transaction,
          },
        );
      }
      return { kind: 'registered', card: cards[0] };
    });

    if (result.kind === 'duplicate') {
      return res.status(409).json({ message: 'This card is already linked to another passenger.' });
    }
    return res.status(200).json({
      message: result.kind === 'already-owned'
        ? 'This card is already linked to your BookIt account.'
        : 'NFC card registered successfully.',
      card: result.card,
    });
  } catch (error) {
    if (error.original?.code === '23505' || error.name === 'SequelizeUniqueConstraintError') {
      return res.status(409).json({ message: 'This card is already linked to another passenger.' });
    }
    console.error('[RFID] phone registration:', error.message);
    return res.status(500).json({ message: 'Could not register this NFC card.' });
  }
};

export const scanFromReader = async (req, res) => {
  const uid = normalizeRfidUid(req.body?.uid);
  if (!isValidRfidUid(uid)) {
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
