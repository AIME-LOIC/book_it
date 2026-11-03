import crypto from 'node:crypto';
import { QueryTypes } from 'sequelize';
import sequelize from '../config/sequelize.js';

// Atomic counters in the primary database are shared across Vercel instances.
export const createPersistentRateLimiter = ({ name, windowMs, max, key }) => {
  if (!name || !Number.isInteger(windowMs) || windowMs < 1 || !Number.isInteger(max) || max < 1 || typeof key !== 'function') {
    throw new TypeError('Invalid persistent rate limiter configuration');
  }
  return async (req, res, next) => {
    const identity = String(key(req) || 'unknown').slice(0, 512);
    const digest = crypto.createHash('sha256').update(identity).digest('hex');
    const rateKey = name + ':' + digest;
    try {
      let rows;
      if (sequelize.getDialect() === 'postgres') {
        rows = await sequelize.query(
          "INSERT INTO security_rate_limits (rate_key, hit_count, expires_at) VALUES (:rateKey, 1, CURRENT_TIMESTAMP + (:windowMs * INTERVAL '1 millisecond')) " +
          'ON CONFLICT (rate_key) DO UPDATE SET hit_count = CASE WHEN security_rate_limits.expires_at <= CURRENT_TIMESTAMP THEN 1 ELSE security_rate_limits.hit_count + 1 END, ' +
          "expires_at = CASE WHEN security_rate_limits.expires_at <= CURRENT_TIMESTAMP THEN CURRENT_TIMESTAMP + (:windowMs * INTERVAL '1 millisecond') ELSE security_rate_limits.expires_at END, updated_at = CURRENT_TIMESTAMP RETURNING hit_count, expires_at",
          { replacements: { rateKey, windowMs }, type: QueryTypes.SELECT },
        );
      } else if (sequelize.getDialect() === 'mysql') {
        await sequelize.query(
          'INSERT INTO security_rate_limits (rate_key, hit_count, expires_at) VALUES (:rateKey, 1, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL :windowMicros MICROSECOND)) ' +
          'ON DUPLICATE KEY UPDATE hit_count = IF(expires_at <= CURRENT_TIMESTAMP, 1, hit_count + 1), ' +
          'expires_at = IF(expires_at <= CURRENT_TIMESTAMP, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL :windowMicros MICROSECOND), expires_at), updated_at = CURRENT_TIMESTAMP',
          { replacements: { rateKey, windowMicros: windowMs * 1000 } },
        );
        rows = await sequelize.query('SELECT hit_count, expires_at FROM security_rate_limits WHERE rate_key = :rateKey', { replacements: { rateKey }, type: QueryTypes.SELECT });
      } else {
        throw new Error('Unsupported database dialect for persistent rate limiting');
      }
      const row = rows[0];
      if (!row) throw new Error('Rate-limit counter was not returned');
      // Opportunistic cleanup keeps expired identifiers from accumulating.
      if (Math.random() < 0.01) await sequelize.query('DELETE FROM security_rate_limits WHERE expires_at < CURRENT_TIMESTAMP');
      if (Number(row.hit_count) > max) {
        const retrySeconds = Math.max(1, Math.ceil((new Date(row.expires_at).getTime() - Date.now()) / 1000));
        res.set('Retry-After', String(retrySeconds));
        return res.status(429).json({ message: 'Too many requests. Please try again later.' });
      }
      return next();
    } catch (error) {
      // Fail closed instead of silently reverting to per-instance counters.
      console.error('[SECURITY] Persistent rate limiter unavailable:', error.message);
      return res.status(503).json({ message: 'Security service temporarily unavailable. Please try again shortly.' });
    }
  };
}
