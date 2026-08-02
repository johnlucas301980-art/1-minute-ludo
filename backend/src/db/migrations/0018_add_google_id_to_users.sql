-- 0018_add_google_id_to_users.sql
-- Adds Google OAuth support: store the Google account ID on the users table.
-- google_id is unique so one Google account maps to exactly one player.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;
