import mysql from 'mysql2/promise';
import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

// Load local dotenv first if DOTENV_CONFIG_PATH set (e.g. .env.local)
const localEnvPath = process.env.DOTENV_CONFIG_PATH || '.env.local';
dotenv.config({ path: localEnvPath });

// Also load main .env (do not override values already set)
dotenv.config();

const localConfig = {
  host:     process.env.db_host || 'localhost',
  user:     process.env.db_user || 'root',
  password: process.env.db_password || '',
  database: process.env.db_name || 'bookit',
  port:     parseInt(process.env.db_port || '3306', 10),
};

if (!process.env.DATABASE_URL) {
  console.error('DATABASE_URL is not set. Cannot connect to Supabase/Postgres.');
  process.exit(1);
}

async function getSequelizeForUrl(url) {
  // Keep this minimal — rely on DATABASE_URL from env
  return new Sequelize(url, {
    dialect: 'postgres',
    dialectOptions: {
      ssl: { require: true, rejectUnauthorized: false }
    },
    logging: false,
  });
}

function buildInsertQuery(table, row) {
  const cols = Object.keys(row);
  const colList = cols.map(c => `\"${c}\"`).join(', ');
  const valList = cols.map(c => `:${c}`).join(', ');
  const updates = cols.filter(c => c !== 'id').map(c => `\"${c}\" = EXCLUDED.\"${c}\"`).join(', ');
  const conflict = cols.includes('id') ? 'ON CONFLICT (id) DO UPDATE SET ' + updates : 'ON CONFLICT DO NOTHING';
  const sql = `INSERT INTO \"${table}\" (${colList}) VALUES (${valList}) ${conflict}`;
  return sql;
}

async function migrate() {
  console.log('[migrate] Connecting to local MySQL', `${localConfig.user}@${localConfig.host}:${localConfig.port}/${localConfig.database}`);
  const localConn = await mysql.createConnection(localConfig);
  const sequelize = await getSequelizeForUrl(process.env.DATABASE_URL);

  try {
    await sequelize.authenticate();
    console.log('[migrate] Connected to Supabase/Postgres');

    // Ensure tables exist before inserting (this mirrors src/database/sync.js behavior)
    try {
      await sequelize.sync({ alter: true });
      console.log('[migrate] Ensured Postgres tables exist (sync complete)');
    } catch (err) {
      console.warn('[migrate] Warning: failed to run sync; continuing. Error:', err.message);
    }

    // Tables to copy — order matters for foreign keys
    const tables = ['locations','operators','operator_settings','users','routes','route_stops','buses','drivers','tickets','notifications'];

    for (const table of tables) {
      console.log(`[migrate] Reading table ${table} from local DB`);
      let rows = [];
      try {
        const [result] = await localConn.query(`SELECT * FROM ${table}`);
        rows = result;
      } catch (err) {
        console.warn(`[migrate] Skipping ${table}: could not read from local DB (${err.message})`);
        continue;
      }

      if (!rows || rows.length === 0) {
        console.log(`[migrate] No rows in ${table}, skipping`);
        continue;
      }

      console.log(`[migrate] ${rows.length} rows found in ${table}. Upserting into Supabase...`);

      // Insert rows in batches
      const batchSize = 50;
      for (let i = 0; i < rows.length; i += batchSize) {
        const batch = rows.slice(i, i + batchSize);
        const tx = await sequelize.transaction();
        try {
          for (const row of batch) {
            const sql = buildInsertQuery(table, row);
            await sequelize.query(sql, { replacements: row, transaction: tx });
          }
          await tx.commit();
          console.log(`[migrate] Upserted batch ${Math.floor(i / batchSize) + 1} for ${table}`);
        } catch (err) {
          await tx.rollback();
          console.error(`[migrate] Failed to upsert batch at ${i} for ${table}:`, err.message);
        }
      }

      console.log(`[migrate] Finished table ${table}`);
    }

    console.log('[migrate] Migration complete');
  } catch (err) {
    console.error('[migrate] Unexpected error:', err);
    process.exitCode = 1;
  } finally {
    try { await localConn.end(); } catch (e) {}
    try { await sequelize.close(); } catch (e) {}
  }
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
