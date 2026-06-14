import Location from './models/location.js';
import Route from './models/route.js';
import RouteStop from './models/route_stop.js';
import Bus from './models/bus.js';
import Operator from './models/operator.js';
import Driver from './models/driver.js';
import bcrypt from 'bcrypt';

export const seedDatabase = async () => {
  try {
    // 1. Define Rwandan Locations
    const locNames = [
      'Kigali', 'Musanze', 'Rubavu', 'Huye', 'Rusizi', 
      'Karongi', 'Nyagatare', 'Rwamagana', 'Kayonza', 
      'Muhanga', 'Nyanza'
    ];
    
    const locMap = {};
    for (const name of locNames) {
      const [loc] = await Location.findOrCreate({ where: { name } });
      locMap[name] = loc;
    }

    // 2. Setup a default Operator (Ritco is a common Rwandan carrier)
    const [operator] = await Operator.findOrCreate({
      where: { company_name: 'Ritco Rwanda' },
      defaults: {
        contact: '+250780000000',
        password_hash: await bcrypt.hash('operator123', 10),
        is_active: true
      }
    });

    // 3. Define the "DM" Driver
    // We create the login record for the DM driver.
    const [dmDriver] = await Driver.findOrCreate({
      where: { phone: '0788888888' }, 
      defaults: {
        operator_id: operator.id,
        name: 'Jean Damascene (DM)',
        password_hash: await bcrypt.hash('driver123', 10),
        is_active: true,
        must_update_profile: false
      }
    });

    // 4. Create 10 Routes and 10 Buses
    const kigali = locMap['Kigali'];
    const destinations = locNames.filter(n => n !== 'Kigali');

    for (let i = 0; i < 10; i++) {
      const dest = locMap[destinations[i]];
      const price = 1500 + (i * 350); // Incremental pricing for variety

      // Create the Route
      const [route] = await Route.findOrCreate({
        where: { from_location_id: kigali.id, to_location_id: dest.id },
        defaults: { operator_id: operator.id, price }
      });

      // Create the necessary RouteStops (Search logic requires these)
      await RouteStop.findOrCreate({
        where: { route_id: route.id, location_id: kigali.id },
        defaults: { stop_order: 1, price_from_origin: 0 }
      });
      await RouteStop.findOrCreate({
        where: { route_id: route.id, location_id: dest.id },
        defaults: { stop_order: 2, price_from_origin: price }
      });

      // Create the Bus
      const plate = `RAA ${500 + i} X`;
      const [bus] = await Bus.findOrCreate({
        where: { plate_number: plate },
        defaults: {
          operator_id: operator.id,
          route_id: route.id,
          capacity: 30,
          driver_name: dmDriver.name,
          departure_time: `${7 + i}:30`, // Staggered morning departures
          is_active: true,
          last_lat: -1.9441 + (i * 0.01),
          last_lng: 30.0619 + (i * 0.01),
          amenities: ['WiFi', 'AC', 'Charging Ports']
        }
      });

      // Link the actual DM Driver login record to the first bus created
      if (i === 0) {
        await dmDriver.update({ bus_id: bus.id });
      }
    }

    console.log('✅ Seed successful: 10 Rwandan routes and buses created.');
  } catch (err) {
    console.error('❌ Seed failed:', err);
  }
};
