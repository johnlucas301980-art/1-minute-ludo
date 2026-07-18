-- 0004_create_wallets_table.sql
-- Phase 4.1 — Wallet balance store for each player.
-- One wallet per user (enforced by UNIQUE on user_id).
-- Balance modification is handled exclusively by backend services —
-- never directly by client requests.

CREATE TABLE IF NOT EXISTS wallets (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  points         NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (points >= 0),
  total_deposit  NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (total_deposit >= 0),
  total_withdraw NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (total_withdraw >= 0),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS wallets_user_id_idx ON wallets (user_id);

-- ---------------------------------------------------------------------------
-- Auto-maintain updated_at on every row update.
-- Reuses set_updated_at() already defined by migration 0001.
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS wallets_set_updated_at ON wallets;
CREATE TRIGGER wallets_set_updated_at
  BEFORE UPDATE ON wallets
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
