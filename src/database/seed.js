import sequelize from '../config/db.js';
import User      from './models/user.js';
import Location  from './models/location.js';
import bcrypt    from 'bcrypt';

await sequelize.authenticate();

const existing = await User.findOne({ where: { email: 'admin@bookit.rw' } });
if (!existing) {
  await User.create({
    name:          'BookIt Admin',
    email:         'admin@bookit.rw',
    phone:         '0780000000',
    password_hash: await bcrypt.hash('Admin@1234', 10),
    role:          'admin',
  });
  console.log('✅ Admin created');
  console.log('   email:    admin@bookit.rw');
  console.log('   password: Admin@1234');
}

await Location.bulkCreate([
  { name: 'Kigali'    },
  { name: 'Musanze'   },
  { name: 'Huye'      },
  { name: 'Rubavu'    },
  { name: 'Nyagatare' },
  { name: 'Rusizi'    },
], { ignoreDuplicates: true });

console.log('✅ Locations seeded');
process.exit(0);