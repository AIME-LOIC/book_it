import { QueryTypes } from 'sequelize';
import sequelize from '../config/sequelize.js';

const todayKigali = () => new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Africa/Kigali', year: 'numeric', month: '2-digit', day: '2-digit',
}).format(new Date());

export const linkTicketToCard = async (req, res) => {
  const ticketId = String(req.body?.ticketId || '').trim();
  if (!ticketId) return res.status(400).json({ message: 'Ticket ID is required.' });

  try {
    const result = await sequelize.transaction(async (transaction) => {
      const cards = await sequelize.query(
        "SELECT id FROM rfid_cards WHERE id = :cardId AND user_id = :userId AND status = 'active' FOR UPDATE",
        { replacements: { cardId: req.params.cardId, userId: req.user.id }, type: QueryTypes.SELECT, transaction },
      );
      if (!cards.length) return { status: 404, message: 'Active travel card not found.' };

      const tickets = await sequelize.query(
        "SELECT id, travel_date FROM tickets WHERE id = :ticketId AND user_id = :userId AND status = 'paid' AND is_used = FALSE AND travel_date >= :today FOR UPDATE",
        { replacements: { ticketId, userId: req.user.id, today: todayKigali() }, type: QueryTypes.SELECT, transaction },
      );
      if (!tickets.length) return { status: 409, message: 'Only your paid, unused and upcoming tickets can be added to a card.' };

      const existing = await sequelize.query(
        'SELECT ticket_id FROM rfid_card_tickets WHERE ticket_id = :ticketId LIMIT 1',
        { replacements: { ticketId }, type: QueryTypes.SELECT, transaction },
      );
      if (existing.length) return { status: 409, message: 'This ticket is already assigned to a card.' };

      const sameDay = await sequelize.query(
        'SELECT ticket_id FROM rfid_card_tickets WHERE card_id = :cardId AND travel_date = :date LIMIT 1',
        { replacements: { cardId: req.params.cardId, date: tickets[0].travel_date }, type: QueryTypes.SELECT, transaction },
      );
      if (sameDay.length) return { status: 409, message: 'This card already has a ticket for that travel date.' };

      await sequelize.query(
        'INSERT INTO rfid_card_tickets(card_id, ticket_id, travel_date) VALUES(:cardId, :ticketId, :date)',
        { replacements: { cardId: req.params.cardId, ticketId, date: tickets[0].travel_date }, transaction },
      );
      return { status: 200, message: 'Ticket added to your BookIt travel card.' };
    });
    return res.status(result.status).json({ message: result.message });
  } catch (error) {
    if (error.original?.code === '23505' || error.name === 'SequelizeUniqueConstraintError') {
      return res.status(409).json({ message: 'This ticket or card already has a travel assignment.' });
    }
    console.error('[TRAVEL CARD] link:', error.message);
    return res.status(500).json({ message: 'Could not add this ticket to the card.' });
  }
};

export const validateTravelCard = async (req, res) => {
  const uid = String(req.body?.card_uid || '').trim().toUpperCase();
  const token = String(req.body?.card_token || '').trim();
  const ticketNumber = String(req.body?.ticket_number || '').trim();
  if (!uid && !token && !ticketNumber) return res.status(400).json({ valid: false, message: 'Card identifier or ticket number is required.' });
  if (!req.user?.bus_id) return res.status(409).json({ valid: false, message: 'No bus is assigned to this driver.' });

  try {
    const result = await sequelize.transaction(async (transaction) => {
      const rows = await sequelize.query(
        `SELECT t.id, t.ticket_number, t.seat_number, t.travel_date,
                u.name AS "passengerName", b.plate_number AS "plateNumber"
         FROM tickets t
         LEFT JOIN rfid_card_tickets rct ON rct.ticket_id = t.id
         LEFT JOIN rfid_cards c ON c.id = rct.card_id AND c.status = 'active' AND c.user_id = t.user_id
         JOIN users u ON u.id = t.user_id
         JOIN buses b ON b.id = t.bus_id
         WHERE (:uid = '' OR c.card_uid = :uid)
           AND (:token = '' OR c.card_token::text = :token)
           AND (:ticketNumber = '' OR UPPER(t.ticket_number) = UPPER(:ticketNumber))
           AND t.bus_id = :busId AND t.travel_date = :date
           AND t.status = 'paid' AND t.is_used = FALSE
         LIMIT 1 FOR UPDATE OF t`,
        { replacements: { uid, token, ticketNumber, busId: req.user.bus_id, date: todayKigali() }, type: QueryTypes.SELECT, transaction },
      );
      if (!rows.length) return { valid: false, reason: 'No unused paid ticket for this card is assigned to your bus today.' };

      const ticket = rows[0];
      const updated = await sequelize.query(
        'UPDATE tickets SET is_used = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = :id AND is_used = FALSE RETURNING id',
        { replacements: { id: ticket.id }, type: QueryTypes.SELECT, transaction },
      );
      if (!updated.length) return { valid: false, reason: 'Ticket was already used.' };

      return {
        valid: true,
        ticket: {
          id: ticket.id, ticket_number: ticket.ticket_number, seat_number: ticket.seat_number,
          travel_date: ticket.travel_date, passenger: ticket.passengerName, plate_number: ticket.plateNumber,
        },
      };
    });
    return res.status(result.valid ? 200 : 409).json(result);
  } catch (error) {
    console.error('[TRAVEL CARD] validate:', error.message);
    return res.status(500).json({ valid: false, message: 'Travel card validation failed.' });
  }
};

