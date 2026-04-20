import { DataTypes } from 'sequelize';
import sequelize  from '../../config/db.js';
import User       from './user.js';
import Bus        from './bus.js';
import Operator   from './operator.js';
import RouteStop  from './route_stop.js';

const Ticket = sequelize.define('Ticket', {
  id:               { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  user_id:          { type: DataTypes.UUID, allowNull: false, references: { model: 'users',       key: 'id' } },
  bus_id:           { type: DataTypes.UUID, allowNull: false, references: { model: 'buses',       key: 'id' } },
  operator_id:      { type: DataTypes.UUID, allowNull: false, references: { model: 'operators',   key: 'id' } },
  boarding_stop_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'route_stops', key: 'id' } },
  dropoff_stop_id:  { type: DataTypes.UUID, allowNull: false, references: { model: 'route_stops', key: 'id' } },
  seat_number:      { type: DataTypes.INTEGER,      allowNull: false },
  travel_date:      { type: DataTypes.DATEONLY,     allowNull: false },
  price:            { type: DataTypes.DECIMAL(10,2), allowNull: false },
  status:           { type: DataTypes.ENUM('pending','paid','cancelled'), defaultValue: 'pending' },
  ticket_number:    { type: DataTypes.STRING(20),   allowNull: true, unique: true },
  qr_token:         { type: DataTypes.TEXT,          allowNull: true },
}, {
  tableName:  'tickets',
  timestamps: true,
});

Ticket.belongsTo(User,      { foreignKey: 'user_id',          as: 'user' });
Ticket.belongsTo(Bus,       { foreignKey: 'bus_id',           as: 'bus' });
Ticket.belongsTo(Operator,  { foreignKey: 'operator_id',      as: 'operator' });
Ticket.belongsTo(RouteStop, { foreignKey: 'boarding_stop_id', as: 'boardingStop' });
Ticket.belongsTo(RouteStop, { foreignKey: 'dropoff_stop_id',  as: 'dropoffStop' });

export default Ticket;