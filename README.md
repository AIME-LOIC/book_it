# 🚌 BookIt - Travel Rwanda, Book Seamlessly

BookIt is Rwanda's premier digital platform designed to modernize bus travel. We eliminate the need for long queues at stations by providing a seamless, secure, and instant booking experience for passengers, bus operators, and drivers.

## ✨ Key Features

### For Passengers
*   **Search & Compare:** Find buses across major Rwandan cities including Kigali, Musanze, Rubavu, and more.
*   **Digital Reservations:** Select your preferred seat and book instantly from your phone or computer.
*   **Secure Payments:** Integrated MRT Wallet and local digital payment support.
*   **QR E-Tickets:** No more paper! Receive a digital ticket with a unique QR code for easy boarding.
*   **Travel Reminders:** Get notifications about your upcoming trips and boarding status.

### For Bus Operators
*   **Fleet Management:** Manage your buses, routes, and schedules in one dashboard.
*   **Revenue Tracking:** Monitor ticket sales and passenger manifests in real-time.
*   **Automated Routes:** Easily generate reverse routes and manage intermediate stops.

### For Drivers
*   **Passenger Manifests:** View a digital list of all paid passengers for your specific trip.
*   **QR Validation:** Use the built-in scanner to verify tickets instantly and prevent fraud.

---

## 📍 Supported Locations
We currently serve major routes connecting:
*   Kigali
*   Musanze
*   Rubavu
*   Huye
*   Rusizi
*   Karongi
*   Nyagatare
*   Rwamagana
*   Kayonza
*   Muhanga
*   Nyanza

---

## ⚠️ Important Note: GPS Tracking
**Please Note:** The real-time GPS bus tracking feature (Live Map) is currently undergoing maintenance and is **not working**. While you can see the bus's last known terminal location, live movement updates on the map are currently unavailable. We apologize for any inconvenience.

---

## 📖 How to Use BookIt

1.  **Search:** Go to the [Booking Page](/book), enter your departure city, destination, and travel date.
2.  **Select:** Choose a bus that fits your schedule and select an available seat.
3.  **Book & Pay:** Confirm your details and pay via the digital wallet.
4.  **Board:** On the day of travel, show your QR code to the driver. The driver will scan it, and you are ready to go!

---

## 📞 Support & Contact

If you have any questions or need assistance with your booking:
*   **Email:** kingaime132@gmail.com
*   **Phone:** +250 791749219
*   **Location:** Kigali, Rwanda

---
*© 2025 BookIt. Simplifing transport in Rwanda.*


## 🔧 Migrations & Supabase (Safe Deployment)

When deploying to Supabase (managed Postgres) do NOT rely on `sequelize.sync({ alter: true })` in production — altering enums or complex types automatically can fail or cause data issues. Use explicit SQL migrations or a migration tool and follow these steps:

- Backup first: use Supabase backups or `pg_dump` before applying schema changes.
- Test on a staging database that mirrors production.
- Apply schema changes inside a transaction when possible.
- Avoid automatic enum casts; create enum types explicitly then alter columns with `USING` casts.
- Disable automatic seeding on production: set `SEED_ON_START=false` in your production env.

Example SQL migration (add driver/bus location columns and bus amenities):

```sql
BEGIN;
ALTER TABLE drivers  ADD COLUMN IF NOT EXISTS last_lat DECIMAL(10,8);
ALTER TABLE drivers  ADD COLUMN IF NOT EXISTS last_lng DECIMAL(11,8);
ALTER TABLE buses    ADD COLUMN IF NOT EXISTS last_lat DECIMAL(10,8);
ALTER TABLE buses    ADD COLUMN IF NOT EXISTS last_lng DECIMAL(11,8);
ALTER TABLE buses    ADD COLUMN IF NOT EXISTS amenities JSONB DEFAULT '[]';
COMMIT;
```

Run the SQL migration with `psql` using your `DATABASE_URL`:

```bash
PGPASSWORD="$DB_PASSWORD" psql "$DATABASE_URL" <<'SQL'
BEGIN;
# paste SQL above or reference a .sql file
COMMIT;
SQL
```

Or use `sequelize-cli` / `umzug` migrations (recommended):

1. Install as dev dep: `npm install -D sequelize-cli`
2. Generate a migration and add the SQL/JS `up` and `down` logic.
3. Run migrations against production carefully: `NODE_ENV=production npx sequelize-cli db:migrate --url "$DATABASE_URL"`

Checklist before production migration
- Backup DB
- Run on staging
- Review enum/JSON/UUID conversions
- Disable seeding
- Monitor logs and have rollback SQL ready

If you want, I can scaffold a `migrations/` folder and add a safe migration file for the `last_lat/last_lng/amenities` changes and a brief `migrate:prod` command that runs SQL against `DATABASE_URL`.