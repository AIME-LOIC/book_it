import { DataTypes } from 'sequelize';
import sequelize from '../../config/db.js';

const Notification = sequelize.define('Notification', {
  id:             { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  recipient_id:   { type: DataTypes.UUID, allowNull: false },
  recipient_type: { type: DataTypes.ENUM('user', 'operator', 'admin', 'driver'), allowNull: false },
  type:           {
    type: DataTypes.ENUM(
      'ticket_booked',
      'ticket_paid',
      'ticket_cancelled',
      'bus_arrived',
      'new_booking'       // operator gets this when user books on their bus
    ),
    allowNull: false,
  },
  message:        { type: DataTypes.STRING(255), allowNull: false },
  meta:           { type: DataTypes.JSON, allowNull: true }, // extra data e.g ticket_id, bus_id
  is_read:        { type: DataTypes.BOOLEAN, defaultValue: false },
}, {
  tableName:  'notifications',
  timestamps: true,
});

export default Notification;