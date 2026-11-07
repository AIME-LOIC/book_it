-- Add notification values introduced by the departure reminder and loyalty
-- promo scheduler jobs. Existing notification rows and enum values are kept.
ALTER TYPE public.notification_type
  ADD VALUE IF NOT EXISTS 'trip_departure_reminder';

ALTER TYPE public.notification_type
  ADD VALUE IF NOT EXISTS 'promo_code_generated';
