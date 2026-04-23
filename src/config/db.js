import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

const pool = {
  max: 3,        // max 3 connections — stays well under FreedB's limit
  min: 0,        // release connections when idle
  acquire: 30000,
  idle: 10000,   // close connection after 10s idle
};

let sequelize;

if (process.env.DATABASE_URL) {
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'mysql',
    dialectOptions: { ssl: { require: true, rejectUnauthorized: false } },
    logging: false,
    pool,
  });
} else {
  sequelize = new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASSWORD,
    {
      host:    process.env.DB_HOST,
      port:    process.env.DB_PORT || 3306,
      dialect: 'mysql',
      dialectOptions: process.env.DB_HOST !== 'localhost'
        ? { ssl: { require: true, rejectUnauthorized: false } }
        : {},
      logging: false,
      pool,
    }
  );
}

export default sequelize;
