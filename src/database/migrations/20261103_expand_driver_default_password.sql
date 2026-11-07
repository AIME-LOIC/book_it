-- AES-GCM hex encoding of 128-bit initial driver passwords is longer than the old 100-char column.
ALTER TABLE drivers ALTER COLUMN default_password TYPE VARCHAR(255);
