-- 0003_create_password_reset_otps_table.sql
-- Phase 2 (Password Reset) — Stores one-time passcodes for password reset.
-- Only the SHA-256 hash of the OTP is persisted; the plaintext lives only in
-- the email sent to the user.

CREATE TABLE IF NOT EXISTS password_reset_otps (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  otp_hash    TEXT        NOT NULL,                    -- SHA-256 hex of the 6-digit OTP
  expires_at  TIMESTAMPTZ NOT NULL,                    -- 15 minutes from creation
  attempts    INT         NOT NULL DEFAULT 0,           -- failed verify attempts
  used_at     TIMESTAMPTZ,                             -- NULL = not yet used
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS password_reset_otps_user_id_idx
  ON password_reset_otps (user_id);

CREATE INDEX IF NOT EXISTS password_reset_otps_expires_at_idx
  ON password_reset_otps (expires_at);
