import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';
import Operator  from './operator.js';
import Bus       from './bus.js';

const Driver = sequelize.define('Driver', {
  id:                  { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  operator_id:         { type: DataTypes.UUID, allowNull: false, references: { model: 'operators', key: 'id' } },
  bus_id:              { type: DataTypes.UUID, allowNull: true,  references: { model: 'buses',     key: 'id' }, unique: true },
  last_lat:            { type: DataTypes.DECIMAL(10,8), allowNull: true },
  last_lng:            { type: DataTypes.DECIMAL(11,8), allowNull: true },
  name:                { type: DataTypes.STRING(100), allowNull: false },
  email:               { type: DataTypes.STRING(150), allowNull: true,  unique: true },
  phone:               { type: DataTypes.STRING(20),  allowNull: false, unique: true },
  password_hash:       { type: DataTypes.STRING(255), allowNull: false },
  default_password:    { type: DataTypes.STRING(100), allowNull: true },
  must_update_profile: { type: DataTypes.BOOLEAN, defaultValue: true },
  is_active:           { type: DataTypes.BOOLEAN, defaultValue: true },
}, {
  tableName:  'drivers',
  timestamps: true,
});

Driver.belongsTo(Operator, { foreignKey: 'operator_id', as: 'operator' });
Driver.belongsTo(Bus,      { foreignKey: 'bus_id',      as: 'bus' });

export default Driver;