export const getOfflineManifest = async (req, res) => {
  if (!req.user?.bus_id) return res.status(409).json({ message: 'No bus is assigned to this driver.' });
  const date = String(req.query.date || todayKigali());
  if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(date)) {
    return res.status(400).json({ message: 'Date must use YYYY-MM-DD.' });
  }

  try {
    const data = await sequelize.transaction(async (transaction) => {
      const [manifest] = await sequelize.query(
        `INSERT INTO offline_ticket_manifests(driver_id, bus_id, travel_date, expires_at)
         VALUES(:driverId, :busId, :date, CURRENT_TIMESTAMP + INTERVAL '8 hours')
         RETURNING id, issued_at AS "issuedAt", expires_at AS "expiresAt"`,
        { replacements: { driverId: req.user.id, busId: req.user.bus_id, date }, type: QueryTypes.SELECT, transaction },
      );

      await sequelize.query(
        `INSERT INTO offline_ticket_manifest_items
          (manifest_id, ticket_id, card_id, card_uid, card_token, ticket_number, seat_number, travel_date, passenger_name)
         SELECT :manifestId, t.id, c.id, c.card_uid, c.card_token, t.ticket_number, t.seat_number, t.travel_date, u.name
         FROM tickets t
         LEFT JOIN rfid_card_tickets rct ON rct.ticket_id = t.id
         LEFT JOIN rfid_cards c ON c.id = rct.card_id AND c.status = 'active' AND c.user_id = t.user_id
         JOIN users u ON u.id = t.user_id
         WHERE t.bus_id = :busId AND t.travel_date = :date
           AND t.status = 'paid' AND t.is_used = FALSE
         ON CONFLICT (manifest_id, ticket_id) DO NOTHING`,
        { replacements: { manifestId: manifest.id, busId: req.user.bus_id, date }, transaction },
      );

      const tickets = await sequelize.query(
        `SELECT ticket_id AS "ticketId", card_uid AS "cardUid", card_token AS "cardToken",
                ticket_number AS "ticketNumber", seat_number AS "seatNumber",
                travel_date AS "travelDate", passenger_name AS "passengerName"
         FROM offline_ticket_manifest_items WHERE manifest_id = :manifestId ORDER BY seat_number`,
        { replacements: { manifestId: manifest.id }, type: QueryTypes.SELECT, transaction },
      );
      return { manifest, tickets };
    });

    res.set('Cache-Control', 'no-store');
    return res.json({
      manifest_id: data.manifest.id, driver_id: req.user.id, bus_id: req.user.bus_id,
      travel_date: date, issued_at: data.manifest.issuedAt, expires_at: data.manifest.expiresAt,
      tickets: data.tickets,
    });
  } catch (error) {
    console.error('[TRAVEL CARD] manifest:', error.message);
    return res.status(500).json({ message: 'Could not prepare the offline passenger list.' });
  }
};

