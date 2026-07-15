import { Op }        from 'sequelize';
import sequelize     from '../config/sequelize.js';
import Route         from '../database/models/route.js';
import RouteStop     from '../database/models/route_stop.js';
import Location      from '../database/models/location.js';
import Operator      from '../database/models/operator.js';
import OperatorSettings from '../database/models/operator_settings.js';

const stopIncludes = [
  { model: Location, as: 'location', attributes: ['id', 'name'] },
];

const getSettings = async (operator_id) => {
  let settings = await OperatorSettings.findOne({ where: { operator_id } });
  if (!settings) settings = await OperatorSettings.create({ operator_id });
  return settings;
};

const resolveLegRoute = async (operator_id, from_location_id, to_location_id) => {
  const legRoutes = await Route.findAll({
    where: {
      operator_id,
      from_location_id,
      to_location_id,
    },
  });

  if (!legRoutes.length) return null;
  if (legRoutes.length > 1) {
    throw new Error(
      `Multiple base routes found from this stop to the next location. ` +
      `Pass leg_route_id explicitly for this stop order.`
    );
  }

  return legRoutes[0];
};

// Chained stop-adding: each stop after the origin must reference an
// existing Route (owned by the same operator) running from the current
// chain-end location to the new stop's location. That leg route's price
// gets added to the running total. If the caller does not supply
// leg_route_id, we try to infer a single matching base route from the
// current chain end to the new stop.
//
// stops payload shape: [{ location_id, stop_order, leg_route_id? }]
// stop_order 1 is always the route's own origin — leg_route_id ignored/
// not required for it, price is always 0.
export const addStops = async (operator_id, route_id, stops) => {
  const route = await Route.findOne({ where: { id: route_id, operator_id } });
  if (!route) throw new Error('Route not found or not yours');

  const orders = stops.map(s => s.stop_order);
  if (new Set(orders).size !== orders.length) throw new Error('Duplicate stop orders');

  const sorted = [...stops].sort((a, b) => a.stop_order - b.stop_order);

  // existing stops already on this route (in case addStops is called
  // incrementally rather than all at once)
  const existing = await RouteStop.findAll({
    where: { route_id }, order: [['stop_order', 'ASC']],
  });

  let chainEndLocationId = existing.length
    ? existing[existing.length - 1].location_id
    : route.from_location_id;
  let runningTotal = existing.length
    ? parseFloat(existing[existing.length - 1].price_from_origin)
    : 0;

  const toCreate = [];

  for (const s of sorted) {
    const isOrigin = existing.length === 0 && s.stop_order === 1;

    if (isOrigin) {
      if (s.location_id !== route.from_location_id) {
        throw new Error('First stop must match the route\'s origin location');
      }
      toCreate.push({
        route_id, location_id: s.location_id, stop_order: s.stop_order,
        price_from_origin: 0, leg_route_id: null,
      });
      chainEndLocationId = s.location_id;
      continue;
    }

    let legRoute = null;
    if (s.leg_route_id) {
      legRoute = await Route.findOne({
        where: { id: s.leg_route_id, operator_id },
      });
    } else {
      legRoute = await resolveLegRoute(operator_id, chainEndLocationId, s.location_id);
    }

    if (!legRoute) {
      throw new Error(
        `Stop at order ${s.stop_order} needs a leg route from the previous stop ` +
        `to this location. Create that base route first.`
      );
    }
    if (legRoute.from_location_id !== chainEndLocationId) {
      throw new Error(
        `Leg route must start where the chain currently ends (stop order ${s.stop_order}) — ` +
        `no matching base route from that location yet.`
      );
    }
    if (legRoute.to_location_id !== s.location_id) {
      throw new Error(`Leg route's destination doesn't match this stop's location (stop order ${s.stop_order})`);
    }

    runningTotal = parseFloat((runningTotal + parseFloat(legRoute.price)).toFixed(2));
    toCreate.push({
      route_id, location_id: s.location_id, stop_order: s.stop_order,
      price_from_origin: runningTotal, leg_route_id: legRoute.id,
    });
    chainEndLocationId = s.location_id;
  }

  await RouteStop.bulkCreate(toCreate);

  // Keep the route's original base price until at least one real leg exists.
  // This prevents an origin-only save from zeroing the route and breaking
  // self-referential leg pricing for the destination stop.
  const hasPricedLeg = toCreate.some(stop => stop.stop_order !== 1);
  if (hasPricedLeg) {
    await route.update({ price: runningTotal });
  }

  const settings = await getSettings(operator_id);
  if (settings.auto_generate_reverse) {
    await syncReverseStops(operator_id, route);
  }

  return await getRouteWithStops(route_id);
};

