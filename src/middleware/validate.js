import { body, param, query, validationResult } from 'express-validator';

// ── HELPER ────────────────────────────────────────────
export const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ message: errors.array()[0].msg });
  }
  next();
};

// ── AUTH ──────────────────────────────────────────────
export const validateRegister = [
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ max: 100 }).withMessage('Name too long'),
  body('email').trim().isEmail().withMessage('Valid email required').normalizeEmail(),
  body('phone').trim().notEmpty().withMessage('Phone is required').isLength({ max: 20 }),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  validate,
];

export const validateLogin = [
  body('email').trim().isEmail().withMessage('Valid email required').normalizeEmail(),
  body('password').notEmpty().withMessage('Password is required'),
  validate,
];

export const validateOperatorLogin = [
  body('company_name').trim().notEmpty().withMessage('Company name is required'),
  body('password').notEmpty().withMessage('Password is required'),
  validate,
];

export const validateDriverLogin = [
  body('phone').trim().notEmpty().withMessage('Phone is required'),
  body('password').notEmpty().withMessage('Password is required'),
  validate,
];

// ── BUS ───────────────────────────────────────────────
export const validateCreateBus = [
  body('route_id').isUUID().withMessage('Invalid route ID'),
  body('plate_number').trim().notEmpty().withMessage('Plate number required').isLength({ max: 20 }).matches(/^[A-Z0-9\s]+$/i).withMessage('Invalid plate number format'),
  body('driver_name').trim().notEmpty().withMessage('Driver name required').isLength({ max: 100 }),
  body('capacity').isInt({ min: 1, max: 100 }).withMessage('Capacity must be between 1 and 100'),
  body('departure_time').matches(/^\d{2}:\d{2}(:\d{2})?$/).withMessage('Invalid time format (HH:MM)'),
  validate,
];

// ── TICKET ────────────────────────────────────────────
export const validateBookTicket = [
  body('bus_id').isUUID().withMessage('Invalid bus ID'),
  body('boarding_stop_id').isUUID().withMessage('Invalid boarding stop'),
  body('dropoff_stop_id').isUUID().withMessage('Invalid dropoff stop'),
  body('seat_number').isInt({ min: 1 }).withMessage('Invalid seat number'),
  body('travel_date').isDate().withMessage('Invalid travel date (YYYY-MM-DD)'),
  validate,
];

// ── ROUTE ─────────────────────────────────────────────
export const validateCreateRoute = [
  body('from_location_id').isUUID().withMessage('Invalid from location'),
  body('to_location_id').isUUID().withMessage('Invalid to location'),
  body('price').isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  validate,
];

// ── DRIVER ────────────────────────────────────────────
export const validateCreateDriver = [
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ max: 100 }),
  body('phone').trim().notEmpty().withMessage('Phone is required').isLength({ max: 20 }),
  body('bus_id').optional().isUUID().withMessage('Invalid bus ID'),
  validate,
];

// ── LOCATION ──────────────────────────────────────────
export const validateCreateLocation = [
  body('name').trim().notEmpty().withMessage('Location name is required').isLength({ max: 100 }).matches(/^[a-zA-Z\s\-']+$/).withMessage('Location name contains invalid characters'),
  validate,
];
