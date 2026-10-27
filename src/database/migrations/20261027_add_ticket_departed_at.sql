-- Track passenger departure separately from ticket validation/redemption.
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS departed_at TIMESTAMPTZ NULL;
