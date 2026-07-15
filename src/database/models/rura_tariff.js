import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';
import Location  from './location.js';

// Manually transcribed from RURA's published tariff PDFs — those are
// scanned images with no extractable text, so this can't be scripted.
// Suggestion only: createRoute() looks this up and returns it as a
// starting price the operator can accept or override, never enforced.
const RuraTariff = sequelize.define('RuraTariff', {
  id:               { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  from_location_id: { type: DataTypes.UUID, allowNull: false, references: { model: 'locations', key: 'id' } },
  to_location_id:   { type: DataTypes.UUID, allowNull: false, references: { model: 'locations', key: 'id' } },
  price:            { type: DataTypes.DECIMAL(10, 2), allowNull: false },
}, {
  tableName:  'rura_tariffs',
  timestamps: true,
  indexes: [{ unique: true, fields: ['from_location_id', 'to_location_id'] }],
});
RuraTariff.belongsTo(Location, { foreignKey: 'from_location_id', as: 'fromLocation' });
RuraTariff.belongsTo(Location, { foreignKey: 'to_location_id',   as: 'toLocation' });
export default RuraTariff;
