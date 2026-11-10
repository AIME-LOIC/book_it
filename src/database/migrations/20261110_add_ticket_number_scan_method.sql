ALTER TABLE offline_ticket_validations DROP CONSTRAINT IF EXISTS offline_ticket_validations_scan_method_check;
ALTER TABLE offline_ticket_validations
  ADD CONSTRAINT offline_ticket_validations_scan_method_check
  CHECK (scan_method IN ('nfc', 'qr', 'ticket_number'));
