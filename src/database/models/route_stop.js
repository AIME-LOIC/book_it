import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';
import Location  from './location.js';
import Route     from './route.js';
const RouteStop = sequelize.define('RouteStop', {
  id:                { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  route_id:          { type: DataTypes.UUID, allowNull: false, references: { model: 'routes',    key: 'id' } },
  location_id:       { type: DataTypes.UUID, allowNull: false, references: { model: 'locations', key: 'id' } },
  stop_order:        { type: DataTypes.INTEGER, allowNull: false },
  price_from_origin: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
  // Which existing Route supplied this stop's price segment. Null for the
  // origin stop (stop_order 1, price 0) and for reverse-auto-generated
  // stops (their price is derived by subtraction, not a chained lookup).
  leg_route_id:      { type: DataTypes.UUID, allowNull: true, references: { model: 'routes', key: 'id' } },
}, {
  tableName:  'route_stops',
  timestamps: false,
  indexes: [{ unique: true, fields: ['route_id', 'stop_order'] }],
});
RouteStop.belongsTo(Route,    { foreignKey: 'route_id',     as: 'route' });
RouteStop.belongsTo(Route,    { foreignKey: 'leg_route_id', as: 'legRoute' });
RouteStop.belongsTo(Location, { foreignKey: 'location_id',  as: 'location' });
export default RouteStop;
