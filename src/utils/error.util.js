// Central client-facing error formatter.
//
// Controllers intentionally return human-readable messages for business-rule
// errors ("Seat 3 is taken for this segment", "Email already in use", …),
// which are thrown as plain `Error`s. Infrastructure/library errors
// (SequelizeDatabaseError, connection failures, FK violations, …) may contain SQL,
// table names, or connection details — those must never reach the client.
//
// Rules applied here (defense in depth — the global Express handler in
// src/app.js applies the same policy to uncaught errors):
//   - plain Error / business-rule errors  → their message
//   - SequelizeValidationError            → first validation message
//   - SequelizeUniqueConstraintError      → generic duplicate message
//   - everything else                     → masked generic message
import { ValidationError, UniqueConstraintError } from 'sequelize';

const GENERIC = 'Something went wrong. Please try again.';

export const clientMessage = (err) => {
  if (!err) return GENERIC;
  if (err instanceof ValidationError) {
    return err.errors?.[0]?.message || 'Some fields are invalid';
  }
  if (err instanceof UniqueConstraintError) {
    return 'That value is already in use';
  }
  if (err?.name?.startsWith('Sequelize')) return GENERIC;
  if (err instanceof Error && err.message) {
    // Belt-and-braces: keep messages from our own thrown Errors, but mask
    // anything that looks like raw DB/driver output.
    if (/(SQLSTATE|ER_[A-Z_]+|ECONNREFUSED|ETIMEDOUT|ENOTFOUND|relation .* does not exist|Unknown column)/i.test(err.message)) {
      return GENERIC;
    }
    return err.message;
  }
  return String(err) || GENERIC;
};
