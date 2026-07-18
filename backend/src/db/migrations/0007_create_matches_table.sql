-- Migration 0007: matches table
-- Stores each matchmaking session (random or friend room).
-- Phase 5.1 — Matchmaking Backend Foundation.

CREATE TABLE IF NOT EXISTS matches (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  room_code     VARCHAR(8)  NOT NULL UNIQUE,
  mode          VARCHAR(20) NOT NULL DEFAULT 'random'
                            CHECK (mode IN ('random', 'friend')),
  status        VARCHAR(20) NOT NULL DEFAULT 'waiting'
                            CHECK (status IN ('waiting', 'active', 'finished', 'cancelled')),
  entry_points  NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (entry_points >= 0),
  player_count  INTEGER     NOT NULL DEFAULT 2,
  winner_id     UUID        REFERENCES users(id) ON DELETE SET NULL,
  started_at    TIMESTAMPTZ,
  finished_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matches_status     ON matches (status);
CREATE INDEX IF NOT EXISTS idx_matches_room_code  ON matches (room_code);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON matches (created_at DESC);
