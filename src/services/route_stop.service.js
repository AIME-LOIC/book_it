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

// Get or create operator settings
const getSettings = async (operator_id) => {
  let settings = await OperatorSettings.findOne({ where: { operator_id } });
  if (!settings) {
    settings = await OperatorSettings.create({ operator_id });
  }
  return settings;
};

// Add stops to a route
export const addStops = async (operator_id, route_id, stops) => {
  const route = await Route.findOne({ where: { id: route_id, operator_id } });
  if (!route) throw new Error('Route not found or not yours');

  // stops = [{ location_id, stop_order, price_from_origin }]
  // validate no duplicate orders
  const orders = stops.map(s => s.stop_order);
  if (new Set(orders).size !== orders.length) throw new Error('Duplicate stop orders');

  const created = await RouteStop.bulkCreate(
    stops.map(s => ({ ...s, route_id })),
    { ignoreDuplicates: false }
  );

  // auto generate reverse if setting is on
  const settings = await getSettings(operator_id);
  if (settings.auto_generate_reverse) {
    await syncReverseStops(operator_id, route);
  }

  return await getRouteWithStops(route_id);
};

// Sync reverse route stops when original stops change
const syncReverseStops = async (operator_id, route) => {
  // find reverse route
  const reverse = await Route.findOne({
    where: {
      operator_id,
      from_location_id: route.to_location_id,
      to_location_id:   route.from_location_id,
      is_reverse:       true,
    },
  });
  if (!reverse) return;

  // get original stops
  const originalStops = await RouteStop.findAll({
    where: { route_id: route.id },
    order: [['stop_order', 'ASC']],
  });
  if (!originalStops.length) return;

  // delete old reverse stops
  await RouteStop.destroy({ where: { route_id: reverse.id } });

  const maxOrder = originalStops.length;

  // create reversed stops with reversed prices
  const totalPrice = parseFloat(originalStops[originalStops.length - 1].price_from_origin);
  await RouteStop.bulkCreate(
    originalStops.map((stop, i) => ({
      route_id:          reverse.id,
      location_id:       stop.location_id,
      stop_order:        maxOrder - i,
      price_from_origin: parseFloat((totalPrice - parseFloat(stop.price_from_origin)).toFixed(2)),
    }))
  );
};

// Get route with all stops ordered
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
    include: stopIncludes,
    order:   [['stop_order', 'ASC']],
  });

  return { ...route.toJSON(), stops };
};

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