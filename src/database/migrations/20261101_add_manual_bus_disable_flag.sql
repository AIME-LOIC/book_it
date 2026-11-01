-- Keep operator-disabled buses inactive while reactivating buses after daily departure.
ALTER TABLE public.buses
  ADD COLUMN IF NOT EXISTS is_manually_disabled BOOLEAN NOT NULL DEFAULT FALSE;

-- Existing inactive buses may have been disabled by an operator. Preserve
-- their current state rather than unexpectedly exposing them after deployment.
UPDATE public.buses
SET is_manually_disabled = TRUE
WHERE is_active = FALSE AND is_manually_disabled = FALSE;
