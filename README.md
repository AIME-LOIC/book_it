# BookIt — Rwanda Bus Booking Platform

BookIt is a digital bus-ticketing platform for Rwanda. It connects passengers, bus operators, and drivers through one booking and operations system.

## Official demo

**Production demo:** [https://bookit.1percent.rw](https://bookit.1percent.rw)

The production project is deployed on **Vercel** from the `main` branch of this repository. Use the custom domain above for reviews and demonstrations. Do not use old preview deployment URLs as the project demo.

## What BookIt does

### Passengers
- Search available buses by origin, destination, and travel date.
- Choose seats and create reservations.
- View tickets and QR codes for boarding.
- Receive trip and booking notifications.
- Start MTN Mobile Money or Airtel Money payments through the Flutterwave integration, where live provider credentials and account approval are configured.
- Redeem one-time promotional codes.

### Bus operators
- Manage buses, drivers, routes, and schedules.
- Review bookings, passenger manifests, and ticket sales.
- Manage route stops and operational availability.

### Drivers
- View assigned trips and passenger manifests.
- Scan QR tickets and validate ticket numbers.
- Update the assigned bus location from the driver application.

## Payment status and scope

The codebase integrates MTN Mobile Money and Airtel Money payment initiation and payment-status handling through **Flutterwave**, including a Flutterwave webhook. Actual payment completion depends on correctly configured live Flutterwave credentials and provider approval. Promo-code redemption is a separate in-app flow.

There is no separate MRT Wallet integration in the current application. Do not describe BookIt as having an MRT Wallet.

## Live map status

**Passenger-facing live bus map: coming soon.** It is intentionally not part of the demo while live-map reliability is being completed. Driver location updates are separate from the passenger-facing map.

## Demo walkthrough

1. Open the [BookIt production demo](https://bookit.1percent.rw).
2. Register or sign in as a passenger.
3. Search a route and travel date, then select a bus and seat.
4. Review the reservation and payment options. Use a provider-approved test flow for demonstrations unless live payment credentials are confirmed.
5. Open the driver or operator interface with the corresponding authorized account to review trip operations and ticket validation.

## Run locally

### Requirements
- Node.js **22.x**
- npm
- A supported database connection: local MySQL using the `DB_*` settings, or PostgreSQL through `DATABASE_URL`

### Setup

```bash
git clone https://github.com/AIME-LOIC/book_it.git
cd book_it
npm install
cp .env.example .env
```

Edit `.env` and configure:
- Database connection: `DATABASE_URL` or `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD`
- Strong, distinct values for `JWT_SECRET`, `QR_SECRET`, and `DEFAULT_PW_SECRET`
- `ALLOWED_ORIGINS` (for local development, include the local origin you use)
- `CRON_SECRET` for protected scheduled operations
- Flutterwave credentials only if you are testing payment initiation and webhooks

Run database migrations and start the server:

```bash
npm run db:migrate
npm start
```

The local server defaults to [http://localhost:2000](http://localhost:2000). Run the automated Node test suite with:

```bash
npm test
```

Do not commit `.env` files, production credentials, database dumps, or real customer data. Back up the database and test migrations against a staging database before applying them to production. Do not use `sequelize.sync({ alter: true })` in production.

## Supported locations

BookIt is designed for routes connecting Kigali, Musanze, Rubavu, Huye, Rusizi, Karongi, Nyagatare, Rwamagana, Kayonza, Muhanga, and Nyanza. Actual searchable routes depend on the locations, operators, schedules, and buses configured in the production database.

## Support

- **Email:** kingaime132@gmail.com
- **Phone:** +250 791 749 219
- **Location:** Kigali, Rwanda

---

© 2026 BookIt. Simplifying transport in Rwanda.
