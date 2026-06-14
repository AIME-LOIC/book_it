import express from 'express';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import os from 'os';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import authRoutes from './routes/auth.routes.js';
import locationRoutes from './routes/location.routes.js';
import operatorRoutes from './routes/operator.routes.js';
import routeRoutes from './routes/route.routes.js';
import routeStopRoutes from './routes/route_stop.routes.js';
import busRoutes from './routes/bus.routes.js';
import driverRoutes from './routes/driver.routes.js';
import ticketRoutes from './routes/ticket.routes.js';
import notificationRoutes from './routes/notification.routes.js';
import cors from 'cors';
import { checkDepartedBuses, checkMidnightReactivation } from './services/scheduler.service.js';


dotenv.config();

// Fail fast if critical env vars are missing
const required = ['JWT_SECRET', 'QR_SECRET'];
const dbVars = process.env.DATABASE_URL
  ? ['DATABASE_URL']
  : ['DB_HOST', 'DB_USER', 'DB_NAME'];
for (const key of [...required, ...dbVars]) {
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

// Normalize trailing slashes on page routes so relative assets like `./api.js` resolve correctly.
// Example failure: visiting `/admin/` makes `./api.js` resolve to `/admin/api.js` (404) -> blank screen.
app.use((req, res, next) => {
  if ((req.method !== 'GET' && req.method !== 'HEAD') || req.path === '/') return next();
  if (req.path.startsWith('/rw/v1/bk')) return next();
  if (!req.path.endsWith('/')) return next();
  const q = req.url.includes('?') ? `?${req.url.split('?')[1]}` : '';
  return res.redirect(301, `${req.path.slice(0, -1)}${q}`);
});

// Lightweight health check for deployments (Render, etc.)
app.get('/healthz', (req, res) => res.status(200).send('ok'));

app.use(express.json());
app.use(cors({
  origin: (origin, callback) => {
    // allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);
    // production: check against ALLOWED_ORIGINS env var (strip trailing slashes)
    const envOrigins = (process.env.ALLOWED_ORIGINS || '')
      .split(',')
      .map(o => o.trim().replace(/\/+$/, ''))
      .filter(Boolean);
    const cleanOrigin = origin.replace(/\/+$/, '');
    // if ALLOWED_ORIGINS isn't set, don't block browser clients (common deployment pitfall)
    if (envOrigins.length === 0) return callback(null, true);
    if (envOrigins.includes(cleanOrigin)) return callback(null, true);
    // allow same render.com domain
    if (origin.endsWith('.onrender.com')) return callback(null, true);
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

const P = '/rw/v1/bk'; // obscure API prefix

app.use(`${P}/`, apiLimiter);
app.use(`${P}/auth/login`, loginLimiter);
app.use(`${P}/auth/operator/login`, loginLimiter);
app.use(`${P}/drivers/login`, loginLimiter);

// Serve frontend static files
app.use(express.static(path.join(__dirname, '../frontend')));

// Explicit page routes
app.get('/', (req, res) => res.sendFile(path.join(__dirname, '../frontend/index.html')));
app.get('/book', (req, res) => res.sendFile(path.join(__dirname, '../frontend/user.html')));
app.get('/operator', (req, res) => res.sendFile(path.join(__dirname, '../frontend/operator.html')));
app.get('/driver', (req, res) => res.sendFile(path.join(__dirname, '../frontend/driver.html')));
app.get('/admin', (req, res) => res.sendFile(path.join(__dirname, '../frontend/admin.html')));
app.get('/policy', (req, res) => res.sendFile(path.join(__dirname, '../frontend/policy.html')));
app.get('/docs', (req, res) => res.sendFile(path.join(__dirname, '../frontend/docs.html')));

app.use(`${P}/auth`, authRoutes);
app.use(`${P}/locations`, locationRoutes);
app.use(`${P}/operators`, operatorRoutes);
app.use(`${P}/routes`, routeRoutes);
app.use(`${P}/route-stops`, routeStopRoutes);
app.use(`${P}/buses`, busRoutes);
app.use(`${P}/drivers`, driverRoutes);
app.use(`${P}/tickets`, ticketRoutes);
app.use(`${P}/notifications`, notificationRoutes);

// Catch unmatched routes in the actual API prefix
app.use(`${P}/*any`, (req, res) => res.status(404).json({ message: 'API endpoint not found' }));

// Confuse scanners looking for common /api paths
app.use('/api/*any', (req, res) => res.status(404).json({ message: 'Not found' }));

// ── GLOBAL ERROR MIDDLEWARE ─────────────────────────────────────────────

// Global error handler — catches any error thrown in routes
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  if (process.env.NODE_ENV !== 'production') console.error(err.stack);
  if (err.message === 'CORS: origin not allowed') {
    return res.status(403).json({ message: 'CORS: origin not allowed' });
  }
  res.status(err.status || 500).json({
    message: process.env.NODE_ENV === 'production'
      ? 'Something went wrong. Please try again.'
      : err.message,
  });
});

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
