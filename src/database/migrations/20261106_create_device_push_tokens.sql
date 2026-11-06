CREATE TABLE IF NOT EXISTS device_push_tokens (
  id UUID PRIMARY KEY,
  recipient_id UUID NOT NULL,
  recipient_type VARCHAR(20) NOT NULL,
  token TEXT NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  platform VARCHAR(10) NOT NULL CHECK (platform IN ('android', 'ios')),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS device_push_tokens_recipient_idx
  ON device_push_tokens (recipient_id, recipient_type);
