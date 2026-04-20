import { DataTypes } from 'sequelize';
import sequelize from '../../config/db.js';

const Operator = sequelize.define('Operator', {
  id:            { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  company_name:  { type: DataTypes.STRING(100), allowNull: false, unique: true },
  contact:       { type: DataTypes.STRING(100), allowNull: true },
  password_hash: { type: DataTypes.STRING(255), allowNull: false },
  is_active:     { type: DataTypes.BOOLEAN, defaultValue: true },
}, { tableName: 'operators', timestamps: true });

export default Operator;