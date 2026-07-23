-- Migration 0010: align match status constraint with the game lifecycle.
--
-- The backend and clients use `in_progress` for a started match. Migration
-- 0007 accidentally allowed `active` instead, which prevented game_start from
-- persisting the match transition.

ALTER TABLE matches
  DROP CONSTRAINT IF EXISTS matches_status_check;

UPDATE matches
   SET status = 'in_progress'
 WHERE status = 'active';

ALTER TABLE matches
  ADD CONSTRAINT matches_status_check
  CHECK (status IN ('waiting', 'in_progress', 'finished', 'cancelled'));