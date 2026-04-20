import bcrypt   from 'bcrypt';
import Operator from '../database/models/operator.js';

export const createOperator = async ({ company_name, contact }) => {
  if (await Operator.findOne({ where: { company_name } })) {
    throw new Error('Operator already exists');
  }
  const initials      = company_name.split(' ').map(w => w[0].toUpperCase()).join('');
  const plainPassword = `${initials}@Bookit1`;
  const password_hash = await bcrypt.hash(plainPassword, 10);
  const operator      = await Operator.create({ company_name, contact, password_hash });

  return {
    id:               operator.id,
    company_name:     operator.company_name,
    contact:          operator.contact,
    default_password: plainPassword,
  };
};

export const getAllOperators = async () => {
  return await Operator.findAll({
    attributes: ['id', 'company_name', 'contact', 'is_active', 'createdAt'],
    order: [['company_name', 'ASC']],
  });
};

export const getOperatorById = async (id) => {
  const op = await Operator.findByPk(id, {
    attributes: ['id', 'company_name', 'contact', 'is_active'],
  });
  if (!op) throw new Error('Operator not found');
  return op;
};

export const updateOperator = async (id, data) => {
  const op = await Operator.findByPk(id);
  if (!op) throw new Error('Operator not found');
  return await op.update(data);
};

export const changePassword = async (id, { old_password, new_password }) => {
  const op = await Operator.findByPk(id);
  if (!op) throw new Error('Operator not found');
  if (!await bcrypt.compare(old_password, op.password_hash)) {
    throw new Error('Old password is incorrect');
  }
  await op.update({ password_hash: await bcrypt.hash(new_password, 10) });
  return { message: 'Password updated successfully' };
};

export const toggleActive = async (id) => {
  const op = await Operator.findByPk(id);
  if (!op) throw new Error('Operator not found');
  await op.update({ is_active: !op.is_active });
  return { id: op.id, is_active: op.is_active };
};

export const deleteOperator = async (id) => {
  const op = await Operator.findByPk(id);
  if (!op) throw new Error('Operator not found');
  await op.destroy();
};