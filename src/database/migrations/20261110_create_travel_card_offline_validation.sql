ALTER TABLE rfid_cards ADD COLUMN IF NOT EXISTS card_token UUID;
UPDATE rfid_cards SET card_token=gen_random_uuid() WHERE card_token IS NULL;
ALTER TABLE rfid_cards ALTER COLUMN card_token SET DEFAULT gen_random_uuid();
ALTER TABLE rfid_cards ALTER COLUMN card_token SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_rfid_cards_card_token ON rfid_cards(card_token);
CREATE TABLE IF NOT EXISTS rfid_card_tickets (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 card_id UUID NOT NULL REFERENCES rfid_cards(id) ON DELETE CASCADE,
 ticket_id UUID NOT NULL UNIQUE REFERENCES tickets(id) ON DELETE CASCADE,
 travel_date DATE NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(card_id,travel_date)
);
CREATE TABLE IF NOT EXISTS offline_ticket_manifests (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
 bus_id UUID NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
 travel_date DATE NOT NULL,
 issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 expires_at TIMESTAMPTZ NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS offline_ticket_validations (
 event_id VARCHAR(100) PRIMARY KEY,
 manifest_id UUID NOT NULL REFERENCES offline_ticket_manifests(id) ON DELETE CASCADE,
 ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
 scan_method VARCHAR(8) NOT NULL CHECK(scan_method IN ('nfc','qr')),
 scanned_at TIMESTAMPTZ NOT NULL,
 status VARCHAR(16) NOT NULL CHECK(status IN ('accepted','rejected')),
 rejection_reason TEXT,
 synced_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
