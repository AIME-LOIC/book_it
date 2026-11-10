ALTER TABLE offline_ticket_validations DROP CONSTRAINT IF EXISTS offline_ticket_validations_scan_method_check;
ALTER TABLE offline_ticket_validations
  ADD CONSTRAINT offline_ticket_validations_scan_method_check
  CHECK (scan_method IN ('nfc', 'qr', 'ticket_number'));

ALTER TABLE offline_ticket_manifest_items ALTER COLUMN card_id DROP NOT NULL;
ALTER TABLE offline_ticket_manifest_items ALTER COLUMN card_uid DROP NOT NULL;
ALTER TABLE offline_ticket_manifest_items ALTER COLUMN card_token DROP NOT NULL;
