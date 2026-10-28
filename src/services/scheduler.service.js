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

// ── REACTIVATE ALL BUSES AT MIDNIGHT (runs every 60s, triggers once) ─────────
let lastReactivationDate = null;
let lastPromoGenerationDate = null;
let lastTicketArchiveDate = null;
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
