-- Migration: 0021 — Create login_history table
-- Records every successful login for audit / UX display.

CREATE TABLE login_history (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  login_time   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  device_name  TEXT,
  platform     TEXT,
  country      TEXT,
  login_method TEXT        NOT NULL,   -- 'email' | 'mobile' | 'google'
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX login_history_user_id_time_idx
  ON login_history (user_id, login_time DESC);
