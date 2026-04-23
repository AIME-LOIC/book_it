import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

const pool = {
  max: 3,
  min: 0,
  acquire: 30000,
  idle: 10000,
};

let sequelize;

if (process.env.DATABASE_URL) {
  // Render / production PostgreSQL
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'postgres',
    dialectOptions: { ssl: { require: true, rejectUnauthorized: false } },
    logging: false,
    pool,
  });
} else {
  // Local MySQL (XAMPP)
  sequelize = new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASSWORD,
    {
      host:    process.env.DB_HOST,
      port:    process.env.DB_PORT || 3306,
      dialect: 'mysql',
      dialectOptions: (process.env.DB_HOST === 'localhost' || process.env.DB_HOST === '127.0.0.1')
        ? {}
        : { ssl: { require: true, rejectUnauthorized: false } },
      logging: false,
      pool,
    }
  );
}

export default sequelize;
