import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';

const Location = sequelize.define('Location', {
  id:        { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  name:      { type: DataTypes.STRING(100), allowNull: false, unique: true },
  // Coordinates identify the registered boarding terminal, not the town centre.
  // Nullable until the exact terminal pin has been verified.
  latitude:  { type: DataTypes.DECIMAL(10, 8), allowNull: true },
  longitude: { type: DataTypes.DECIMAL(11, 8), allowNull: true },
}, { tableName: 'locations', timestamps: false });

export default Location;
