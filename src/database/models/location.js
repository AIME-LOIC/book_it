import { DataTypes } from 'sequelize';
import sequelize from '../../config/db.js';

const Location = sequelize.define('Location', {
  id:   { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  name: { type: DataTypes.STRING(100), allowNull: false, unique: true },
}, { tableName: 'locations', timestamps: false });

export default Location;