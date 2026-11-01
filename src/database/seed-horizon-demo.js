import bcrypt from 'bcryptjs';
import sequelize from '../config/sequelize.js';
import Location from './models/location.js';
import Route from './models/route.js';
import RouteStop from './models/route_stop.js';
import Operator from './models/operator.js';
import Bus from './models/bus.js';
import Driver from './models/driver.js';

// Opt-in, repeatable demo records. Run with:
// SEED_HORIZON_DEMO=true node src/database/seed-horizon-demo.js
export async function seedHorizonDemo() {
  if (process.env.SEED_HORIZON_DEMO !== 'true') {
    throw new Error('Set SEED_HORIZON_DEMO=true to create demo records.');
  }
  await sequelize.authenticate();
  const [kigali] = await Location.findOrCreate({ where: { name: 'Kigali' } });
  const [musanze] = await Location.findOrCreate({ where: { name: 'Musanze' } });

  const [operator] = await Operator.findOrCreate({
    where: { company_name: 'Horizon' },
    defaults: {
      contact: '+250788123456',
      password_hash: await bcrypt.hash('HorizonOperatorDemo123!', 10),
      is_active: true,
    },
  });
  const [route] = await Route.findOrCreate({
    where: { operator_id: operator.id, from_location_id: kigali.id, to_location_id: musanze.id },
    defaults: { price: 2500 },
  });
  await RouteStop.findOrCreate({
    where: { route_id: route.id, location_id: kigali.id },
    defaults: { stop_order: 1, price_from_origin: 0 },
  });
  await RouteStop.findOrCreate({
    where: { route_id: route.id, location_id: musanze.id },
    defaults: { stop_order: 2, price_from_origin: 2500 },
  });
  const [bus] = await Bus.findOrCreate({
    where: { plate_number: 'RAD 001 H' },
    defaults: {
      operator_id: operator.id, route_id: route.id, driver_name: 'Bruce',
      capacity: 30, departure_time: '08:00', is_active: true,
      last_lat: -1.9418697, last_lng: 30.0439804,
      amenities: ['Air conditioning', 'USB charging'],
    },
  });
  const [driver] = await Driver.findOrCreate({
    where: { phone: '+250781234567' },
    defaults: {
      operator_id: operator.id, bus_id: bus.id, name: 'Bruce',
      password_hash: await bcrypt.hash('HorizonDemo123!', 10),
      is_active: true, must_update_profile: false,
    },
  });
  if (String(driver.operator_id) !== String(operator.id)) {
    throw new Error('The demo phone number is already assigned to another operator.');
  }
  if (!driver.bus_id) await driver.update({ bus_id: bus.id });
  await bus.update({ driver_name: driver.name });
  console.log('Horizon demo company and Bruce driver are ready.');
  console.log('Driver phone: +250781234567');
  console.log('Driver password: HorizonDemo123!');
  console.log('Demo bus: RAD 001 H • Kigali → Musanze');
}

if (process.argv[1]?.endsWith('seed-horizon-demo.js')) {
  seedHorizonDemo()
    .then(() => process.exit(0))
    .catch((error) => { console.error('Horizon demo seed failed:', error); process.exit(1); });
}
