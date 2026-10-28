import { Op } from 'sequelize';
import Ticket from '../database/models/ticket.js';
import Bus from '../database/models/bus.js';
import Route from '../database/models/route.js';
import RouteStop from '../database/models/route_stop.js';
import Operator from '../database/models/operator.js';
import Location from '../database/models/location.js';
import User from '../database/models/user.js';
import Driver from '../database/models/driver.js';
import { createMany } from './notification.service.js';
import { validateAndConsumePromoCode } from './promo.service.js';
import {
  generateTicketNumber,
  generateQRToken,
  generateQRImage,
  verifyQRToken,
} from '../utils/ticket.utils.js';
import {
  initiateMobileMoneyCharge,
  getCharge,
  verifyWebhookSignature,
  FLW_SUCCESS_STATUSES,
  FLW_FAILED_STATUSES,
} from './flutter.service.js';

const ticketIncludes = [
  {
    model: Bus, as: 'bus',
    attributes: ['id', 'plate_number', 'driver_name', 'departure_time', 'capacity', 'last_lat', 'last_lng', 'amenities'],
    include: [{
      model: Route, as: 'route', attributes: ['id', 'price'],
      include: [
        { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
        { model: Location, as: 'toLocation', attributes: ['id', 'name'] },
      ],
    }],
  },
  { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
  { model: User, as: 'user', attributes: ['id', 'name', 'email', 'phone'] },
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
];

// ── TIME CHECK ────────────────────────────────────────
const isStillAvailable = (departure_time, travel_date) => {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  if (travel_date > today) return true;
  if (travel_date < today) return false;
  const [h, m] = String(departure_time).split(':').map(Number);
  const dep = new Date();
  dep.setHours(h, m, 0, 0);
  return dep > now;
};

// ── SEAT AVAILABILITY ─────────────────────────────────
const PENDING_TIMEOUT_MINUTES = 15;
const PENDING_HOLD_CUTOFF = () => new Date(Date.now() - PENDING_TIMEOUT_MINUTES * 60000);

// The provider is authoritative for payment state. Whenever it returns
// transaction details, reject mismatched reference, amount or currency.
const assertChargeMatchesTicket = (charge, ticket) => {
  if (charge?.reference && ticket.payment_reference && String(charge.reference) !== String(ticket.payment_reference)) {
    throw new Error('Payment reference does not match this reservation');
  }
  if (charge?.amount != null && Number.isFinite(Number(charge.amount)) &&
      Math.round(Number(charge.amount)) !== Math.round(Number(ticket.price))) {
    throw new Error('Payment amount does not match this reservation');
  }
  if (charge?.currency && String(charge.currency).toUpperCase() !== 'RWF') {
    throw new Error('Payment currency does not match this reservation');
  }
};

// segments overlap if existing boarding < new dropoff AND existing dropoff > new boarding
const segmentsOverlap = (existingBoarding, existingDropoff, newBoarding, newDropoff) => {
  const eb = Number(existingBoarding);
  const ed = Number(existingDropoff);
  const nb = Number(newBoarding);
  const nd = Number(newDropoff);
  return eb < nd && ed > nb;
};

const isSeatFree = async (bus_id, travel_date, seat_number, boarding_order, dropoff_order, transaction = null, excludeTicketId = null) => {
  const conflicts = await Ticket.findAll({
    where: {
      bus_id, travel_date, seat_number,
      ...(excludeTicketId ? { id: { [Op.ne]: excludeTicketId } } : {}),
      [Op.or]: [
        { status: 'paid' },
        { status: 'pending', updatedAt: { [Op.gt]: PENDING_HOLD_CUTOFF() } }
      ]
    },
    include: [
      { model: RouteStop, as: 'boardingStop', attributes: ['stop_order'] },
      { model: RouteStop, as: 'dropoffStop', attributes: ['stop_order'] },
    ],
    ...(transaction ? {
      transaction,
      // Lock only the tickets table. The RouteStop includes are LEFT OUTER
      // JOINs; PostgreSQL rejects FOR UPDATE across their nullable side.
      lock: { level: transaction.LOCK.UPDATE, of: Ticket },
    } : {}),
  });

  for (const t of conflicts) {
    if (segmentsOverlap(t.boardingStop.stop_order, t.dropoffStop.stop_order, boarding_order, dropoff_order)) {
      return false;
    }
  }
  return true;
};

const getSegmentSeats = async (bus, travel_date, boarding_order, dropoff_order) => {
  const conflicts = await Ticket.findAll({
    where: {
      bus_id: bus.id, travel_date,
      [Op.or]: [
        { status: 'paid' },
        { status: 'pending', updatedAt: { [Op.gt]: PENDING_HOLD_CUTOFF() } }
      ]
    },
    include: [
      { model: RouteStop, as: 'boardingStop', attributes: ['stop_order'] },
      { model: RouteStop, as: 'dropoffStop', attributes: ['stop_order'] },
    ],
  });

  const takenSeats = new Set();
  for (const t of conflicts) {
    if (segmentsOverlap(t.boardingStop.stop_order, t.dropoffStop.stop_order, boarding_order, dropoff_order)) {
      takenSeats.add(t.seat_number);
    }
  }

  const available = [];
  const taken = [];
  for (let seat = 1; seat <= bus.capacity; seat++) {
    if (takenSeats.has(seat)) taken.push(seat);
    else available.push(seat);
  }
  return { available, taken };
};

// ── SEARCH ────────────────────────────────────────────
export const searchBuses = async ({ from_location_id, to_location_id, travel_date }) => {
  // load all stops raw
  const allStops = await RouteStop.findAll({ raw: true });

  const fromStops = allStops.filter(s => s.location_id === from_location_id);
  const toStops = allStops.filter(s => s.location_id === to_location_id);

  if (!fromStops.length || !toStops.length) {
    throw new Error(
      `Stop not found in DB. ` +
      `Searching from: "${from_location_id}" to: "${to_location_id}". ` +
      `DB has: [${[...new Set(allStops.map(s => s.location_id))].join(', ')}]`
    );
  }

  // group stops by route
  const byRoute = {};
  allStops.forEach(s => {
    if (!byRoute[s.route_id]) byRoute[s.route_id] = [];
    byRoute[s.route_id].push(s);
  });

  const validRoutes = [];
  for (const [route_id, stops] of Object.entries(byRoute)) {
    const fromStop = stops.find(s => s.location_id === from_location_id);
    const toStop = stops.find(s => s.location_id === to_location_id);
    if (!fromStop || !toStop) continue;
    if (fromStop.stop_order >= toStop.stop_order) continue;

    validRoutes.push({
      route_id,
      boarding_stop_id: fromStop.id,
      dropoff_stop_id: toStop.id,
      boarding_order: fromStop.stop_order,
      dropoff_order: toStop.stop_order,
      price: parseFloat(
        (parseFloat(toStop.price_from_origin) - parseFloat(fromStop.price_from_origin)).toFixed(2)
      ),
    });
  }

  if (!validRoutes.length) {
    const details = Object.entries(byRoute).map(([rid, stops]) => {
      const f = stops.find(s => s.location_id === from_location_id);
      const t = stops.find(s => s.location_id === to_location_id);
      return `Route ${rid}: fromFound=${!!f} toFound=${!!t}${f && t ? ` orders:${f.stop_order}→${t.stop_order}` : ''}`;
    }).join(' | ');
    throw new Error(`No valid route. Debug: ${details}`);
  }

  const route_ids = validRoutes.map(r => r.route_id);
  const locationRows = await Location.findAll({ attributes: ['id', 'name'], raw: true });
  const locationNames = new Map(locationRows.map(location => [location.id, location.name]));
  const buses = await Bus.findAll({
    where: { route_id: { [Op.in]: route_ids }, is_active: true },
    include: [
      { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
      {
        model: Route, as: 'route', attributes: ['id', 'price'],
        include: [
          { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
          { model: Location, as: 'toLocation', attributes: ['id', 'name'] },
        ],
      },
    ],
  });

  if (!buses.length) throw new Error('Route found but no buses assigned to it yet.');

  const results = await Promise.all(buses.map(async (bus) => {
    const routeInfo = validRoutes.find(r => r.route_id === bus.route_id);
    const { available, taken } = await getSegmentSeats(
      bus, travel_date, routeInfo.boarding_order, routeInfo.dropoff_order
    );

    return {
      bus_id: bus.id,
      plate_number: bus.plate_number,
      driver_name: bus.driver_name,
      departure_time: bus.departure_time,
      capacity: bus.capacity,
      available_seats: available,
      amenities: bus.amenities || [],
      last_location: bus.last_lat ? { lat: bus.last_lat, lng: bus.last_lng } : null,
      taken_seats: taken,
      price: routeInfo.price,
      boarding_stop_id: routeInfo.boarding_stop_id,
      dropoff_stop_id: routeInfo.dropoff_stop_id,
      // Return the exact ordered stops for the passenger's selected segment.
      route_stops: (byRoute[routeInfo.route_id] || [])
        .filter(stop => stop.stop_order >= routeInfo.boarding_order && stop.stop_order <= routeInfo.dropoff_order)
        .sort((a, b) => a.stop_order - b.stop_order)
        .map(stop => ({
          id: stop.id,
          stop_order: stop.stop_order,
          location_id: stop.location_id,
          name: locationNames.get(stop.location_id) || 'Stop',
          price_from_origin: Number(stop.price_from_origin || 0),
        })),
      operator: bus.operator,
      route: bus.route,
    };
  }));

  return results.filter(b => b !== null && b.available_seats.length > 0);
};

// ── BOOK ──────────────────────────────────────────────
export const bookTicket = async (user_id, { bus_id, seat_number, boarding_stop_id, dropoff_stop_id, travel_date }) => {
  const user = await User.findByPk(user_id);
  if (!user) throw new Error('User not found (invalid token)');

  const bus = await Bus.findByPk(bus_id);
  if (!bus) throw new Error('Bus not found');

  // time check
  if (!isStillAvailable(bus.departure_time, travel_date)) {
    throw new Error('This bus has already departed');
  }

  const boardingStop = await RouteStop.findByPk(boarding_stop_id);
  const dropoffStop = await RouteStop.findByPk(dropoff_stop_id);
  if (!boardingStop || !dropoffStop) throw new Error('Invalid stops');
  if (boardingStop.stop_order >= dropoffStop.stop_order) throw new Error('Invalid stop order');
  // stops must belong to the route this bus travels — prevents cross-route
  // price manipulation (e.g. mixing stops from a cheaper route)
  if (boardingStop.route_id !== bus.route_id || dropoffStop.route_id !== bus.route_id) {
    throw new Error('Stops do not belong to this bus route');
  }

  if (seat_number < 1 || seat_number > bus.capacity) {
    throw new Error(`Seat must be between 1 and ${bus.capacity}`);
  }

  const price = parseFloat(
    (parseFloat(dropoffStop.price_from_origin) - parseFloat(boardingStop.price_from_origin)).toFixed(2)
  );
  if (!(price >= 0)) throw new Error('Invalid price for this segment');

  // ── CONCURRENCY-SAFE RESERVATION ──────────────────────
  // Availability checks without this transaction are advisory only. Here we
  // serialize every booking for this bus on a transaction holding a row lock
  // on the bus (works on MySQL InnoDB and Postgres): a second conflicting
  // booking waits for the first to commit, then its re-check sees the
  // pending ticket and fails — so two overlapping reservations can never
  // both succeed.
  const sequelize = Ticket.sequelize;
  const ticket = await sequelize.transaction(async (t) => {
    const lockedBus = await Bus.findByPk(bus_id, { transaction: t, lock: t.LOCK.UPDATE });
    if (!lockedBus) throw new Error('Bus not found');

    const free = await isSeatFree(
      bus_id, travel_date, seat_number,
      boardingStop.stop_order, dropoffStop.stop_order, t
    );
    if (!free) throw new Error(`Seat ${seat_number} is taken for this segment`);

    return await Ticket.create({
      user_id,
      bus_id,
      operator_id: bus.operator_id,
      boarding_stop_id,
      dropoff_stop_id,
      seat_number,
      travel_date,
      price,
      status: 'pending',
    }, { transaction: t });
  });

  const full = await Ticket.findByPk(ticket.id, { include: ticketIncludes });

  // A reservation is already committed at this point. Notification failures
  // must never turn a successful booking into an HTTP 400 response, which
  // would make the mobile client believe the seat was not reserved.
  try {
    await createMany([
      {
        recipient_id: user_id,
        recipient_type: 'user',
        type: 'ticket_booked',
        message: `Ticket booked! Seat ${seat_number} from ${full.boardingStop.location.name} → ${full.dropoffStop.location.name} on ${travel_date}. Price: ${price} RWF. Please pay to confirm.`,
        meta: { ticket_id: ticket.id, bus_id, travel_date, seat_number, price },
      },
      {
        recipient_id: bus.operator_id,
        recipient_type: 'operator',
        type: 'new_booking',
        message: `New booking on bus ${bus.plate_number} — seat ${seat_number} boarding at ${full.boardingStop.location.name} for ${travel_date}.`,
        meta: { ticket_id: ticket.id, bus_id, travel_date, seat_number },
      },
    ]);
  } catch (err) {
    console.error('[BOOKING] Ticket created but user/operator notifications failed:', err?.stack || err);
  }

  try {
    const driver = await Driver.findOne({ where: { bus_id } });
    if (driver) {
      await createMany([{
        recipient_id: driver.id,
        recipient_type: 'driver',
        type: 'new_booking',
        message: `Seat ${seat_number} reserved — passenger boards at ${full.boardingStop.location.name}, exits at ${full.dropoffStop.location.name}.`,
        meta: { ticket_id: ticket.id, seat_number, boarding: full.boardingStop.location.name, dropoff: full.dropoffStop.location.name },
      }]);
    }
  } catch (err) {
    console.error('[BOOKING] Ticket created but driver notification failed:', err?.stack || err);
  }

  return full;
};

// ── PAY (STEP 1: INITIATE) ─────────────────────────────
// Kicks off a real MTN / Airtel mobile money charge via Flutterwave.
// This does NOT mark the ticket as paid — mobile money is asynchronous:
// the customer gets a USSD/push prompt on their phone and has to approve
// it. The ticket stays 'pending' with a payment reference attached until
// either the webhook fires (preferred) or the frontend polls
// checkPaymentStatus().
//
// REQUIRES a migration adding these columns to `tickets`:
//   payment_reference   STRING
//   flw_customer_id     STRING
//   flw_payment_method_id STRING
//   flw_charge_id       STRING
//   payment_network     STRING   ('mtn' | 'airtel')
export const payTicket = async (user_id, ticket_id, { network, phone_number, promo_code } = {}) => {
  const ticket = await Ticket.findOne({ where: { id: ticket_id, user_id } });
  if (!ticket) throw new Error('Ticket not found');
  if (ticket.status === 'paid') throw new Error('Ticket already paid');
  if (ticket.status === 'cancelled') throw new Error('Ticket is cancelled');

  // A repeated mobile-money request must reuse the active charge instead of
  // creating a second charge for the same reservation.
  if (ticket.flw_charge_id) {
    if (promo_code) {
      throw new Error('A mobile-money payment is already associated with this reservation. Check its status before applying a promo code.');
    }
    const existingCharge = await getCharge(ticket.flw_charge_id);
    assertChargeMatchesTicket(existingCharge, ticket);
    const existingStatus = String(existingCharge.status || '').toLowerCase();

    if (FLW_SUCCESS_STATUSES.includes(existingStatus)) {
      const finalized = await finalizeTicketPayment(ticket.id);
      return { status: 'paid', ticket: finalized };
    }

    if (!FLW_FAILED_STATUSES.includes(existingStatus)) {
      return {
        status: existingStatus || 'pending',
        reference: ticket.payment_reference,
        charge_id: ticket.flw_charge_id,
        next_action: existingCharge.next_action || null,
        message: 'A payment request is already active. Approve it on your phone or check its status before trying again.',
      };
    }

    // The provider has definitively failed/expired the previous attempt.
    // Clear its active identifiers so the passenger can safely retry.
    await ticket.update({
      payment_reference: null,
      flw_payment_method_id: null,
      flw_charge_id: null,
      payment_network: null,
    });
  }

  if (promo_code && ticket.payment_reference && !ticket.flw_charge_id) {
    throw new Error('A mobile-money payment request is being initialized. Check its status before applying a promo code.');
  }

  if (promo_code) {
    await validateAndConsumePromoCode({ code: promo_code, recipient_id: user_id, ticket_id: ticket.id });
    const finalized = await finalizeTicketPayment(ticket.id);
    return { status: 'paid', ticket: finalized, message: 'Promo code applied successfully.' };
  }

  if (!network || !phone_number) {
    throw new Error('network ("mtn" or "airtel") and phone_number are required');
  }

  const user = await User.findByPk(user_id);
  if (!user) throw new Error('User not found');

  const shortId = String(ticket.id).replace(/-/g, '').slice(0, 12);
  const reference = 'bk-' + shortId + '-' + Date.now();

  // Claim payment initiation under a row lock. This prevents simultaneous API
  // requests from creating two Flutterwave charges for one reservation.
  const claim = await Ticket.sequelize.transaction(async (transaction) => {
    const locked = await Ticket.findOne({
      where: { id: ticket_id, user_id },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });
    if (!locked) throw new Error('Ticket not found');
    if (locked.status === 'paid') return { kind: 'paid' };
    if (locked.status === 'cancelled') throw new Error('Ticket is cancelled');
    if (locked.flw_charge_id) {
      return { kind: 'existing', reference: locked.payment_reference, charge_id: locked.flw_charge_id };
    }
    if (locked.payment_reference) {
      const updatedAt = locked.updatedAt ? new Date(locked.updatedAt).getTime() : 0;
      const claimAge = Date.now() - updatedAt;
      if (claimAge < 60_000) {
        return { kind: 'processing', reference: locked.payment_reference };
      }
      // Recover a stale claim left by a process that died before creating a
      // provider charge. The old reference remains in application logs.
      await locked.update({ payment_reference: null, payment_network: null }, { transaction });
    }
    await locked.update({
      payment_reference: reference,
      payment_network: network.toLowerCase(),
    }, { transaction });
    return { kind: 'claimed' };
  });

  if (claim.kind === 'paid') {
    return { status: 'paid', ticket: await getTicketById(user_id, ticket_id) };
  }
  if (claim.kind === 'processing' || claim.kind === 'existing') {
    return {
      status: 'processing',
      reference: claim.reference,
      charge_id: claim.charge_id || null,
      message: 'A payment request is already being processed. Wait for its status before trying again.',
    };
  }

  let chargeResult;
  try {
    chargeResult = await initiateMobileMoneyCharge({
      user,
      network,
      phone_number,
      amount: Math.round(Number(ticket.price)),
      reference,
      meta: { ticket_id: ticket.id, user_id },
      existing_customer_id: user.flw_customer_id || null,
    });
  } catch (err) {
    // Release only our own claim so a later retry can proceed safely.
    await Ticket.update(
      { payment_reference: null, payment_network: null },
      { where: { id: ticket.id, user_id, payment_reference: reference, flw_charge_id: null } },
    );
    throw err;
  }
  const { customer, paymentMethod, charge } = chargeResult;

  // remember this customer on the user, not the ticket — one Flutterwave
  // customer per person, reused across every future ticket they buy
  if (!user.flw_customer_id) {
    await user.update({ flw_customer_id: customer.id });
  }

  await ticket.update({
    payment_reference: reference,
    flw_customer_id: customer.id,
    flw_payment_method_id: paymentMethod.id,
    flw_charge_id: charge.id,
    payment_network: network.toLowerCase(),
  });

  if (FLW_SUCCESS_STATUSES.includes(charge.status)) {
    const finalized = await finalizeTicketPayment(ticket.id);
    return { status: 'paid', ticket: finalized };
  }

  return {
    status: charge.status,
    reference,
    charge_id: charge.id,
    next_action: charge.next_action || null,
    message: `Approve the payment prompt sent to your ${network.toUpperCase()} number to confirm.`,
  };
};

// ── PAY (STEP 2: CHECK / CONFIRM) ──────────────────────
// Frontend polls this (e.g. every 5-8s) after initiating payment, since
// mobile money confirmation isn't instant. Safe to call repeatedly.
export const checkPaymentStatus = async (user_id, ticket_id) => {
  const ticket = await Ticket.findOne({ where: { id: ticket_id, user_id } });
  if (!ticket) throw new Error('Ticket not found');

  if (ticket.status === 'paid') {
    return { status: 'paid', ticket: await getTicketById(user_id, ticket_id) };
  }
  if (ticket.status === 'cancelled') {
    return { status: 'cancelled' };
  }
  if (!ticket.flw_charge_id) {
    return { status: ticket.payment_reference ? 'processing' : 'not_initiated' };
  }

  const charge = await getCharge(ticket.flw_charge_id);
  assertChargeMatchesTicket(charge, ticket);
  const providerStatus = String(charge.status || '').toLowerCase();

  if (FLW_SUCCESS_STATUSES.includes(providerStatus)) {
    const finalized = await finalizeTicketPayment(ticket.id);
    return { status: 'paid', ticket: finalized };
  }

  if (FLW_FAILED_STATUSES.includes(providerStatus)) {
    return { status: 'failed', reason: charge.failure_reason || providerStatus };
  }

  return { status: providerStatus || 'pending' };
};

// ── PAY (WEBHOOK) ───────────────────────────────────────
// Wire this into a route like: POST /webhooks/flutterwave
// router.post('/webhooks/flutterwave', express.json(), async (req, res) => {
//   const result = await handleFlutterwaveWebhook(req.body, req.headers['verif-hash']);
//   res.sendStatus(result.ok ? 200 : 400);
// });
export const handleFlutterwaveWebhook = async (payload, signatureHeader) => {
  if (!verifyWebhookSignature(signatureHeader)) {
    return { ok: false, reason: 'Invalid signature' };
  }

  const chargeId = payload?.data?.id;
  if (!chargeId) return { ok: false, reason: 'Missing charge id in payload' };

  const ticket = await Ticket.findOne({ where: { flw_charge_id: chargeId } });
  if (!ticket) return { ok: false, reason: 'No matching ticket for charge' };

  if (ticket.status === 'paid') return { ok: true, reason: 'Already paid' };

  // Do not trust the webhook's status alone. Fetch the charge directly from
  // Flutterwave and verify its details against the reserved ticket.
  const charge = await getCharge(chargeId);
  assertChargeMatchesTicket(charge, ticket);
  const status = String(charge.status || '').toLowerCase();

  if (FLW_SUCCESS_STATUSES.includes(status)) {
    await finalizeTicketPayment(ticket.id);
    return { ok: true };
  }

  if (FLW_FAILED_STATUSES.includes(status)) {
    // leave as 'pending' so the seat hold expires naturally (or set a
    // 'failed' status on your Ticket model if you'd rather be explicit)
    return { ok: true, reason: `Charge ${status}` };
  }

  return { ok: true, reason: `Ignored status: ${status}` };
};

// ── SHARED: FINALIZE A SUCCESSFUL PAYMENT ───────────────
// Generates the ticket number/QR, flips status to 'paid', and fires all
// the same notifications the old synchronous payTicket used to send.
const finalizeTicketPayment = async (ticket_id) => {
  const ticket = await Ticket.findByPk(ticket_id);
  if (!ticket) throw new Error('Ticket not found');
  if (ticket.status === 'paid') {
    return Ticket.findByPk(ticket_id, { include: ticketIncludes });
  }
  if (ticket.status === 'cancelled') throw new Error('Ticket is cancelled');

  const bus = await Bus.findByPk(ticket.bus_id);
  if (!bus) throw new Error('Bus not found');
  const boardingStop = await RouteStop.findByPk(ticket.boarding_stop_id);
  const dropoffStop = await RouteStop.findByPk(ticket.dropoff_stop_id);
  if (!boardingStop || !dropoffStop) throw new Error('Invalid ticket stops');

  // ── ATOMIC CLAIM ─────────────────────────────────────
  // Concurrent webhooks and polling calls can reach this at the same time.
  // The claim only applies while the row is still 'pending', under a row
  // lock on the bus (same lock bookTicket holds): whichever caller wins the
  // bus lock finalizes first; a concurrent caller sees 0 affected rows and
  // just returns the already-finalized ticket. The seat-integrity guard
  // inside the same transaction prevents an expired pending hold whose seat
  // was re-booked from being flipped to 'paid' on top of another booking.
  const sequelize = Ticket.sequelize;
  const claimed = await sequelize.transaction(async (t) => {
    await Bus.findByPk(ticket.bus_id, { transaction: t, lock: t.LOCK.UPDATE });

    const seatFree = await isSeatFree(
      ticket.bus_id, ticket.travel_date, ticket.seat_number,
      boardingStop.stop_order, dropoffStop.stop_order,
      t,
      ticket_id // exclude the ticket itself from the conflict scan
    );
    if (!seatFree) {
      throw new Error('Seat no longer available — the pending hold expired and the seat was re-booked before payment confirmed.');
    }

    // retry on ticket-number uniqueness collisions (crypto-random, but the
    // space is intentionally short/human-readable)
    for (let attempt = 0; attempt < 5; attempt++) {
      const ticket_number = generateTicketNumber();
      const qr_token = generateQRToken(
        ticket.id, ticket_number, bus.id,
        bus.departure_time, ticket.travel_date,
        ticket.boarding_stop_id, ticket.dropoff_stop_id
      );
      try {
        const [affectedRows] = await Ticket.update(
          { status: 'paid', ticket_number, qr_token },
          { where: { id: ticket_id, status: 'pending' }, transaction: t }
        );
        return { affectedRows, ticket_number };
      } catch (err) {
        if (err?.name === 'SequelizeUniqueConstraintError' && attempt < 4) continue;
        throw err;
      }
    }
    throw new Error('Could not generate a unique ticket number');
  });

  if (claimed.affectedRows === 0) {
    // another concurrent call finalized the ticket first — nothing to do
    return Ticket.findByPk(ticket_id, { include: ticketIncludes });
  }

  await ticket.reload();
  const ticket_number = claimed.ticket_number;
  const full = await Ticket.findByPk(ticket_id, { include: ticketIncludes });

  await createMany([
    {
      recipient_id: ticket.user_id,
      recipient_type: 'user',
      type: 'ticket_paid',
      message: `Payment confirmed! Ticket: ${ticket_number}. Seat ${full.seat_number} — board at ${full.boardingStop.location.name}, exit at ${full.dropoffStop.location.name}. Bus ${bus.plate_number} departs ${bus.departure_time}.`,
      meta: { ticket_id, ticket_number, seat_number: full.seat_number },
    },
    {
      recipient_id: full.operator_id,
      recipient_type: 'operator',
      type: 'ticket_paid',
      message: `Ticket ${ticket_number} paid. Seat ${full.seat_number} on bus ${bus.plate_number} — boards at ${full.boardingStop.location.name}.`,
      meta: { ticket_id, ticket_number },
    },
  ]);

  const driver = await Driver.findOne({ where: { bus_id: bus.id } });
  if (driver) {
    await createMany([{
      recipient_id: driver.id,
      recipient_type: 'driver',
      type: 'ticket_paid',
      message: `Ticket ${ticket_number} confirmed. Seat ${full.seat_number} — pick up at ${full.boardingStop.location.name}, drop off at ${full.dropoffStop.location.name}.`,
      meta: { ticket_id, ticket_number, seat_number: full.seat_number, boarding: full.boardingStop.location.name, dropoff: full.dropoffStop.location.name },
    }]);
  }

  return full;
};

// ── CANCEL ────────────────────────────────────────────
export const cancelTicket = async (user_id, ticket_id) => {
  const ticket = await Ticket.findOne({ where: { id: ticket_id, user_id } });
  if (!ticket) throw new Error('Ticket not found');
  if (ticket.status === 'cancelled') throw new Error('Already cancelled');
  if (ticket.status === 'paid') throw new Error('Paid tickets cannot be cancelled');

  // A reservation cannot be released while a charge may still succeed. Only
  // clear payment identifiers after Flutterwave definitively reports failure.
  if (ticket.flw_charge_id) {
    const charge = await getCharge(ticket.flw_charge_id);
    assertChargeMatchesTicket(charge, ticket);
    const providerStatus = String(charge.status || '').toLowerCase();
    if (!FLW_FAILED_STATUSES.includes(providerStatus)) {
      throw new Error('Payment is still processing. Check its status before cancelling this reservation.');
    }
    await ticket.update({
      payment_reference: null,
      flw_payment_method_id: null,
      flw_charge_id: null,
      payment_network: null,
    });
  } else if (ticket.payment_reference) {
    const claimAge = Date.now() - new Date(ticket.updatedAt || 0).getTime();
    if (claimAge < 60_000) {
      throw new Error('Payment request is still being initialized. Wait a moment and check its status before cancelling.');
    }
    await ticket.update({ payment_reference: null, payment_network: null });
  }

  await ticket.update({ status: 'cancelled' });
  const full = await Ticket.findByPk(ticket_id, { include: ticketIncludes });

  await createMany([
    {
      recipient_id: user_id,
      recipient_type: 'user',
      type: 'ticket_cancelled',
      message: `Ticket cancelled — seat ${full.seat_number} on ${full.travel_date}.`,
      meta: { ticket_id },
    },
    {
      recipient_id: full.operator_id,
      recipient_type: 'operator',
      type: 'ticket_cancelled',
      message: `Seat ${full.seat_number} on bus ${full.bus.plate_number} for ${full.travel_date} cancelled.`,
      meta: { ticket_id },
    },
  ]);

  const driver = await Driver.findOne({ where: { bus_id: full.bus_id } });
  if (driver) {
    await createMany([{
      recipient_id: driver.id,
      recipient_type: 'driver',
      type: 'ticket_cancelled',
      message: `Seat ${full.seat_number} booking cancelled for ${full.travel_date}.`,
      meta: { ticket_id, seat_number: full.seat_number },
    }]);
  }

  return { message: 'Ticket cancelled' };
};

// ── GET ───────────────────────────────────────────────
export const getMyTickets = async (user_id) => {
  return await Ticket.findAll({
    where: { user_id },
    include: ticketIncludes,
    order: [['travel_date', 'DESC']],
  });
};

export const getTicketById = async (user_id, ticket_id) => {
  const ticket = await Ticket.findOne({
    where: { id: ticket_id, user_id },
    include: ticketIncludes,
  });
  if (!ticket) throw new Error('Ticket not found');
  const qr_image = ticket.qr_token ? await generateQRImage(ticket.qr_token) : null;
  return { ...ticket.toJSON(), qr_image };
};

export const getOperatorTickets = async (operator_id) => {
  return await Ticket.findAll({
    where: { operator_id },
    include: ticketIncludes,
    order: [['travel_date', 'DESC']],
  });
};

export const getAllTickets = async () => {
  return await Ticket.findAll({
    include: ticketIncludes,
    order: [['travel_date', 'DESC']],
  });
};

// ── DRIVER ────────────────────────────────────────────
export const getBusPassengers = async (bus_id, travel_date) => {
  const date = travel_date || new Date().toISOString().split('T')[0];
  return await Ticket.findAll({
    where: { bus_id, travel_date: date, status: 'paid' },
    include: ticketIncludes,
    order: [['seat_number', 'ASC']],
  });
};

export const notifyPassengerExit = async (driver_id, ticket_id) => {
  const driver = await Driver.findByPk(driver_id);
  if (!driver) throw new Error('Driver not found');

  const ticket = await Ticket.findByPk(ticket_id, { include: ticketIncludes });
  if (!ticket) throw new Error('Ticket not found');
  if (ticket.bus_id !== driver.bus_id) throw new Error('Ticket not on your bus');

  await createMany([{
    recipient_id: ticket.user_id,
    recipient_type: 'user',
    type: 'bus_arrived',
    message: `🚏 Prepare to exit! Your stop ${ticket.dropoffStop.location.name} is coming up. Seat ${ticket.seat_number}.`,
    meta: { ticket_id, dropoff: ticket.dropoffStop.location.name },
  }]);

  return { message: `Exit notification sent to passenger at seat ${ticket.seat_number}` };
};

// ── VALIDATE ──────────────────────────────────────────
// Shared atomic redemption. The ticket row is locked (SELECT … FOR UPDATE)
// and flipped with a conditional UPDATE, so two concurrent scans can never
// both redeem the same ticket — the second sees is_used already true.
const redeemTicket = async (findWhere, driver) => {
  const TicketModel = Ticket.sequelize;
  return await TicketModel.transaction(async (t) => {
    const ticket = await Ticket.findOne({ where: findWhere, include: ticketIncludes, transaction: t, lock: t.LOCK.UPDATE });

    if (!ticket) return { valid: false, reason: 'Ticket not found' };
    if (ticket.status !== 'paid') return { valid: false, reason: `Ticket is ${ticket.status}` };
    if (ticket.is_used) return { valid: false, reason: 'Ticket already used — boarding denied' };
    if (driver?.bus_id && String(ticket.bus_id) !== String(driver.bus_id)) {
      return { valid: false, reason: 'This ticket is not for your bus' };
    }

    const today = new Date().toISOString().split('T')[0];
    if (String(ticket.travel_date) > today) {
      return { valid: false, reason: `Ticket is for future date: ${ticket.travel_date}` };
    }

    const [affectedRows] = await Ticket.update(
      { is_used: true },
      { where: { id: ticket.id, is_used: false }, transaction: t }
    );
    if (affectedRows !== 1) {
      return { valid: false, reason: 'Ticket already used — boarding denied' };
    }

    return {
      valid: true,
      ticket: {
        id: ticket.id,
        ticket_number: ticket.ticket_number,
        seat_number: ticket.seat_number,
        travel_date: ticket.travel_date,
        departure_time: ticket.bus.departure_time,
        plate_number: ticket.bus.plate_number,
        passenger: ticket.user,
        boarding: ticket.boardingStop.location.name,
        dropoff: ticket.dropoffStop.location.name,
        operator: ticket.operator,
      },
    };
  });
};

// Record a passenger's departure separately from ticket redemption.
// This does not set is_used and does not change payment status.
export const markTicketDeparted = async (ticket_id, driver) => {
  if (!driver?.id || !driver?.bus_id) throw new Error('Active driver and assigned bus are required');

  const ticket = await Ticket.findByPk(ticket_id, {
    include: [
      { model: Bus, as: 'bus', attributes: ['id', 'plate_number', 'departure_time'] },
      { model: User, as: 'user', attributes: ['id', 'name'] },
      {
        model: RouteStop, as: 'boardingStop', attributes: ['id'],
        include: [{ model: Location, as: 'location', attributes: ['name'] }],
      },
      {
        model: RouteStop, as: 'dropoffStop', attributes: ['id'],
        include: [{ model: Location, as: 'location', attributes: ['name'] }],
      },
    ],
  });
  if (!ticket) throw new Error('Ticket not found');
  if (ticket.bus_id !== driver.bus_id) throw new Error('This ticket is not assigned to your bus');
  if (ticket.status !== 'paid') throw new Error('Only paid tickets can be marked as departed');
  if (ticket.departed_at) {
    return { departed: true, already_departed: true, departed_at: ticket.departed_at, ticket_id: ticket.id };
  }

  const now = new Date();
  const [updated] = await Ticket.update(
    { departed_at: now },
    { where: { id: ticket.id, bus_id: driver.bus_id, status: 'paid', departed_at: null } },
  );
  if (updated !== 1) {
    const latest = await Ticket.findByPk(ticket.id);
    if (latest?.departed_at) {
      return { departed: true, already_departed: true, departed_at: latest.departed_at, ticket_id: ticket.id };
    }
    throw new Error('Could not record passenger departure');
  }

  try {
    await createMany([{
      recipient_id: ticket.user_id,
      recipient_type: 'user',
      type: 'passenger_departed',
      message: `Your trip on bus ${ticket.bus?.plate_number || ''} has been marked as departed. Safe travels!`.trim(),
      meta: {
        ticket_id: ticket.id,
        bus_id: ticket.bus_id,
        travel_date: ticket.travel_date,
        seat_number: ticket.seat_number,
        departed_at: now.toISOString(),
        boarding: ticket.boardingStop?.location?.name || null,
        dropoff: ticket.dropoffStop?.location?.name || null,
      },
    }]);
  } catch (err) {
    console.error('[DEPARTURE] Departure saved but passenger notification failed:', err?.stack || err);
  }

  return { departed: true, already_departed: false, departed_at: now, ticket_id: ticket.id, message: 'Passenger departure recorded. Ticket payment and validation status were not changed.' };
};

export const validateByQR = async (token, driver) => {
  // QR endpoint accepts ONLY signed QR JWTs — no fallback to raw ticket
  // numbers. Ticket numbers must go through the /validate/number endpoint,
  // so a tampered/unparseable payload can never be redeemed as a ticket.
  const decoded = verifyQRToken(token);
  if (!decoded || !decoded.ticket_id) {
    return { valid: false, reason: 'Invalid QR code' };
  }
  return await redeemTicket({ id: decoded.ticket_id }, driver);
};

export const validateByNumber = async (ticket_number, driver) => {
  if (typeof ticket_number !== 'string' || !ticket_number.trim()) {
    return { valid: false, reason: 'Ticket number required' };
  }
  return await redeemTicket({ ticket_number: ticket_number.trim() }, driver);
};