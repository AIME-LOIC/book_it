import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';

const DevicePushToken = sequelize.define('DevicePushToken', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  recipient_id: { type: DataTypes.UUID, allowNull: false },
  recipient_type: { type: DataTypes.STRING(20), allowNull: false },
  token: { type: DataTypes.TEXT, allowNull: false },
  token_hash: { type: DataTypes.STRING(64), allowNull: false, unique: true },
  platform: { type: DataTypes.STRING(10), allowNull: false },
  last_seen_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
}, { tableName: 'device_push_tokens', timestamps: true });

export default DevicePushToken;
