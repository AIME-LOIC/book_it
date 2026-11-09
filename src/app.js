import express from 'express';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import { createPersistentRateLimiter } from './middleware/persistent-rate-limit.js';
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
import internalRoutes from './routes/internal.routes.js';
import rfidCardRoutes from './routes/rfid-card.routes.js';
import rfidHardwareRoutes from './routes/rfid-hardware.routes.js';
import cors from 'cors';
import sequelize from './config/sequelize.js';


dotenv.config();

// Vercel serves public assets from its CDN. API requests validate runtime configuration
// and establish a reusable database connection before reaching controllers.

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

// On Vercel the Express function answers `/` before the vercel.json rewrite is applied,
// so send the root to the static landing page in public/.
if (process.env.VERCEL === '1') {
  app.get('/', (req, res) => res.redirect(302, '/index.html'));
}

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
// Production uses atomic PostgreSQL counters shared by all serverless instances.
// Local development retains the in-memory limiter so it works with MySQL too.
const persistent = process.env.NODE_ENV === 'production';
const makeLimiter = (name, windowMs, max, key) => persistent
  ? createPersistentRateLimiter({ name, windowMs, max, key })
  : rateLimit({ windowMs, max, standardHeaders: true, legacyHeaders: false,
      message: { message: 'Too many requests. Please try again later.' } });

const apiLimiter = rateLimit({ windowMs: 60 * 1000, max: 100, standardHeaders: true, legacyHeaders: false,
  message: { message: 'Too many requests. Please try again later.' } });
const loginIpLimiter = makeLimiter('login-ip', 15 * 60 * 1000, 30, (req) => req.ip);
const loginAccountLimiter = makeLimiter('login-account', 15 * 60 * 1000, 5, (req) => {
  const body = req.body || {};
  const identifier = body.email || body.company_name || body.phone || 'unknown';
  return String(identifier).trim().toLowerCase();
});
const ticketValidateLimiter = makeLimiter('ticket-validate', 60 * 1000, 20, (req) => req.ip);
const rfidPhoneRegistrationLimiter = makeLimiter('rfid-phone-registration', 15 * 60 * 1000, 10, (req) => req.ip);

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
app.use(`${P}/rfid-cards/phone-registration`, rfidPhoneRegistrationLimiter);
app.use(`${P}/auth/login`, loginIpLimiter, loginAccountLimiter);
app.use(`${P}/auth/operator/login`, loginIpLimiter, loginAccountLimiter);
app.use(`${P}/drivers/login`, loginIpLimiter, loginAccountLimiter);
app.use(`${P}/tickets/validate`, ticketValidateLimiter);

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
app.use(`${P}/internal/cron`, internalRoutes);
app.use(`${P}/rfid-cards`, rfidCardRoutes);
app.use(`${P}/hardware/rfid`, rfidHardwareRoutes);

// Customer downloads are proxied through BookIt so passengers never leave for GitHub.
const RELEASE_ASSETS = {
  android: { name: 'bookit-android.apk', path: 'app-release.apk', type: 'application/vnd.android.package-archive' },
  linux: { name: 'bookit-linux-x86_64.tar.gz', path: 'bookit-linux-x86_64.tar.gz', type: 'application/gzip' },
  checksum: { name: 'bookit-linux-x86_64.tar.gz.sha256', path: 'bookit-linux-x86_64.tar.gz.sha256', type: 'text/plain; charset=utf-8' },
};
app.get('/downloads/:asset', async (req, res, next) => {
  const asset = RELEASE_ASSETS[req.params.asset];
  if (!asset) return res.status(404).sendFile('404.html', { root: 'public' });
  try {
    const upstream = await fetch(`https://github.com/AIME-LOIC/book_it/releases/latest/download/${asset.path}`, {
      headers: { 'User-Agent': 'BookIt-Download-Service' },
      redirect: 'follow',
    });
    if (!upstream.ok || !upstream.body) {
      console.error('[DOWNLOAD] Release asset unavailable:', asset.path, upstream.status);
      return res.status(503).sendFile('503.html', { root: 'public' });
    }
    res.setHeader('Content-Type', asset.type);
    res.setHeader('Content-Disposition', `attachment; filename="${asset.name}"`);
    res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=60');
    const length = upstream.headers.get('content-length');
    if (length) res.setHeader('Content-Length', length);
    const { Readable } = await import('node:stream');
    Readable.fromWeb(upstream.body).on('error', next).pipe(res);
  } catch (error) {
    next(error);
  }
});

// API clients receive stable JSON errors; browser navigation receives branded pages.
app.use(`${P}/*any`, (req, res) => res.status(404).json({ message: 'API endpoint not found', status: 404 }));
app.use('/api/*any', (req, res) => res.status(404).json({ message: 'Not found', status: 404 }));

const ERROR_PAGES = new Set([400, 401, 403, 404, 409, 422, 429, 500, 502, 503]);
const isApiRequest = (req) => req.path.startsWith(P) || req.path.startsWith('/api/');
const sendStatusPage = (req, res, status) => {
  if (isApiRequest(req) || req.accepts('html') === false) {
    return res.status(status).json({ status, message: status === 500 ? 'Something went wrong. Please try again.' : 'The request could not be completed.' });
  }
  const page = ERROR_PAGES.has(status) ? `${status}.html` : '500.html';
  return res.status(status).sendFile(page, { root: 'public' });
};

// ── GLOBAL ERROR MIDDLEWARE ─────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  if (process.env.NODE_ENV !== 'production') console.error(err.stack);
  const status = Number(err.status || err.statusCode || 500);
  return sendStatusPage(req, res, ERROR_PAGES.has(status) ? status : 500);
});

// Unknown website pages end at a real HTTP 404 with a branded recovery page.
app.use((req, res) => sendStatusPage(req, res, 404));

// The app is exported for Vercel's Express runtime. Local listening and
// background schedulers are started by server.js only.

export default app;
