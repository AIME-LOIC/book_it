import express            from 'express';
import dotenv             from 'dotenv';
import path               from 'path';
import { fileURLToPath }  from 'url';
import authRoutes         from './routes/auth.routes.js';
import locationRoutes     from './routes/location.routes.js';
import operatorRoutes     from './routes/operator.routes.js';
import routeRoutes        from './routes/route.routes.js';
import routeStopRoutes    from './routes/route_stop.routes.js';
import busRoutes          from './routes/bus.routes.js';
import driverRoutes       from './routes/driver.routes.js';
import ticketRoutes       from './routes/ticket.routes.js';
import notificationRoutes from './routes/notification.routes.js';
import cors               from 'cors';

dotenv.config();


const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();
app.use(express.json());
app.use(cors());

// Serve frontend static files
app.use(express.static(path.join(__dirname, '../frontend')));

app.use('/api/auth',          authRoutes);
app.use('/api/locations',     locationRoutes);
app.use('/api/operators',     operatorRoutes);
app.use('/api/routes',        routeRoutes);
app.use('/api/route-stops',   routeStopRoutes);
app.use('/api/buses',         busRoutes);
app.use('/api/drivers',       driverRoutes);
app.use('/api/tickets',       ticketRoutes);
app.use('/api/notifications', notificationRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(` BookIt running on port ${PORT}`));

export default app;