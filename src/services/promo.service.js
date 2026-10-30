import crypto from 'crypto';
import { Op } from 'sequelize';
import sequelize from '../config/sequelize.js';
import PromoCode from '../database/models/promo_code.js';
import Ticket from '../database/models/ticket.js';
import User from '../database/models/user.js';
import { createNotification } from './notification.service.js';

export const buildPromoCodeValue = (issuedAt = new Date()) => {
  const stamp = `${issuedAt.getUTCFullYear()}${String(issuedAt.getUTCMonth() + 1).padStart(2, '0')}${String(issuedAt.getUTCDate()).padStart(2, '0')}-${String(issuedAt.getUTCHours()).padStart(2, '0')}${String(issuedAt.getUTCMinutes()).padStart(2, '0')}`;
  const randomPart = crypto.randomBytes(3).toString('hex').toUpperCase();
  return `BK-${stamp}-${randomPart}`;
};

export const generateDailyLoyaltyPromo = async (issuedAt = new Date()) => {
  const start = new Date(issuedAt);
  start.setUTCDate(start.getUTCDate() - 30);

  const topBuyer = await Ticket.findOne({
    where: {
      createdAt: { [Op.gte]: start },
      status: { [Op.in]: ['paid', 'pending'] },
    },
    attributes: ['user_id'],
    group: ['user_id'],
    order: [[sequelize.fn('COUNT', sequelize.col('id')), 'DESC']],
    limit: 1,
    raw: true,
  });

  if (!topBuyer?.user_id) return null;

  const existingCode = await PromoCode.findOne({
    where: { recipient_id: topBuyer.user_id, status: 'active' },
    order: [['generated_at', 'DESC']],
  });

  const todayKey = issuedAt.toISOString().split('T')[0];
  if (existingCode?.metadata?.day_key === todayKey) return existingCode;

  const codeValue = buildPromoCodeValue(issuedAt);
  const expiresAt = new Date(issuedAt);
  expiresAt.setUTCDate(expiresAt.getUTCDate() + 1);

  const promoCode = await PromoCode.create({
    code: codeValue,
    recipient_id: topBuyer.user_id,
    recipient_type: 'user',
    status: 'active',
    generated_at: issuedAt,
    expires_at: expiresAt,
    metadata: { day_key: todayKey, issued_from: 'daily-loyalty' },
  });

  const user = await User.findByPk(topBuyer.user_id, { attributes: ['id', 'name', 'email'] });
  await createNotification({
    recipient_id: topBuyer.user_id,
    recipient_type: 'user',
    type: 'promo_code_generated',
    message: `Your daily promo code is ${promoCode.code}. It can be used once and expires at the end of the day.`,
    meta: { promo_code: promoCode.code, promo_code_id: promoCode.id, day_key: todayKey },
  });

  return { promoCode, user };
};

export const validateAndConsumePromoCode = async ({ code, recipient_id, ticket_id }) => {
  const promoCode = await PromoCode.findOne({
    where: {
      code: String(code).trim().toUpperCase(),
      recipient_id,
      status: 'active',
      [Op.or]: [{ expires_at: { [Op.gt]: new Date() } }, { expires_at: null }],
    },
  });

  if (!promoCode) throw new Error('Invalid or expired promo code');

  await promoCode.update({ status: 'used', used_at: new Date(), ticket_id });
  return promoCode;
};
