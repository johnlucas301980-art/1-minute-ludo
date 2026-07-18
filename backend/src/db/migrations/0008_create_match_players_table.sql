-- Migration 0008: match_players table
-- Links players to matches and stores per-player outcome data.
-- Phase 5.1 — Matchmaking Backend Foundation.

CREATE TABLE IF NOT EXISTS match_players (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id      UUID        NOT NULL REFERENCES matches(id)  ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  color         VARCHAR(10) NOT NULL
                            CHECK (color IN ('red', 'blue', 'green', 'yellow')),
  final_rank    INTEGER,
  earned_points NUMERIC(18,2) NOT NULL DEFAULT 0,
  joined_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (match_id, user_id),
  UNIQUE (match_id, color)
);

CREATE INDEX IF NOT EXISTS idx_match_players_match ON match_players (match_id);
CREATE INDEX IF NOT EXISTS idx_match_players_user  ON match_players (user_id);
