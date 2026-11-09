-- Create the tables used by the scheduled notification and loyalty-promo jobs.
-- These tables were represented by Sequelize models but were missing from the
-- production PostgreSQL migration history.

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL,
  recipient_type VARCHAR(20) NOT NULL,
  type VARCHAR(50) NOT NULL,
  message VARCHAR(255) NOT NULL,
  meta JSON NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS notifications_recipient_created_at_idx
  ON public.notifications (recipient_id, recipient_type, "createdAt" DESC);

CREATE INDEX IF NOT EXISTS notifications_type_created_at_idx
  ON public.notifications (type, "createdAt");

CREATE TABLE IF NOT EXISTS public.promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(40) NOT NULL UNIQUE,
  recipient_id UUID NOT NULL REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE,
  recipient_type VARCHAR(20) NOT NULL DEFAULT 'user',
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  generated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMPTZ NULL,
  used_at TIMESTAMPTZ NULL,
  ticket_id UUID NULL REFERENCES public.tickets(id) ON UPDATE CASCADE ON DELETE SET NULL,
  metadata JSON NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS promo_codes_recipient_generated_at_idx
  ON public.promo_codes (recipient_id, generated_at DESC);

CREATE INDEX IF NOT EXISTS promo_codes_status_expires_at_idx
  ON public.promo_codes (status, expires_at);
