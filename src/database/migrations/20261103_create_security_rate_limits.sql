-- Shared atomic rate-limit counters for serverless deployments.
CREATE TABLE IF NOT EXISTS security_rate_limits (
  rate_key VARCHAR(255) PRIMARY KEY,
  hit_count INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_security_rate_limits_expires_at ON security_rate_limits (expires_at);
