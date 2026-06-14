import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';
import Location  from './location.js';
import Operator  from './operator.js';

const Route = sequelize.define('Route', {
  id:               { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  operator_id:      { type: DataTypes.UUID, allowNull: false, references: { model: 'operators', key: 'id' } },
  from_location_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'locations', key: 'id' } },
  to_location_id:   { type: DataTypes.UUID, allowNull: false, references: { model: 'locations', key: 'id' } },
  price:            { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  is_reverse:       { type: DataTypes.BOOLEAN, defaultValue: false },
  parent_route_id:  { type: DataTypes.UUID, allowNull: true },
}, {
  tableName:  'routes',
  timestamps: false,
});

Route.belongsTo(Operator, { foreignKey: 'operator_id',      as: 'operator' });
Route.belongsTo(Location, { foreignKey: 'from_location_id', as: 'fromLocation' });
Route.belongsTo(Location, { foreignKey: 'to_location_id',   as: 'toLocation' });

export default Route;