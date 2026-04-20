import bcrypt   from 'bcrypt';
import jwt      from 'jsonwebtoken';
import User     from '../database/models/user.js';
import Operator from '../database/models/operator.js';

export const register = async ({ name, email, phone, password }) => {
  if (await User.findOne({ where: { email } })) throw new Error('Email already in use');
  const password_hash = await bcrypt.hash(password, 10);
  const user = await User.create({ name, email, phone, password_hash });
  return { id: user.id, name: user.name, email: user.email };
};

export const loginUser = async ({ email, password }) => {
  const user = await User.findOne({ where: { email } });
  if (!user) throw new Error('Invalid credentials');
  if (!await bcrypt.compare(password, user.password_hash)) throw new Error('Invalid credentials');

  const token = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
};

export const loginOperator = async ({ company_name, password }) => {
  const operator = await Operator.findOne({ where: { company_name } });
  if (!operator)           throw new Error('Invalid credentials');
  if (!operator.is_active) throw new Error('Account suspended');
  if (!await bcrypt.compare(password, operator.password_hash)) throw new Error('Invalid credentials');

  const token = jwt.sign(
    { id: operator.id, company_name: operator.company_name, role: 'operator' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return { token, operator: { id: operator.id, company_name: operator.company_name } };
};