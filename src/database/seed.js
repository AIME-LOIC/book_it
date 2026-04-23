import sequelize from '../config/db.js';
import User      from './models/user.js';
import Location  from './models/location.js';
import bcrypt    from 'bcrypt';
import path      from 'path';
import { pathToFileURL } from 'url';

export async function seedDatabase() {
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
}

// Allow running as a one-off script: `node src/database/seed.js`
if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  seedDatabase()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('❌ Seed failed:', err);
      process.exit(1);
    });
}
