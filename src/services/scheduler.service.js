import Bus      from '../database/models/bus.js';
import Operator from '../database/models/operator.js';
import Route    from '../database/models/route.js';
import Location from '../database/models/location.js';
import { createMany } from './notification.service.js';

export const checkDepartedBuses = async () => {
  const now   = new Date();
  const today = now.toISOString().split('T')[0];

  const activeBuses = await Bus.findAll({
    where: { is_active: true },
    include: [
      { model: Operator, as: 'operator', attributes: ['id', 'company_name'] },
      {
        model: Route, as: 'route', attributes: ['id', 'price'],
        include: [
          { model: Location, as: 'fromLocation', attributes: ['id', 'name'] },
          { model: Location, as: 'toLocation',   attributes: ['id', 'name'] },
        ],
      },
    ],
  });

  for (const bus of activeBuses) {
    const [h, m] = String(bus.departure_time).split(':').map(Number);
    const dep = new Date();
    dep.setHours(h, m, 0, 0);

    if (now >= dep) {
      await bus.update({ is_active: false });

      const from = bus.route?.fromLocation?.name || '?';
      const to   = bus.route?.toLocation?.name   || '?';

      await createMany([{
        recipient_id:   bus.operator_id,
        recipient_type: 'operator',
        type:           'bus_departed',
        message:        `Bus ${bus.plate_number} (${from} → ${to}) has departed at ${String(bus.departure_time).slice(0,5)}. It has been deactivated and removed from bookings.`,
        meta:           { bus_id: bus.id, plate: bus.plate_number },
      }]);

      console.log(`[Scheduler] Bus ${bus.plate_number} deactivated — departed at ${String(bus.departure_time).slice(0,5)}`);
    }
  }
};
