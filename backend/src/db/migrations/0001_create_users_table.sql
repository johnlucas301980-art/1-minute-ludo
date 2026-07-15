-- 0001_create_users_table.sql
-- Phase 2.1 — Database foundation for player accounts.
-- Creates the `users` table, its indexes/constraints, and the supporting
-- triggers for automatic Player ID generation and `updated_at` maintenance.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id       VARCHAR(10) NOT NULL UNIQUE
                    CHECK (player_id ~ '^LUD-[A-Z0-9]{6}$'),
  full_name       VARCHAR(120) NOT NULL,
  email           VARCHAR(255),
  mobile          VARCHAR(20),
  password_hash   TEXT,
  google_id       VARCHAR(255),
  country         VARCHAR(100),
  avatar          TEXT,
  is_verified     BOOLEAN NOT NULL DEFAULT false,
  status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'banned')),
  last_login_at   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT users_identity_present_chk
    CHECK (email IS NOT NULL OR mobile IS NOT NULL OR google_id IS NOT NULL)
);

-- Unique indexes (partial, so multiple NULLs are allowed for optional identity fields)
CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_idx
  ON users (lower(email)) WHERE email IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_mobile_unique_idx
  ON users (mobile) WHERE mobile IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_google_id_unique_idx
  ON users (google_id) WHERE google_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS users_status_idx ON users (status);
CREATE INDEX IF NOT EXISTS users_created_at_idx ON users (created_at);

-- ---------------------------------------------------------------------------
-- Auto-generate a public Player ID (format LUD-XXXXXX) when one isn't supplied.
-- Retries on the rare collision since uniqueness is enforced by the table.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_player_id()
RETURNS TRIGGER AS $$
DECLARE
  candidate VARCHAR(10);
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  attempt INT := 0;
BEGIN
  IF NEW.player_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  LOOP
    candidate := 'LUD-';
    FOR i IN 1..6 LOOP
      candidate := candidate || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;

    EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE player_id = candidate);

    attempt := attempt + 1;
    IF attempt > 20 THEN
      RAISE EXCEPTION 'Unable to generate a unique player_id after % attempts', attempt;
    END IF;
  END LOOP;

  NEW.player_id := candidate;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_generate_player_id ON users;
CREATE TRIGGER users_generate_player_id
  BEFORE INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION generate_player_id();

-- ---------------------------------------------------------------------------
-- Automatically maintain `updated_at` on every row update.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_set_updated_at ON users;
CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
