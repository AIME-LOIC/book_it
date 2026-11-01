import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { QueryTypes } from 'sequelize';
import sequelize from '../src/config/sequelize.js';

const root = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.join(root, '..', 'src', 'database', 'migrations');

try {
  if (sequelize.getDialect() !== 'postgres') {
    throw new Error('The checked-in SQL migrations target PostgreSQL. Refusing to run them against another dialect.');
  }

  await sequelize.authenticate();
  await sequelize.query(`CREATE TABLE IF NOT EXISTS bookit_schema_migrations (\n    name VARCHAR(255) PRIMARY KEY,\n    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP\n  )`);\n\n  const appliedRows = await sequelize.query(\n    'SELECT name FROM bookit_schema_migrations',\n    { type: QueryTypes.SELECT },\n  );
  const applied = new Set(appliedRows.map((row) => row.name));
  const files = (await fs.readdir(migrationsDir))
    .filter((name) => name.endsWith('.sql'))
    .sort();

  for (const name of files) {
    if (applied.has(name)) {
      console.log(`[Migrations] Skipping already applied: ${name}`);
      continue;
    }

    const sql = await fs.readFile(path.join(migrationsDir, name), 'utf8');
    console.log(`[Migrations] Applying: ${name}`);
    await sequelize.query(sql);
    await sequelize.query(
      'INSERT INTO bookit_schema_migrations (name, applied_at) VALUES (:name, CURRENT_TIMESTAMP)',
      { replacements: { name } },
    );
    console.log(`[Migrations] Applied: ${name}`);
  }

  console.log('[Migrations] Database is up to date.');
} catch (error) {
  console.error('[Migrations] Failed:', error?.stack || error);
  process.exitCode = 1;
} finally {
  await sequelize.close();
}
