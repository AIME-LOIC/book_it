-- BookIt RFID card ownership and short-lived reader pairing sessions.
CREATE TABLE IF NOT EXISTS rfid_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  card_uid VARCHAR(40) NOT NULL UNIQUE,
  status VARCHAR(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
  registered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_rfid_cards_user_status ON rfid_cards (user_id, status);

CREATE TABLE IF NOT EXISTS rfid_registration_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id VARCHAR(100) NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(16) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed', 'expired', 'cancelled')),
  card_uid VARCHAR(40),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_rfid_sessions_device_pending ON rfid_registration_sessions (device_id, status, expires_at);
CREATE INDEX IF NOT EXISTS idx_rfid_sessions_user_created ON rfid_registration_sessions (user_id, created_at DESC);
