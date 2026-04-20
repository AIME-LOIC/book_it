import Location from '../database/models/location.js';

export const createLocation = async ({ name }) => {
  if (await Location.findOne({ where: { name } })) throw new Error('Location already exists');
  return await Location.create({ name });
};

export const getAllLocations = async () => {
  return await Location.findAll({ order: [['name', 'ASC']] });
};

export const getLocationById = async (id) => {
  const loc = await Location.findByPk(id);
  if (!loc) throw new Error('Location not found');
  return loc;
};

export const deleteLocation = async (id) => {
  const loc = await Location.findByPk(id);
  if (!loc) throw new Error('Location not found');
  await loc.destroy();
};