// Reverse stops are derived by subtraction, not re-chained — there's no
// guarantee a reverse leg route (B→A) exists just because A→B does, and
// requiring one would block auto-reverse-generation entirely. leg_route_id
// stays null on these; they're informational mirrors, not chain-validated.
const syncReverseStops = async (operator_id, route) => {
  const reverse = await Route.findOne({
    where: {
      operator_id,
      from_location_id: route.to_location_id,
      to_location_id:   route.from_location_id,
      is_reverse:       true,
    },
  });
  if (!reverse) return;

  const originalStops = await RouteStop.findAll({
    where: { route_id: route.id },
    order: [['stop_order', 'ASC']],
  });
  if (!originalStops.length) return;

  await RouteStop.destroy({ where: { route_id: reverse.id } });

  const maxOrder = originalStops.length;
  const totalPrice = parseFloat(originalStops[originalStops.length - 1].price_from_origin);

  await RouteStop.bulkCreate(
    originalStops.map((stop, i) => ({
      route_id:          reverse.id,
      location_id:       stop.location_id,
      stop_order:        maxOrder - i,
      price_from_origin: parseFloat((totalPrice - parseFloat(stop.price_from_origin)).toFixed(2)),
      leg_route_id:      null,
    }))
  );

  await reverse.update({ price: totalPrice });
};

export const getRouteWithStops = async (route_id) => {
  const route = await Route.findByPk(route_id, {
    include: [
      { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
      { model: Location, as: 'toLocation',   attributes: ['id', 'name'] },
      { model: Operator, as: 'operator',     attributes: ['id', 'company_name'] },
    ],
  });
  if (!route) throw new Error('Route not found');

  const stops = await RouteStop.findAll({
    where:   { route_id },
    include: [...stopIncludes, { model: Route, as: 'legRoute', attributes: ['id', 'price'] }],
    order:   [['stop_order', 'ASC']],
  });

  return { ...route.toJSON(), stops };
};

// (searchByStops, updateStop, deleteStop, getOperatorSettings,
//  updateOperatorSettings unchanged from your current file — updateStop
//  in particular would need the same leg-route validation as addStops if
//  you want edits to individually-changed stops re-validated; flagging
//  that as a gap I haven't closed, tell me if you want it handled now
//  or later)

// Search routes passing through both stops in correct order
export const searchByStops = async ({ from_location_id, to_location_id }) => {
  // load ALL stops at once — no complex joins
  const allStops = await RouteStop.findAll({
    attributes: ['id', 'route_id', 'location_id', 'stop_order', 'price_from_origin'],
    raw: true, // plain objects, no sequelize wrapping
  });

  console.log('Total stops in DB:', allStops.length);
  console.log('Looking for from:', from_location_id);
  console.log('Looking for to:',   to_location_id);
  console.log('All location_ids:', allStops.map(s => s.location_id));

  // group by route
  const byRoute = {};
  allStops.forEach(s => {
    if (!byRoute[s.route_id]) byRoute[s.route_id] = [];
    byRoute[s.route_id].push(s);
  });

  const validRoutes = [];

  for (const [route_id, stops] of Object.entries(byRoute)) {
    const fromStop = stops.find(s => s.location_id === from_location_id);
    const toStop   = stops.find(s => s.location_id === to_location_id);

    console.log(`Route ${route_id} — fromStop:`, fromStop?.location_id, '| toStop:', toStop?.location_id);

    if (!fromStop || !toStop) continue;
    if (fromStop.stop_order >= toStop.stop_order) continue;

    const price = parseFloat(
      (parseFloat(toStop.price_from_origin) - parseFloat(fromStop.price_from_origin)).toFixed(2)
    );

    validRoutes.push({
      route_id,
      boarding_stop_id: fromStop.id,
      dropoff_stop_id:  toStop.id,
      boarding_order:   fromStop.stop_order,
      dropoff_order:    toStop.stop_order,
      price,
    });
  }

  console.log('Valid routes found:', validRoutes.length);
  return validRoutes;
};

// Update a single stop
export const updateStop = async (operator_id, stop_id, data) => {
  const stop  = await RouteStop.findByPk(stop_id, { include: [{ model: Route, as: 'route' }] });
  if (!stop)                              throw new Error('Stop not found');
  if (stop.route.operator_id !== operator_id) throw new Error('Not your route');
  await stop.update(data);

  const settings = await getSettings(operator_id);
  if (settings.auto_generate_reverse) {
    await syncReverseStops(operator_id, stop.route);
  }

  return stop;
};

// Delete a stop
export const deleteStop = async (operator_id, stop_id) => {
  const stop = await RouteStop.findByPk(stop_id, { include: [{ model: Route, as: 'route' }] });
  if (!stop)                              throw new Error('Stop not found');
  if (stop.route.operator_id !== operator_id) throw new Error('Not your route');
  await stop.destroy();
};

// Get/update operator settings
export const getOperatorSettings = async (operator_id) => {
  return await getSettings(operator_id);
};

export const updateOperatorSettings = async (operator_id, data) => {
  const settings = await getSettings(operator_id);
  return await settings.update(data);
};
