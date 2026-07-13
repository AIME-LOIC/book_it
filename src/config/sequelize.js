import dns from 'node:dns/promises';
import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config({ path: process.env.DOTENV_CONFIG_PATH || '.env' });

const useLocal = process.env.USE_LOCAL_DB === 'true' || Boolean(process.env.DOTENV_CONFIG_PATH);

async function getOptions() {
  if (!useLocal && process.env.DATABASE_URL) {
    // Postgres (Supabase) — resolve IPv4 like previous db.js
    const parsed = new URL(process.env.DATABASE_URL);
    const hostname = parsed.hostname;
    let resolvedHost = hostname;
    try {
      const addresses = await dns.resolve4(hostname);
      if (addresses.length) resolvedHost = addresses[0];
    } catch (err) {
      // fall back to hostname
    }
    return {
      url: process.env.DATABASE_URL,
      options: {
        dialect: 'postgres',
        host: resolvedHost,
        port: parseInt(parsed.port, 10) || 5432,
        dialectOptions: { ssl: { require: true, rejectUnauthorized: false } },
        logging: false,
      }
    };
  }

  // Local MySQL via env vars (or .env.local via DOTENV_CONFIG_PATH)
  const host = process.env.db_host || 'localhost';
  const user = process.env.db_user || 'root';
  const password = process.env.db_password || '';
  const database = process.env.db_name || 'bookit';
  const port = parseInt(process.env.db_port || '3306', 10);

  const url = `mysql://${user}:${encodeURIComponent(password)}@${host}:${port}/${database}`;
  return {
    url,
    options: {
      dialect: 'mysql',
      host,
      port,
      username: user,
      password,
      database,
      logging: false,
    }
  };
}

const { url, options } = await getOptions();
const sequelize = new Sequelize(url, options);

export const isLocal = useLocal;
export default sequelize;
