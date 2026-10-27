-- Correct BookIt terminal coordinates using the Google Maps place pins supplied.
-- Safe to run after 20261027_add_location_coordinates.sql.
BEGIN;

UPDATE public.locations
SET latitude = -1.94186970, longitude = 30.04398040
WHERE lower(name) = 'kigali';

UPDATE public.locations
SET latitude = -1.90089820, longitude = 30.50772850
WHERE lower(name) = 'kayonza';

UPDATE public.locations
SET latitude = -2.08328670, longitude = 29.75142890
WHERE lower(name) = 'muhanga';

UPDATE public.locations
SET latitude = -2.59518090, longitude = 29.74233250
WHERE lower(name) = 'huye';

UPDATE public.locations
SET latitude = -1.95185450, longitude = 30.43327400
WHERE lower(name) = 'rwamagana';

COMMIT;
