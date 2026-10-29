import Bus      from '../database/models/bus.js';
import Operator from '../database/models/operator.js';
import Route    from '../database/models/route.js';
import Location from '../database/models/location.js';
import Ticket from '../database/models/ticket.js';
import RouteStop from '../database/models/route_stop.js';
import { createMany } from './notification.service.js';
import { generateDailyLoyaltyPromo } from './promo.service.js';
import { Op } from 'sequelize';
import PromoCode from '../database/models/promo_code.js';
import TicketArchive from '../database/models/ticket_archive.js';
import Notification from '../database/models/notification.js';

// ── DEACTIVATE DEPARTED BUSES (runs every 60s) ────────────────
export const checkDepartedBuses = async () => {
  const now = new Date();

  const activeBuses = await Bus.findAll({
    where: { is_active: true },
    include: [
      { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
      {
        model: Route, as: 'route', attributes: ['id', 'price'],
        include: [
          { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
          { model: Location, as: 'toLocation',   attributes: ['id', 'name'] },
        ],
      },
    ],
  });

  for (const bus of activeBuses) {
    const [h, m] = String(bus.departure_time).split(':').map(Number);
    const dep = new Date();
    dep.setHours(h, m, 0, 0);

    if (now >= dep) {
      await bus.update({ is_active: false });

      const from = bus.route?.fromLocation?.name || '?';
      const to   = bus.route?.toLocation?.name   || '?';

      await createMany([{
        recipient_id:   bus.operator_id,
        recipient_type: 'operator',
        type:           'bus_departed',
        message:        `Bus ${bus.plate_number} (${from} → ${to}) has departed at ${String(bus.departure_time).slice(0,5)}. It will be reactivated tomorrow.`,
        meta:           { bus_id: bus.id, plate: bus.plate_number },
      }]);

      // Notify passengers with paid tickets for this bus on today's service.
      // The bus is deactivated above, so this block runs only once per service day.
      const today = now.toISOString().split('T')[0];
      const passengers = await Ticket.findAll({
        where: { bus_id: bus.id, travel_date: today, status: 'paid' },
        attributes: ['id', 'user_id', 'seat_number', 'travel_date'],
      });
      if (passengers.length) {
        try {
          await createMany(passengers.map(ticket => ({
            recipient_id: ticket.user_id,
            recipient_type: 'user',
            type: 'bus_departed',
            message: `Your bus ${bus.plate_number} (${from} → ${to}) has reached its scheduled departure time.`,
            meta: { bus_id: bus.id, ticket_id: ticket.id, seat_number: ticket.seat_number, travel_date: ticket.travel_date },
          })));
        } catch (err) {
          console.error('[Scheduler] Bus departed but passenger notifications failed:', err?.stack || err);
        }
      }

      console.log(`[Scheduler] Bus ${bus.plate_number} deactivated — departed at ${String(bus.departure_time).slice(0,5)}`);
    }
  }
};


// ── PENDING RESERVATION HOLDS (runs every 60s) ──────────────────
// Use createdAt: payment attempts update updatedAt but must not reset the 15-minute hold.
export const checkPendingTicketHolds = async () => {
  const now = Date.now();
  const expiry = new Date(now - 15 * 60 * 1000);
  const warningStart = new Date(now - 13 * 60 * 1000);
  const warningEnd = new Date(now - 12 * 60 * 1000);

  const expiringSoon = await Ticket.findAll({
    where: {
      status: 'pending',
      createdAt: { [Op.lte]: warningEnd, [Op.gt]: warningStart },
      payment_reference: null,
      flw_charge_id: null,
    },
    attributes: ['id', 'user_id', 'seat_number', 'travel_date', 'createdAt'],
  });

  const recentWarnings = expiringSoon.length
    ? await Notification.findAll({
        where: {
          recipient_id: { [Op.in]: [...new Set(expiringSoon.map((ticket) => ticket.user_id))] },
          recipient_type: 'user',
          type: 'ticket_expiring_soon',
          createdAt: { [Op.gte]: new Date(now - 24 * 60 * 60 * 1000) },
        },
        attributes: ['meta'],
      })
    : [];
  const warned = new Set(recentWarnings.map((notification) => notification.meta?.ticket_id).filter(Boolean));
  const warnings = expiringSoon.filter((ticket) => !warned.has(ticket.id)).map((ticket) => ({
    recipient_id: ticket.user_id,
    recipient_type: 'user',
    type: 'ticket_expiring_soon',
    message: `Only 3 minutes remain to pay for seat ${ticket.seat_number}. BookIt will cancel this reservation when the 15-minute hold expires.`,
    meta: { ticket_id: ticket.id, seat_number: ticket.seat_number, expires_at: new Date(new Date(ticket.createdAt).getTime() + 15 * 60 * 1000).toISOString(), temporary: true },
  }));
  if (warnings.length) await createMany(warnings);

  const expired = await Ticket.findAll({
    where: {
      status: 'pending',
      createdAt: { [Op.lte]: expiry },
      payment_reference: null,
      flw_charge_id: null,
    },
    limit: 200,
  });
  for (const ticket of expired) {
    // Recheck before mutation so a concurrent payment attempt is not overwritten.
    const fresh = await Ticket.findByPk(ticket.id);
    if (!fresh || fresh.status !== 'pending' || fresh.payment_reference || fresh.flw_charge_id ||
        new Date(fresh.createdAt).getTime() > expiry.getTime()) continue;
    await fresh.update({ status: 'cancelled' });
    await createMany([{
      recipient_id: fresh.user_id,
      recipient_type: 'user',
      type: 'ticket_expired',
      message: `Your unpaid reservation for seat ${fresh.seat_number} expired after 15 minutes and was cancelled.`,
      meta: { ticket_id: fresh.id, seat_number: fresh.seat_number },
    }]);
  }
};

// ── DEPARTURE REMINDERS: 30, 15 AND 5 MINUTES BEFORE ───────────
export const notifyUpcomingDepartures = async () => {
  const now = new Date();
  const today = now.toISOString().slice(0, 10);
  const tickets = await Ticket.findAll({
    where: { status: 'paid', travel_date: today },
    include: [{ model: Bus, as: 'bus', attributes: ['id', 'plate_number', 'departure_time'] }],
    attributes: ['id', 'user_id', 'bus_id', 'seat_number', 'travel_date'],
  });
  if (!tickets.length) return;

  const recent = await Notification.findAll({
    where: {
      recipient_id: { [Op.in]: [...new Set(tickets.map((ticket) => ticket.user_id))] },
      recipient_type: 'user',
      type: 'trip_departure_reminder',
      createdAt: { [Op.gte]: new Date(now.getTime() - 24 * 60 * 60 * 1000) },
    },
    attributes: ['meta'],
  });
  const alreadySent = new Set(recent.map((notification) =>
    notification.meta?.ticket_id && notification.meta?.minutes_before
      ? `${notification.meta.ticket_id}:${notification.meta.minutes_before}`
      : null,
  ).filter(Boolean));
  const reminders = [];
  for (const ticket of tickets) {
    if (!ticket.bus?.departure_time) continue;
    const [hours, minutes] = String(ticket.bus.departure_time).split(':').map(Number);
    const departure = new Date(now);
    departure.setHours(hours, minutes, 0, 0);
    const remainingMs = departure.getTime() - now.getTime();
    if (remainingMs <= 0) continue;
    for (const target of [30, 15, 5]) {
      if (remainingMs <= target * 60000 && remainingMs > (target - 1) * 60000 &&
          !alreadySent.has(`${ticket.id}:${target}`)) {
        reminders.push({
          recipient_id: ticket.user_id,
          recipient_type: 'user',
          type: 'trip_departure_reminder',
          message: `Your bus ${ticket.bus.plate_number} departs in ${target} minutes. Be at the station on time (seat ${ticket.seat_number}).`,
          meta: { ticket_id: ticket.id, bus_id: ticket.bus_id, minutes_before: target, seat_number: ticket.seat_number },
        });
      }
    }
  }
  if (reminders.length) await createMany(reminders);
};

// Permanently remove notifications older than 60 days.
export const cleanupOldNotifications = async () => {
  const today = new Date().toISOString().slice(0, 10);
  if (lastNotificationCleanupDate === today) return;
  lastNotificationCleanupDate = today;
  try {
    const cutoff = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);
    const deleted = await Notification.destroy({ where: { createdAt: { [Op.lt]: cutoff } } });
    if (deleted) console.log(`[Notifications] Deleted ${deleted} notification(s) older than 60 days.`);
  } catch (error) {
    lastNotificationCleanupDate = null;
    console.error('[Notifications] Retention cleanup failed:', error?.message || error);
  }
};

// ── REACTIVATE ALL BUSES AT MIDNIGHT (runs every 60s, triggers once) ─────────
let lastReactivationDate = null;
let lastPromoGenerationDate = null;
let lastTicketArchiveDate = null;
let lastNotificationCleanupDate = null;
let ticketArchiveTableReady = false;

// Archive only completed/cancelled trips after 365 days. The full ticket row
// is copied to ticket_archives inside the same transaction before deletion.
export const archiveOldTickets = async () => {
  const today = new Date().toISOString().slice(0, 10);
  if (lastTicketArchiveDate === today) return;
  lastTicketArchiveDate = today;

  const retentionDays = Math.max(365, Number.parseInt(process.env.BOOKIT_TICKET_RETENTION_DAYS || '365', 10) || 365);
  const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

  try {
    // The API listener can start before the server bootstrap's database check;
    // ensure the backup table exists before this job reads or deletes anything.
    if (!ticketArchiveTableReady) {
      await TicketArchive.sync();
      ticketArchiveTableReady = true;
    }
    const candidates = await Ticket.findAll({
      where: {
        status: { [Op.in]: ['paid', 'cancelled'] },
        travel_date: { [Op.lt]: cutoff },
      },
      order: [['travel_date', 'ASC']],
      limit: 100,
    });

    let archived = 0;
    for (const candidate of candidates) {
      try {
        await Ticket.sequelize.transaction(async (transaction) => {
          const ticket = await Ticket.findByPk(candidate.id, {
            transaction,
            lock: { level: transaction.LOCK.UPDATE, of: Ticket },
            include: [
              {
                model: Bus, as: 'bus',
                attributes: ['id', 'plate_number', 'driver_name', 'departure_time', 'capacity'],
                include: [{
                  model: Route, as: 'route', attributes: ['id', 'price'],
                  include: [
                    { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
                    { model: Location, as: 'toLocation', attributes: ['id', 'name'] },
                  ],
                }],
              },
              { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
              {
                model: RouteStop, as: 'boardingStop',
                attributes: ['id', 'stop_order', 'price_from_origin'],
                include: [{ model: Location, as: 'location', attributes: ['id', 'name'] }],
              },
              {
                model: RouteStop, as: 'dropoffStop',
                attributes: ['id', 'stop_order', 'price_from_origin'],
                include: [{ model: Location, as: 'location', attributes: ['id', 'name'] }],
              },
            ],
          });
          if (!ticket || !['paid', 'cancelled'].includes(ticket.status) || String(ticket.travel_date) >= cutoff) return;

          await TicketArchive.findOrCreate({
            where: { original_ticket_id: ticket.id },
            defaults: {
              original_ticket_id: ticket.id,
              user_id: ticket.user_id,
              travel_date: ticket.travel_date,
              status: ticket.status,
              ticket_number: ticket.ticket_number,
              ticket_snapshot: ticket.toJSON(),
              archived_at: new Date(),
            },
            transaction,
          });

          // promo_codes.ticket_id references live tickets; preserve its ticket
          // identifier inside the immutable JSON backup before releasing the FK.
          await PromoCode.update(
            { ticket_id: null },
            { where: { ticket_id: ticket.id }, transaction },
          );

          await ticket.destroy({ transaction });
          archived += 1;
        });
      } catch (err) {
        // Never delete a ticket if its backup or dependent-row update fails.
        console.error('[TicketArchive] Ticket kept because archive failed:', candidate.id, err?.message || err);
      }
    }

    if (archived) console.log(`[TicketArchive] Backed up and archived ${archived} old ticket(s) before deletion.`);
  } catch (err) {
    lastTicketArchiveDate = null; // retry on the next scheduler tick
    console.error('[TicketArchive] Daily archive job failed:', err?.message || err);
  }
};

export const checkMidnightReactivation = async () => {
  const now   = new Date();
  const today = now.toISOString().split('T')[0];

  // only run once per day, between 00:00 and 00:01
  if (now.getHours() !== 0 || now.getMinutes() > 1) return;
  if (lastReactivationDate === today) return;

  lastReactivationDate = today;

  const inactiveBuses = await Bus.findAll({
    where: { is_active: false },
  });

  for (const bus of inactiveBuses) {
    await bus.update({ is_active: true });
    console.log(`[Scheduler] Bus ${bus.plate_number} reactivated for ${today}`);
  }

  if (inactiveBuses.length > 0) {
    console.log(`[Scheduler] ${inactiveBuses.length} bus(es) reactivated for ${today}`);
  }
};

export const checkPromoCodeGeneration = async () => {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  if (lastPromoGenerationDate === today) return;
  lastPromoGenerationDate = today;

  try {
    const result = await generateDailyLoyaltyPromo(now);
    if (result) {
      console.log(`[Scheduler] Promo code generated for ${result.user?.name || result.user?.email || 'top buyer'}: ${result.promoCode.code}`);
    }
  } catch (err) {
    console.error('[Scheduler] Promo generation failed', err.message);
  }
};
