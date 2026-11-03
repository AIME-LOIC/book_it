# BookIt security operations

## Shared production rate limits

Production rate limits use atomic counters in the primary PostgreSQL database. This avoids the per-instance counter reset/bypass problem on Vercel serverless functions.

Before deploying the security changes, apply the migration to the production database:

```bash
npm run db:migrate
```

Run this command with the production `DATABASE_URL` configured in a secure environment. The migration creates `security_rate_limits`; do not paste database credentials into GitHub or commit an environment file.

Current limits:
- General API: 100 requests per IP per minute (per-instance; this is a coarse abuse guard, not the primary authentication defense).
- Login: 30 requests per IP and 5 attempts per account per 15 minutes, shared across passenger, operator, and driver login routes.
- Ticket validation: 20 requests per IP per minute.
- Locker password verification: 3 attempts per authenticated user per 10 minutes.

If the persistent counter table is missing or unavailable in production, the limiter intentionally fails closed with HTTP 503 rather than silently falling back to per-instance memory counters.

## Credential handling

New driver initial passwords are generated with 128 bits of cryptographically secure randomness. Drivers should change their initial password immediately. Existing driver credentials are not automatically changed by this code update.

Login failures use a generic response so callers cannot distinguish unknown accounts, incorrect passwords, or suspended accounts.

## Verification still required

After applying the migration and deploying:
1. Confirm the health endpoint responds.
2. Test successful passenger, operator, and driver logins.
3. Use a dedicated test account to confirm the sixth failed attempt for one account is rate-limited with HTTP 429.
4. Confirm requests from a second client/IP still share the account-level limit.
5. Confirm ticket validation returns HTTP 429 after its configured threshold.
6. Review Vercel function logs for `[SECURITY] Persistent rate limiter unavailable`.

Do not perform brute-force testing against real customer accounts or production credentials.
