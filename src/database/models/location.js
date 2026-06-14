import { DataTypes } from 'sequelize';
import db from '../../config/local.db.js';

const Location = sequelize.define('Location', {
  id:   { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  name: { type: DataTypes.STRING(100), allowNull: false, unique: true },
}, { tableName: 'locations', timestamps: false });

export default Location;