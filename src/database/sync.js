import sequelize          from '../config/sequelize.js';
import './models/location.js';
import './models/user.js';
import './models/operator.js';
import './models/operator_settings.js';
import './models/route.js';
import './models/route_stop.js';
import './models/bus.js';
import './models/driver.js';
import './models/ticket.js';
import './models/notification.js';

await sequelize.sync({ alter: true });
console.log('✅ All tables synced');
process.exit(0);