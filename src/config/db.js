import dns from 'node:dns/promises';
import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is not set. Add the Supabase connection string to your .env file.');
}

// ── Force IPv4: resolve the DB hostname to an IPv4 address before connecting.
// Passing `host` explicitly via dialectOptions ensures pg never does its own
// DNS lookup that could return an unreachable IPv6 address (ENETUNREACH).
async function getSequelizeOptions(url) {
  const parsed = new URL(url);
  const hostname = parsed.hostname;

  let resolvedHost = hostname;
  try {
    const addresses = await dns.resolve4(hostname);
    if (addresses.length > 0) {
      resolvedHost = addresses[0];
      console.log(`[db] Resolved ${hostname} → ${resolvedHost} (IPv4)`);
    }
  } catch (err) {
    console.warn(`[db] IPv4 resolve failed for ${hostname}, using original hostname. Error: ${err.message}`);
  }

  return {
    url,
    options: {
      dialect: 'postgres',
      host: resolvedHost,
      port: parseInt(parsed.port, 10) || 5432,
      dialectOptions: {
        ssl: { require: true, rejectUnauthorized: false },
      },
      logging: false,
      pool: {
        max: 5,
        min: 0,
        acquire: 30000,
        idle: 10000,
      },
    },
  };
}

const { url, options } = await getSequelizeOptions(process.env.DATABASE_URL);
const sequelize = new Sequelize(url, options);

export default sequelize;
