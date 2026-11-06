
import sequelize from '../config/sequelize.js';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';

import Location from './models/location.js';
import Operator from './models/operator.js';
import Route from './models/route.js';
import RouteStop from './models/route_stop.js';
import Bus from './models/bus.js';
import Driver from './models/driver.js';

import { encryptPassword } from '../utils/crypto.utils.js';

const destinations = [
  { name: 'Muhanga', price: 1500, plate: 'RAA 901 X', phone: '0788000501', driver: 'Jean Claude' },
  { name: 'Rwamagana', price: 1500, plate: 'RAA 902 X', phone: '0788000502', driver: 'Patrick' },
  { name: 'Huye', price: 2500, plate: 'RAA 903 X', phone: '0788000503', driver: 'Emmanuel' },
];

async function seedRitco() {
  await sequelize.authenticate();

  const [operator] = await Operator.findOrCreate({
    where: { company_name: 'Ritco' },
    defaults: {
      contact: '+250780000000',
      password_hash: await bcrypt.hash(
        crypto.randomBytes(24).toString('hex'), 10
      ),
      is_active: true,
    },
  });

  const [kigali] = await Location.findOrCreate({
    where: { name: 'Kigali' },
  });

  const credentials = [];

  for (const item of destinations) {
    const [destination] = await Location.findOrCreate({
      where: { name: item.name },
    });

    const [route] = await Route.findOrCreate({
      where: {
        from_location_id: kigali.id,
        to_location_id: destination.id,
      },
      defaults: {
        operator_id: operator.id,
        price: item.price,
      },
    });

    await RouteStop.findOrCreate({
      where: { route_id: route.id, stop_order: 1 },
      defaults: {
        location_id: kigali.id,
        price_from_origin: 0,
      },
    });

    await RouteStop.findOrCreate({
      where: { route_id: route.id, stop_order: 2 },
      defaults: {
        location_id: destination.id,
        price_from_origin: item.price,
      },
    });

    const [bus] = await Bus.findOrCreate({
      where: { plate_number: item.plate },
      defaults: {
        operator_id: operator.id,
        route_id: route.id,
        capacity: 30,
        driver_name: item.driver,
        departure_time: '07:30',
        is_active: true,
        amenities: ['WiFi', 'AC', 'Charging Ports'],
      },
    });

    if (bus.operator_id !== operator.id) {
      throw new Error(`Bus ${item.plate} belongs to another operator`);
    }

    const existingDriver = await Driver.findOne({
      where: { phone: item.phone },
    });

    let driverPassword = null;

    if (!existingDriver) {
      driverPassword = crypto.randomBytes(16).toString('hex').toUpperCase();

      await Driver.create({
        operator_id: operator.id,
        bus_id: bus.id,
        name: item.driver,
        phone: item.phone,
        password_hash: await bcrypt.hash(driverPassword, 10),
        default_password: encryptPassword(driverPassword),
        must_update_profile: true,
        is_active: true,
      });
    } else {
      if (existingDriver.operator_id !== operator.id) {
        throw new Error(`Driver ${item.phone} belongs to another operator`);
      }

      if (existingDriver.bus_id && existingDriver.bus_id !== bus.id) {
        throw new Error(`Driver ${item.phone} is assigned to another bus`);
      }

      await existingDriver.update({ bus_id: bus.id });
    }

    credentials.push({
      destination: item.name,
      bus: item.plate,
      driver: item.driver,
      phone: item.phone,
      password: driverPassword || 'Existing account: password unchanged',
    });
  }

  console.log('\n========== RITCO SEED RESULTS ==========');
  console.table(credentials);
  console.log('\nRITCO buses and drivers seeded successfully.');
}

seedRitco()
  .catch(error => {
    console.error('RITCO SEED FAILED:', error);
    process.exitCode = 1;
  })
  .finally(() => sequelize.close());
