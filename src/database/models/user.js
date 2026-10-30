import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';

const User = sequelize.define('User', {
  id:            { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  name:          { type: DataTypes.STRING(100), allowNull: false },
  email:         { type: DataTypes.STRING(150), allowNull: false, unique: true },
  phone:         { type: DataTypes.STRING(20),  allowNull: false },
  password_hash: { type: DataTypes.STRING(255), allowNull: false },
  role:          { type: DataTypes.ENUM('admin', 'user'), defaultValue: 'user' },
  flw_customer_id: { type: DataTypes.STRING, allowNull: true },
  terms_accepted_at: { type: DataTypes.DATE, allowNull: true },
  // flw_customer_id: { type: DataTypes.STRING, allowNull: true },

}, { tableName: 'users', timestamps: true });

export default User;