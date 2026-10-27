-- BookIt: persist boarding-terminal coordinates on locations.
-- Run against PostgreSQL before deploying the backend that reads these fields.
BEGIN;

ALTER TABLE public.locations
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

-- Known terminal pins. Kigali uses the approximate Nyabugogo Taxi Park pin;
-- verify the exact gate/pickup point with the operator before relying on it.
UPDATE public.locations
SET latitude = -1.94091000, longitude = 30.04475000
WHERE lower(name) = 'kigali';

UPDATE public.locations
SET latitude = -1.90098000, longitude = 30.50820000
WHERE lower(name) = 'kayonza';

UPDATE public.locations
SET latitude = -2.08314000, longitude = 29.75163000
WHERE lower(name) = 'muhanga';

UPDATE public.locations
SET latitude = -2.59061000, longitude = 29.74352000
WHERE lower(name) = 'huye';

COMMIT;