export const syncOfflineValidations = async (req, res) => {
  const manifestId = String(req.body?.manifest_id || '').trim();
  const events = Array.isArray(req.body?.events) ? req.body.events.slice(0, 100) : [];
  if (!manifestId || !events.length) return res.status(400).json({ message: 'Manifest ID and validation events are required.' });
  if (!req.user?.bus_id) return res.status(409).json({ message: 'No bus is assigned to this driver.' });

  const results = [];
  for (const event of events) {
    const eventId = String(event?.event_id || '').trim();
    const ticketId = String(event?.ticket_id || '').trim();
    const scannedAt = new Date(event?.scanned_at);
    const method = ['nfc', 'qr', 'ticket_number'].includes(event?.scan_method) ? event.scan_method : '';
    if (!eventId || !ticketId || !method || Number.isNaN(scannedAt.getTime())) {
      results.push({ event_id: eventId || null, accepted: false, reason: 'Malformed event.' });
      continue;
    }

    try {
      const outcome = await sequelize.transaction(async (transaction) => {
        const prior = await sequelize.query(
          'SELECT v.manifest_id, v.ticket_id, v.scan_method, v.status, v.rejection_reason AS reason, m.driver_id, m.bus_id FROM offline_ticket_validations v JOIN offline_ticket_manifests m ON m.id = v.manifest_id WHERE v.event_id = :eventId LIMIT 1',
          { replacements: { eventId }, type: QueryTypes.SELECT, transaction },
        );
        if (prior.length) {
          const sameEvent = String(prior[0].manifest_id) === manifestId
            && String(prior[0].ticket_id) === ticketId && prior[0].scan_method === method
            && String(prior[0].driver_id) === String(req.user.id)
            && String(prior[0].bus_id) === String(req.user.bus_id);
          return {
            accepted: sameEvent && prior[0].status === 'accepted',
            reason: sameEvent ? (prior[0].reason || 'Already synchronized.') : 'Event ID was already used for a different scan.',
          };
        }

        const manifests = await sequelize.query(
          `SELECT id, travel_date FROM offline_ticket_manifests
           WHERE id = :manifestId AND driver_id = :driverId AND bus_id = :busId
             AND :scannedAt BETWEEN issued_at AND expires_at
             AND CURRENT_TIMESTAMP <= expires_at + INTERVAL '48 hours'
           LIMIT 1 FOR UPDATE`,
          { replacements: { manifestId, driverId: req.user.id, busId: req.user.bus_id, scannedAt }, type: QueryTypes.SELECT, transaction },
        );
        if (!manifests.length) return { accepted: false, reason: 'Offline manifest expired or belongs to another driver.' };

        const linked = await sequelize.query(
          `SELECT t.id FROM offline_ticket_manifest_items mi
           JOIN tickets t ON t.id = mi.ticket_id
           LEFT JOIN rfid_card_tickets rct ON rct.ticket_id = t.id AND rct.card_id = mi.card_id
           LEFT JOIN rfid_cards c ON c.id = mi.card_id AND c.status = 'active' AND c.user_id = t.user_id
           WHERE mi.manifest_id = :manifestId AND mi.ticket_id = :ticketId
             AND t.bus_id = :busId AND t.travel_date = :date AND t.status = 'paid'
             AND (:method IN ('ticket_number', 'qr') OR (rct.ticket_id IS NOT NULL AND c.id IS NOT NULL))`,
          { replacements: { manifestId, ticketId, busId: req.user.bus_id, date: manifests[0].travel_date, method }, type: QueryTypes.SELECT, transaction },
        );

        let accepted = false;
        let reason = null;
        if (!linked.length) {
          reason = 'Ticket was not in the downloaded manifest or is no longer valid.';
        } else {
          const updated = await sequelize.query(
            `UPDATE tickets SET is_used = TRUE, updated_at = CURRENT_TIMESTAMP
             WHERE id = :ticketId AND bus_id = :busId AND status = 'paid' AND is_used = FALSE
             RETURNING id`,
            { replacements: { ticketId, busId: req.user.bus_id }, type: QueryTypes.SELECT, transaction },
          );
          accepted = updated.length > 0;
          if (!accepted) reason = 'Ticket was already used or is no longer valid.';
        }

        await sequelize.query(
          `INSERT INTO offline_ticket_validations
            (event_id, manifest_id, ticket_id, scan_method, scanned_at, status, rejection_reason)
           VALUES(:eventId, :manifestId, :ticketId, :method, :scannedAt, :status, :reason)`,
          { replacements: { eventId, manifestId, ticketId, method, scannedAt, status: accepted ? 'accepted' : 'rejected', reason }, transaction },
        );
        return { accepted, reason };
      });
      results.push({ event_id: eventId, ...outcome });
    } catch (error) {
      console.error('[TRAVEL CARD] sync:', error.message);
      results.push({ event_id: eventId, accepted: false, reason: 'Could not synchronize this scan.' });
    }
  }
  return res.json({
    results, accepted: results.filter((item) => item.accepted).length,
    rejected: results.filter((item) => !item.accepted).length,
  });
};
