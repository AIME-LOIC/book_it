import Bus from '../database/models/bus.js';
import Route from '../database/models/route.js';
import Operator from '../database/models/operator.js';
import Location from '../database/models/location.js';

const includes = [
  { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
  {
    model: Route, as: 'route', attributes: ['id', 'price'],
    include: [
      { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
      { model: Location, as: 'toLocation', attributes: ['id', 'name'] },
    ],
  },
];

export const createBus = async (operator_id, { route_id, plate_number, driver_name, capacity, departure_time }) => {
  const route = await Route.findOne({ where: { id: route_id, operator_id } });
  if (!route) throw new Error('Route not found or not yours');
  if (await Bus.findOne({ where: { plate_number } })) throw new Error('Plate number already exists');
  return await Bus.create({ operator_id, route_id, plate_number, driver_name, capacity, departure_time });
};

export const getMyBuses = async (operator_id) => {
  return await Bus.findAll({ where: { operator_id }, include: includes });
};

export const getAllBuses = async () => {
  return await Bus.findAll({ include: includes });
};

export const getBusesByRoute = async (route_id) => {
  return await Bus.findAll({ where: { route_id }, include: includes });
};

export const getBusById = async (id) => {
  const bus = await Bus.findByPk(id, { include: includes });
  if (!bus) throw new Error('Bus not found');
  return bus;
};

export const updateBus = async (operator_id, id, data) => {
  const bus = await Bus.findOne({ where: { id, operator_id } });
  if (!bus) throw new Error('Bus not found or not yours');
  const allowedFields = ['route_id', 'plate_number', 'driver_name', 'capacity', 'departure_time', 'amenities', 'is_active'];
  const updates = Object.fromEntries(
    Object.entries(data || {}).filter(([key]) => allowedFields.includes(key)),
  );

  if (Object.hasOwn(updates, 'route_id')) {
    const route = await Route.findOne({ where: { id: updates.route_id, operator_id } });
    if (!route) throw new Error('Route not found or not yours');
  }

  if (Object.hasOwn(updates, 'plate_number') && updates.plate_number !== bus.plate_number) {
    const duplicate = await Bus.findOne({ where: { plate_number: updates.plate_number } });
    if (duplicate) throw new Error('Plate number already exists');
  }

  if (Object.hasOwn(updates, 'is_active')) {
    if (typeof updates.is_active !== 'boolean') throw new Error('is_active must be a boolean');
    updates.is_manually_disabled = updates.is_active === false;
  }

  return await bus.update(updates);
};

export const updateBusLocation = async (id, { last_lat, last_lng }) => {
  const bus = await Bus.findByPk(id);
  if (!bus) throw new Error('Bus not found');
  console.log(`[BusService] Updating location for Bus ${id}: ${last_lat}, ${last_lng}`);
  return await bus.update({ last_lat, last_lng });
};

export const deleteBus = async (operator_id, id) => {
  const bus = await Bus.findOne({ where: { id, operator_id } });
  if (!bus) throw new Error('Bus not found or not yours');
  await bus.destroy();
};
export const getAllAvailableBuses = async () => {
  return await Bus.findAll({
    where: { is_active: true },
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
};