#!/usr/bin/env node
console.log('ensure-location-columns: starting');
import sequelize from '../src/config/sequelize.js';
import { DataTypes } from 'sequelize';

async function ensureColumns() {
  const qi = sequelize.getQueryInterface();
  const targets = ['drivers', 'buses'];

  for (const table of targets) {
    let desc = null;
    try {
      desc = await qi.describeTable(table);
    } catch (err) {
      console.warn(`Table '${table}' not found, skipping.`);
      continue;
    }

    if (!desc.last_lat) {
      console.log(`Adding column last_lat to ${table}`);
      await qi.addColumn(table, 'last_lat', { type: DataTypes.FLOAT, allowNull: true });
    } else {
      console.log(`${table}.last_lat exists`);
    }

    if (!desc.last_lng) {
      console.log(`Adding column last_lng to ${table}`);
      await qi.addColumn(table, 'last_lng', { type: DataTypes.FLOAT, allowNull: true });
    } else {
      console.log(`${table}.last_lng exists`);
    }
  }

  await sequelize.close();
}

ensureColumns()
  .then(() => {
    console.log('Done ensuring location columns.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error ensuring columns:', err);
    process.exit(1);
  });
