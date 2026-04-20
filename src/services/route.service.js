import Route         from '../database/models/route.js';
import Location      from '../database/models/location.js';
import Operator      from '../database/models/operator.js';
import RouteStop     from '../database/models/route_stop.js';
import OperatorSettings from '../database/models/operator_settings.js';

const includes = [
  { model: Operator, as: 'operator',     attributes: ['id', 'company_name'] },
  { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
  { model: Location, as: 'toLocation',   attributes: ['id', 'name'] },
];

const stopIncludes = [
  { model: Location, as: 'location', attributes: ['id', 'name'] },
];

export const createRoute = async (operator_id, { from_location_id, to_location_id, price }) => {
  if (from_location_id === to_location_id) throw new Error('Origin and destination cannot be the same');

  const route = await Route.create({ operator_id, from_location_id, to_location_id, price, is_reverse: false });

  // check settings for auto reverse
  let settings = await OperatorSettings.findOne({ where: { operator_id } });
  if (!settings) settings = await OperatorSettings.create({ operator_id });

  let reverse = null;
  if (settings.auto_generate_reverse) {
    reverse = await Route.create({
      operator_id,
      from_location_id: to_location_id,
      to_location_id:   from_location_id,
      price,
      is_reverse:      true,
      parent_route_id: route.id,
    });
  }

  return {
    route:   await Route.findByPk(route.id,   { include: includes }),
    reverse: reverse ? await Route.findByPk(reverse.id, { include: includes }) : null,
  };
};

export const getMyRoutes = async (operator_id) => {
  const routes = await Route.findAll({ where: { operator_id }, include: includes });
  return await Promise.all(routes.map(async r => ({
    ...r.toJSON(),
    stops: await RouteStop.findAll({
      where:   { route_id: r.id },
      include: stopIncludes,
      order:   [['stop_order', 'ASC']],
    }),
  })));
};

export const getAllRoutes = async () => {
  const routes = await Route.findAll({ include: includes });
  return await Promise.all(routes.map(async r => ({
    ...r.toJSON(),
    stops: await RouteStop.findAll({
      where:   { route_id: r.id },
      include: stopIncludes,
      order:   [['stop_order', 'ASC']],
    }),
  })));
};

export const getRouteById = async (id) => {
  const route = await Route.findByPk(id, { include: includes });
  if (!route) throw new Error('Route not found');
  const stops = await RouteStop.findAll({
    where:   { route_id: id },
    include: stopIncludes,
    order:   [['stop_order', 'ASC']],
  });
  return { ...route.toJSON(), stops };
};

export const updateRoute = async (operator_id, id, data) => {
  const route = await Route.findOne({ where: { id, operator_id } });
  if (!route) throw new Error('Route not found or not yours');
  return await route.update(data);
};

export const deleteRoute = async (operator_id, id) => {
  const route = await Route.findOne({ where: { id, operator_id } });
  if (!route) throw new Error('Route not found or not yours');
  await RouteStop.destroy({ where: { route_id: id } });
  await route.destroy();
};