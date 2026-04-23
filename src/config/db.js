import { Sequelize } from 'sequelize';
import dotenv from 'dotenv';

dotenv.config();

let sequelize;

if (process.env.DATABASE_URL) {
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'mysql',
    dialectOptions: {
      ssl: { require: true, rejectUnauthorized: false },
    },
    logging: false,
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
    }
  );
}

export default sequelize;
