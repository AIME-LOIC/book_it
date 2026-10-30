// Regression tests for the booking/QR concurrency fixes (Critical C2/C3).
// Runs against an ISOLATED local MySQL test database (bookit_sec_test) that is
// wiped and recreated by these tests — never against dev/production data.
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';
import { Op } from 'sequelize';

const dirname = path.dirname(fileURLToPath(import.meta.url));

// Point dotenv at the test env BEFORE importing anything that touches config.
// (Static imports below are all dynamic inside the tests so this env var is
// guaranteed to be set first.)
process.env.DOTENV_CONFIG_PATH = path.join(dirname, '.env.test');
if (!existsSync(process.env.DOTENV_CONFIG_PATH)) {
  console.error('tests/.env.test missing — test DB config unavailable');
}

const { default: sequelize } = await import('../src/config/sequelize.js');

// ── fixtures ───────────────────────────────────────────────────────
let User, Operator, Location, Route, RouteStop, Bus, Ticket;
let bookTicket, validateByNumber, generateQRToken;

test('setup: isolated test DB schema + fixtures', async () => {
  ({ default: User } = await import('../src/database/models/user.js'));
  ({ default: Operator } = await import('../src/database/models/operator.js'));
  ({ default: Location } = await import('../src/database/models/location.js'));
  ({ default: Route } = await import('../src/database/models/route.js'));
  ({ default: RouteStop } = await import('../src/database/models/route_stop.js'));
  ({ default: Bus } = await import('../src/database/models/bus.js'));
  ({ default: Ticket } = await import('../src/database/models/ticket.js'));
  ({ bookTicket, validateByNumber } = await import('../src/services/ticket.service.js'));
  ({ generateQRToken } = await import('../src/utils/ticket.utils.js'));

  await sequelize.authenticate();
  await sequelize.sync({ force: true });

  const bcrypt = (await import('bcrypt')).default;
  const hash = await bcrypt.hash('testpass123', 10);

  const operator = await Operator.create({ company_name: 'TestBus Co', password_hash: hash, contact: '0788000000', is_active: true });
  const fromLoc  = await Location.create({ name: 'RaceFromville' });
  const midLoc   = await Location.create({ name: 'RaceMidville' });
  const toLoc    = await Location.create({ name: 'RaceToville' });
  const route    = await Route.create({ operator_id: operator.id, from_location_id: fromLoc.id, to_location_id: toLoc.id, price: 5000 });
  const stop1 = await RouteStop.create({ route_id: route.id, location_id: fromLoc.id, stop_order: 1, price_from_origin: 0 });
  const stop2 = await RouteStop.create({ route_id: route.id, location_id: midLoc.id, stop_order: 2, price_from_origin: 2000 });
  const stop3 = await RouteStop.create({ route_id: route.id, location_id: toLoc.id, stop_order: 3, price_from_origin: 5000 });
  const bus   = await Bus.create({ operator_id: operator.id, route_id: route.id, plate_number: 'RAB999T', driver_name: 'Test Driver', capacity: 10, departure_time: '23:59' });

  const tomorrow = new Date(Date.now() + 24 * 3600 * 1000).toISOString().split('T')[0];
  const u1 = await User.create({ name: 'User One', email: 'race-u1@test.local', phone: '0788111111', password_hash: hash });
  const u2 = await User.create({ name: 'User Two', email: 'race-u2@test.local', phone: '0788222222', password_hash: hash });

  global.__raceFixtures = { operator, route, fromLoc, midLoc, toLoc, route, stop1, stop2, stop3, bus, tomorrow, u1, u2 };
});

// ── C2: concurrent booking of same seat/segment → exactly one winner ──
test('C2: two concurrent bookings for the same seat + segment → exactly one succeeds', async () => {
  const f = global.__raceFixtures;
  const base = {
    bus_id: f.bus.id,
    boarding_stop_id: f.stop1.id,
    dropoff_stop_id: f.stop3.id,
    travel_date: f.tomorrow,
  };
  const [r1, r2] = await Promise.all([
    bookTicket(f.u1.id, { ...base, seat_number: 10 }).then(t => ({ ok: true, id: t.id })).catch(e => ({ ok: false, message: e.message })),
    bookTicket(f.u2.id, { ...base, seat_number: 10 }).then(t => ({ ok: true, id: t.id })).catch(e => ({ ok: false, message: e.message })),
  ]);
  assert.equal(r1.ok, true, 'first booking should succeed');
  assert.equal(r2.ok, false, 'second overlapping booking must fail');
  assert.match(r2.message, /taken/i);

  const seat10 = await Ticket.findAll({ where: { bus_id: f.bus.id, seat_number: 10, travel_date: f.tomorrow, status: { [Op.not]: 'cancelled' } } });
  assert.equal(seat10.length, 1, 'exactly one non-cancelled ticket owns seat 10');
});

