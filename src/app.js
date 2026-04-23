import express            from 'express';
import dotenv             from 'dotenv';
import path               from 'path';
import { fileURLToPath }  from 'url';
import os                 from 'os';
import rateLimit          from 'express-rate-limit';
import helmet             from 'helmet';
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
import { checkDepartedBuses, checkMidnightReactivation } from './services/scheduler.service.js';


dotenv.config();

// Fail fast if critical env vars are missing
const required = ['JWT_SECRET', 'QR_SECRET', 'DB_HOST', 'DB_USER', 'DB_NAME'];
for (const key of required) {
  if (!process.env[key]) { console.error(`Missing required env var: ${key}`); process.exit(1); }
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();

// ── SECURITY HEADERS ─────────────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: false, // disabled so CDN scripts (Tailwind, FA) still load
  crossOriginEmbedderPolicy: false,
}));

app.use(express.json());
app.use(cors({
  origin: (origin, callback) => {
    // allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);
    // production: check against ALLOWED_ORIGINS env var
    const envOrigins = (process.env.ALLOWED_ORIGINS || '')
      .split(',')
      .map(o => o.trim())
      .filter(Boolean);
    if (envOrigins.includes(origin)) return callback(null, true);
    // development: allow localhost and LAN
    const isLAN = /^http:\/\/(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+)(:\d+)?$/.test(origin);
    if (isLAN) return callback(null, true);
    return callback(new Error('CORS: origin not allowed'));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

// ── RATE LIMITING ─────────────────────────────────────────────
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,                   // max 10 attempts per IP
  message: { message: 'Too many login attempts. Please try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,  // 1 minute
  max: 100,             // max 100 requests per IP per minute
  message: { message: 'Too many requests. Please slow down.' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api/', apiLimiter);
app.use('/api/auth/login',          loginLimiter);
app.use('/api/auth/operator/login', loginLimiter);
app.use('/api/drivers/login',       loginLimiter);

// Serve frontend static files
app.use(express.static(path.join(__dirname, '../frontend')));

// Explicit page routes
app.get('/',          (req, res) => res.sendFile(path.join(__dirname, '../frontend/index.html')));
app.get('/book',      (req, res) => res.sendFile(path.join(__dirname, '../frontend/user.html')));
app.get('/operator',  (req, res) => res.sendFile(path.join(__dirname, '../frontend/operator.html')));
app.get('/driver',    (req, res) => res.sendFile(path.join(__dirname, '../frontend/driver.html')));
app.get('/admin',     (req, res) => res.sendFile(path.join(__dirname, '../frontend/admin.html')));

app.use('/api/auth',          authRoutes);
app.use('/api/locations',     locationRoutes);
app.use('/api/operators',     operatorRoutes);
app.use('/api/routes',        routeRoutes);
app.use('/api/route-stops',   routeStopRoutes);
app.use('/api/buses',         busRoutes);
app.use('/api/drivers',       driverRoutes);
app.use('/api/tickets',       ticketRoutes);
app.use('/api/notifications', notificationRoutes);

const PORT = process.env.PORT || 2000;
const HOST = '0.0.0.0';
app.listen(PORT, HOST, () => {
  const nets = os.networkInterfaces();
  let lanIP = 'localhost';
  for (const iface of Object.values(nets)) {
    for (const net of iface) {
      if (net.family === 'IPv4' && !net.internal) { lanIP = net.address; break; }
    }
  }
  console.log(` BookIt running on:`);
  console.log(`   Local:   http://localhost:${PORT}`);
  console.log(`   Network: http://${lanIP}:${PORT}`);
  checkDepartedBuses();
  checkMidnightReactivation();
  setInterval(() => {
    checkDepartedBuses();
    checkMidnightReactivation();
  }, 60 * 1000);
});

export default app;