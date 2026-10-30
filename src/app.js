import express from 'express';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
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
import promoRoutes from './routes/promo.routes.js';
import cors from 'cors';
import sequelize from './config/sequelize.js';


dotenv.config();

// Vercel serves public assets from its CDN. API requests validate runtime configuration
// and establish a reusable database connection before reaching controllers.

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const app = express();
app.set('trust proxy', 1);
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
    // allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);
    // normalize: strip trailing slashes, lowercase scheme+host comparison key
    const normalize = (o) => String(o).trim().replace(/\/+$/, '').toLowerCase();
    const envOrigins = (process.env.ALLOWED_ORIGINS || '')
      .split(',')
      .map(normalize)
      .filter(Boolean);
    const cleanOrigin = normalize(origin);
    const isProd = process.env.NODE_ENV === 'production';
    // production requires an allowlist — the startup check above makes this
    // non-empty, but if the variable ends up empty, fail closed.
    if (envOrigins.length === 0) {
      if (isProd) return callback(null, false);
      return callback(null, true); // dev convenience when no allowlist configured
    }
    if (envOrigins.includes(cleanOrigin)) return callback(null, true);
    // development only: allow localhost / 127.0.0.1 / LAN HTTP origins
    if (!isProd && /^http:\/\/(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+)(:\d+)?$/.test(cleanOrigin)) {
      return callback(null, true);
    }
    // never trust arbitrary hosted origins (*.onrender.com etc.) — deny
    return callback(null, false);
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
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

// Ticket redemption brute-force guard: ticket numbers follow BK-####-XX,
// so without a limiter a client could enumerate the whole ~590k space.
const ticketValidateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20, // 20 scans per minute per IP is far above manual throughput
  message: { message: 'Too many validation attempts. Please slow down.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const P = '/rw/v1/bk'; // obscure API prefix

let databaseReady;
app.use(P, async (req, res, next) => {
  const required = ['JWT_SECRET', 'QR_SECRET', 'DEFAULT_PW_SECRET', 'ALLOWED_ORIGINS'];
  const missing = required.filter((key) => !process.env[key]?.trim());
  if (!process.env.DATABASE_URL && !(process.env.DB_HOST && process.env.DB_USER && process.env.DB_NAME)) {
    missing.push('DATABASE_URL (or DB_HOST, DB_USER, DB_NAME)');
  }
  if (missing.length) {
    return res.status(503).json({
      message: 'BookIt server configuration is incomplete.',
      missing,
    });
  }
  try {
    databaseReady ||= sequelize.authenticate();
    await databaseReady;
    next();
  } catch (error) {
    databaseReady = null;
    console.error('[DB] Connection failed:', error.message);
    res.status(503).json({ message: 'BookIt database is unavailable.' });
  }
});

app.use(`${P}/`, apiLimiter);
app.use(`${P}/auth/login`, loginLimiter);
app.use(`${P}/auth/operator/login`, loginLimiter);
app.use(`${P}/drivers/login`, loginLimiter);
app.use(`${P}/tickets/validate`, ticketValidateLimiter);

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
app.use(`${P}/promos`, promoRoutes);

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

// The app is exported for Vercel's Express runtime. Local listening and
// background schedulers are started by server.js only.

export default app;
