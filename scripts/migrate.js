import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sequelize from '../src/config/sequelize.js';

const root = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.join(root, '..', 'src', 'database', 'migrations');
const queryInterface = sequelize.getQueryInterface();

try {
  if (sequelize.getDialect() !== 'postgres') {
    throw new Error('The checked-in SQL migrations target PostgreSQL. Refusing to run them against another dialect.');
  }

  await sequelize.authenticate();
  await queryInterface.createTable('bookit_schema_migrations', {
    name: { type: (await import('sequelize')).DataTypes.STRING(255), allowNull: false, primaryKey: true },
    applied_at: { type: (await import('sequelize')).DataTypes.DATE, allowNull: false, defaultValue: (await import('sequelize')).DataTypes.NOW },
  });

  const appliedRows = await sequelize.query(
    'SELECT name FROM bookit_schema_migrations',
    { type: (await import('sequelize')).QueryTypes.SELECT },
  );
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
