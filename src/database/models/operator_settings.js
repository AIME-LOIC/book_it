import { DataTypes } from 'sequelize';
import sequelize from '../../config/sequelize.js';
import Operator  from './operator.js';

const OperatorSettings = sequelize.define('OperatorSettings', {
  id:                    { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  operator_id:           { type: DataTypes.UUID, allowNull: false, unique: true, references: { model: 'operators', key: 'id' } },
  allow_manual_reverse:  { type: DataTypes.BOOLEAN, defaultValue: true },
  auto_generate_reverse: { type: DataTypes.BOOLEAN, defaultValue: true },
}, {
  tableName:  'operator_settings',
  timestamps: false,
});

OperatorSettings.belongsTo(Operator, { foreignKey: 'operator_id', as: 'operator' });

export default OperatorSettings;