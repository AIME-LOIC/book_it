import { DataTypes } from 'sequelize';
import db from '../../config/local.db.js';
import Operator from './operator.js';
import Route from './route.js';

const Bus = sequelize.define('Bus', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  operator_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'operators', key: 'id' } },
  route_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'routes', key: 'id' } },
  plate_number: { type: DataTypes.STRING(20), allowNull: false, unique: true },
  driver_name: { type: DataTypes.STRING(100), allowNull: false },
  capacity: { type: DataTypes.INTEGER, allowNull: false },
  departure_time: { type: DataTypes.STRING(8), allowNull: false },
  last_lat: { type: DataTypes.DECIMAL(10, 8), allowNull: true },
  last_lng: { type: DataTypes.DECIMAL(11, 8), allowNull: true },
  amenities: { type: DataTypes.JSONB, allowNull: false, defaultValue: [] },
  is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
}, { tableName: 'buses', timestamps: false });

Bus.belongsTo(Operator, { foreignKey: 'operator_id', as: 'operator' });
Bus.belongsTo(Route, { foreignKey: 'route_id', as: 'route' });

export default Bus;