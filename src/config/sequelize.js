import dns from 'node:dns/promises';
import { Sequelize } from 'sequelize';
import pg from 'pg';
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
        // Explicit import so Vercel's file tracer bundles `pg` (Sequelize loads it via a dynamic require it can't see)
        dialectModule: pg,
        host: resolvedHost,
        port: parseInt(parsed.port, 10) || 5432,
        dialectOptions: { ssl: { require: true, rejectUnauthorized: false } },
        logging: false,
      }
    };
  }

  // Local MySQL via env vars (or .env.local via DOTENV_CONFIG_PATH).
  // Accept both casings: earlier code read lowercase `db_*` while
  // documentation/.env.example used uppercase `DB_*` — which meant the
  // documented variables were silently ignored and the defaults (root,
  // localhost, bookit) were used instead.
  const env = (name) => process.env[name];
  const host    = env('DB_HOST')    || env('db_host')    || 'localhost';
  const user    = env('DB_USER')    || env('db_user')    || 'root';
  const password = env('DB_PASSWORD') ?? env('db_password') ?? '';
  const database = env('DB_NAME')    || env('db_name')    || 'bookit';
  const port    = parseInt(env('DB_PORT') || env('db_port') || '3306', 10);

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
