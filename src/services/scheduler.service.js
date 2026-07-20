import Bus      from '../database/models/bus.js';
import Operator from '../database/models/operator.js';
import Route    from '../database/models/route.js';
import Location from '../database/models/location.js';
import { createMany } from './notification.service.js';
import { generateDailyLoyaltyPromo } from './promo.service.js';

// ── DEACTIVATE DEPARTED BUSES (runs every 60s) ────────────────
export const checkDepartedBuses = async () => {
  const now = new Date();

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
        message:        `Bus ${bus.plate_number} (${from} → ${to}) has departed at ${String(bus.departure_time).slice(0,5)}. It will be reactivated tomorrow.`,
        meta:           { bus_id: bus.id, plate: bus.plate_number },
      }]);

      console.log(`[Scheduler] Bus ${bus.plate_number} deactivated — departed at ${String(bus.departure_time).slice(0,5)}`);
    }
  }
};

// ── REACTIVATE ALL BUSES AT MIDNIGHT (runs every 60s, triggers once) ─────────
let lastReactivationDate = null;
let lastPromoGenerationDate = null;

export const checkMidnightReactivation = async () => {
  const now   = new Date();
  const today = now.toISOString().split('T')[0];

  // only run once per day, between 00:00 and 00:01
  if (now.getHours() !== 0 || now.getMinutes() > 1) return;
  if (lastReactivationDate === today) return;

  lastReactivationDate = today;

  const inactiveBuses = await Bus.findAll({
    where: { is_active: false },
  });

  for (const bus of inactiveBuses) {
    await bus.update({ is_active: true });
    console.log(`[Scheduler] Bus ${bus.plate_number} reactivated for ${today}`);
  }

  if (inactiveBuses.length > 0) {
    console.log(`[Scheduler] ${inactiveBuses.length} bus(es) reactivated for ${today}`);
  }
};

export const checkPromoCodeGeneration = async () => {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  if (lastPromoGenerationDate === today) return;
  lastPromoGenerationDate = today;

  try {
    const result = await generateDailyLoyaltyPromo(now);
    if (result) {
      console.log(`[Scheduler] Promo code generated for ${result.user?.name || result.user?.email || 'top buyer'}: ${result.promoCode.code}`);
    }
  } catch (err) {
    console.error('[Scheduler] Promo generation failed', err.message);
  }
};
