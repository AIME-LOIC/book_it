import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';

// Immutable application-level backup for tickets archived after their
// retention period. Deliberately has no foreign keys to live operational
// tables so it survives deletion of the original ticket and related records.
const TicketArchive = sequelize.define('TicketArchive', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  original_ticket_id: { type: DataTypes.UUID, allowNull: false, unique: true },
  user_id: { type: DataTypes.UUID, allowNull: false },
  travel_date: { type: DataTypes.DATEONLY, allowNull: false },
  status: { type: DataTypes.STRING(20), allowNull: false },
  ticket_number: { type: DataTypes.STRING(20), allowNull: true },
  ticket_snapshot: { type: DataTypes.JSON, allowNull: false },
  archived_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
}, {
  tableName: 'ticket_archives',
  timestamps: true,
});

export default TicketArchive;
