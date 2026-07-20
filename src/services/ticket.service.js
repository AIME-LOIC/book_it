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
const isSeatFree = async (bus_id, travel_date, seat_number, boarding_order, dropoff_order) => {
  const PENDING_TIMEOUT_MINUTES = 15;
  const expirationCutoff = new Date(Date.now() - PENDING_TIMEOUT_MINUTES * 60000);

  const conflicts = await Ticket.findAll({
    where: {
      bus_id, travel_date, seat_number,
      [Op.or]: [
        { status: 'paid' },
        { status: 'pending', createdAt: { [Op.gt]: expirationCutoff } }
      ]
    },
    include: [
      { model: RouteStop, as: 'boardingStop', attributes: ['stop_order'] },
      { model: RouteStop, as: 'dropoffStop', attributes: ['stop_order'] },
    ],
  });

  for (const t of conflicts) {
    const existBoarding = Number(t.boardingStop.stop_order);
    const existDropoff = Number(t.dropoffStop.stop_order);
    const nb = Number(boarding_order);
    const nd = Number(dropoff_order);
    if (existBoarding < nd && existDropoff > nb) {
      return false;
    }
  }
  return true;
};

const getSegmentSeats = async (bus, travel_date, boarding_order, dropoff_order) => {
  const PENDING_TIMEOUT_MINUTES = 15;
  const expirationCutoff = new Date(Date.now() - PENDING_TIMEOUT_MINUTES * 60000);

  const conflicts = await Ticket.findAll({
    where: {
      bus_id: bus.id, travel_date,
      [Op.or]: [
        { status: 'paid' },
        { status: 'pending', createdAt: { [Op.gt]: expirationCutoff } }
      ]
    },
    include: [
      { model: RouteStop, as: 'boardingStop', attributes: ['stop_order'] },
      { model: RouteStop, as: 'dropoffStop', attributes: ['stop_order'] },
    ],
  });

  const takenSeats = new Set();
  for (const t of conflicts) {
    const eb = Number(t.boardingStop.stop_order);
    const ed = Number(t.dropoffStop.stop_order);
    const nb = Number(boarding_order);
    const nd = Number(dropoff_order);
    // segments overlap if existing boarding < new dropoff AND existing dropoff > new boarding
    if (eb < nd && ed > nb) takenSeats.add(t.seat_number);
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

  if (seat_number < 1 || seat_number > bus.capacity) {
    throw new Error(`Seat must be between 1 and ${bus.capacity}`);
  }

  const free = await isSeatFree(
    bus_id, travel_date, seat_number,
    boardingStop.stop_order, dropoffStop.stop_order
  );
  if (!free) throw new Error(`Seat ${seat_number} is taken for this segment`);

  const price = parseFloat(
    (parseFloat(dropoffStop.price_from_origin) - parseFloat(boardingStop.price_from_origin)).toFixed(2)
  );

  const ticket = await Ticket.create({
    user_id,
    bus_id,
    operator_id: bus.operator_id,
    boarding_stop_id,
    dropoff_stop_id,
    seat_number,
    travel_date,
    price,
    status: 'pending',
  });

  const full = await Ticket.findByPk(ticket.id, { include: ticketIncludes });

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
  const reference = `bk-${shortId}-${Date.now()}`;

  const { customer, paymentMethod, charge } = await initiateMobileMoneyCharge({
    user,
    network,
    phone_number,
    amount: Math.round(Number(ticket.price)),
    reference,
    meta: { ticket_id: ticket.id, user_id },
    existing_customer_id: user.flw_customer_id || null,
  });

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
    return { status: 'not_initiated' };
  }

  const charge = await getCharge(ticket.flw_charge_id);

  if (FLW_SUCCESS_STATUSES.includes(charge.status)) {
    const finalized = await finalizeTicketPayment(ticket.id);
    return { status: 'paid', ticket: finalized };
  }

  if (FLW_FAILED_STATUSES.includes(charge.status)) {
    return { status: 'failed', reason: charge.failure_reason || charge.status };
  }

  return { status: charge.status || 'pending' };
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
  const status = payload?.data?.status;
  if (!chargeId) return { ok: false, reason: 'Missing charge id in payload' };

  const ticket = await Ticket.findOne({ where: { flw_charge_id: chargeId } });
  if (!ticket) return { ok: false, reason: 'No matching ticket for charge' };

  if (ticket.status === 'paid') return { ok: true, reason: 'Already paid' };

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

  const bus = await Bus.findByPk(ticket.bus_id);
  const ticket_number = generateTicketNumber();
  const qr_token = generateQRToken(
    ticket.id, ticket_number, bus.id,
    bus.departure_time, ticket.travel_date,
    ticket.boarding_stop_id, ticket.dropoff_stop_id
  );

  await ticket.update({ status: 'paid', ticket_number, qr_token });
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
export const validateByQR = async (token, driver) => {
  const decoded = verifyQRToken(token);
  if (!decoded) {
    // Fallback: check if it's a raw ticket number (some scanners might send raw text)
    const ticket_number = token.trim();
    var ticket = await Ticket.findOne({ where: { ticket_number }, include: ticketIncludes });
  } else {
    var ticket = await Ticket.findOne({ where: { id: decoded.ticket_id }, include: ticketIncludes });
  }

  if (!ticket) return { valid: false, reason: 'Ticket not found' };
  if (ticket.status !== 'paid') return { valid: false, reason: `Ticket is ${ticket.status}` };
  if (ticket.is_used) return { valid: false, reason: '⚠️ Ticket already used — boarding denied' };
  if (driver?.bus_id && ticket.bus_id !== driver.bus_id) return { valid: false, reason: 'This ticket is not for your bus' };

  const today = new Date().toISOString().split('T')[0];
  if (ticket.travel_date > today) return { valid: false, reason: `Ticket is for future date: ${ticket.travel_date}` };

  await ticket.update({ is_used: true });

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
};

export const validateByNumber = async (ticket_number, driver) => {
  const ticket = await Ticket.findOne({ where: { ticket_number }, include: ticketIncludes });
  if (!ticket) return { valid: false, reason: 'Ticket not found' };
  if (ticket.status !== 'paid') return { valid: false, reason: `Ticket is ${ticket.status}` };
  if (ticket.is_used) return { valid: false, reason: '⚠️ Ticket already used — boarding denied' };
  if (driver?.bus_id && ticket.bus_id !== driver.bus_id) return { valid: false, reason: 'This ticket is not for your bus' };

  const today = new Date().toISOString().split('T')[0];
  if (ticket.travel_date > today) return { valid: false, reason: `Ticket is for future date: ${ticket.travel_date}` };

  await ticket.update({ is_used: true });

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
};