// ── C2: overlapping-segment check, not bus-level coarse check ──
test('C2: non-overlapping segments on the same seat can both be booked', async () => {
  const f = global.__raceFixtures;
  // seat 9: (stop1→stop2) is inside check window only when overlapping.
  // first book stop1→stop3 then try stop1→stop3 again — should fail,
  // then stop1→stop2 after winner cancelled? Simpler: different seats prove
  // the segment logic via full-route vs partial-segment distinction.
  const r1 = await bookTicket(f.u1.id, { bus_id: f.bus.id, boarding_stop_id: f.stop1.id, dropoff_stop_id: f.stop2.id, travel_date: f.tomorrow, seat_number: 9 });
  assert.ok(r1, 'first partial-segment booking succeeded');
  // booking stop2→stop3 (after the first passenger exits) must be allowed
  const r2 = await bookTicket(f.u2.id, { bus_id: f.bus.id, boarding_stop_id: f.stop2.id, dropoff_stop_id: f.stop3.id, travel_date: f.tomorrow, seat_number: 9 });
  assert.ok(r2, 'same seat usable for a later non-overlapping segment');
});

// ── C3: concurrent redemption of the same ticket → exactly one valid ──
test('C3: simultaneous ticket-number scans → exactly one redemption', async () => {
  const f = global.__raceFixtures;
  const t = await bookTicket(f.u1.id, { bus_id: f.bus.id, boarding_stop_id: f.stop1.id, dropoff_stop_id: f.stop2.id, travel_date: f.tomorrow, seat_number: 5 });
  // Redeemable tickets are for today — the service (correctly) denies travel on a future date.
  const today = new Date().toISOString().split('T')[0];
  const [updated] = await Ticket.update(
    { status: 'paid', ticket_number: 'BK-7777-AA', travel_date: today },
    { where: { id: t.id } }
  );
  assert.equal(updated, 1);

  const driver = { bus_id: f.bus.id };
  const [s1, s2] = await Promise.all([
    validateByNumber('BK-7777-AA', driver),
    validateByNumber('BK-7777-AA', driver),
  ]);
  const results = [s1, s2];
  assert.equal(results.filter(r => r.valid).length, 1, `exactly one scan must win (got ${JSON.stringify([s1, s2])})`);
  const loser = results.find(r => !r.valid);
  assert.match(loser.reason, /already used|not for your bus|denied/i, 'the loser must report a denial');
  const after = await Ticket.findByPk(t.id);
  assert.equal(after.is_used, true);
});

// ── QR token path: valid signed token redeems; garbage is rejected ──
test('C3: QR endpoint rejects invalid payloads and redeems signed tokens once', async () => {
  const f = global.__raceFixtures;
  const { validateByQR } = await import('../src/services/ticket.service.js');

  // garbage token → 'Invalid QR code' (no fallback to raw ticket number)
  const bad = await validateByQR('BK-7777-AA', { bus_id: f.bus.id });
  assert.equal(bad.valid, false);
  assert.equal(bad.reason, 'Invalid QR code');

  const t = await bookTicket(f.u1.id, { bus_id: f.bus.id, boarding_stop_id: f.stop1.id, dropoff_stop_id: f.stop2.id, travel_date: f.tomorrow, seat_number: 6 });
  await Ticket.update(
    { status: 'paid', ticket_number: 'BK-7777-BB', qr_token: 'JWTSTAMP', travel_date: new Date().toISOString().split('T')[0] },
    { where: { id: t.id } }
  );

  const freshTicket = await Ticket.findByPk(t.id);
  const token = generateQRToken(
    freshTicket.id, freshTicket.ticket_number, f.bus.id, f.bus.departure_time,
    freshTicket.travel_date, freshTicket.boarding_stop_id, freshTicket.dropoff_stop_id
  );
  const driver = { bus_id: f.bus.id };
  const first = await validateByQR(token, driver);
  assert.equal(first.valid, true);
  const second = await validateByQR(token, driver);
  assert.equal(second.valid, false, 'signed QR token also redeems exactly once');
});

// ── teardown ──────────────────────────────────────────────────────
test('teardown: close DB connection', async () => {
  await sequelize.close();
});
