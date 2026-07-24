-- Migration 0016: admin-managed application settings.
-- Phase 10.4 — Settings.

CREATE TABLE IF NOT EXISTS settings (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  key        VARCHAR(100) NOT NULL UNIQUE,
  value      TEXT         NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settings_key ON settings (key);
