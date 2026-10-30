import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';
import User from './user.js';

const PromoCode = sequelize.define('PromoCode', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  code: { type: DataTypes.STRING(40), allowNull: false, unique: true },
  recipient_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'users', key: 'id' } },
  recipient_type: { type: DataTypes.ENUM('user', 'operator', 'admin', 'driver'), allowNull: false, defaultValue: 'user' },
  status: { type: DataTypes.ENUM('active', 'used', 'expired'), allowNull: false, defaultValue: 'active' },
  generated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  expires_at: { type: DataTypes.DATE, allowNull: true },
  used_at: { type: DataTypes.DATE, allowNull: true },
  ticket_id: { type: DataTypes.UUID, allowNull: true, references: { model: 'tickets', key: 'id' } },
  metadata: { type: DataTypes.JSON, allowNull: true },
}, {
  tableName: 'promo_codes',
  timestamps: true,
});

PromoCode.belongsTo(User, { foreignKey: 'recipient_id', as: 'recipient' });

export default PromoCode;
