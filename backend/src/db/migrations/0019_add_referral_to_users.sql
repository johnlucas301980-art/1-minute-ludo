-- 0019_add_referral_to_users.sql
-- Adds referral system columns to the users table:
--   referral_code  — unique 8-char code auto-generated for every user on INSERT
--   referred_by    — FK to the user whose referral_code was used at registration

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS referral_code VARCHAR(12) UNIQUE,
  ADD COLUMN IF NOT EXISTS referred_by   UUID REFERENCES users(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- Trigger: auto-generate an 8-char alphanumeric referral_code on INSERT.
-- Retries on the rare collision (uniqueness enforced by the column constraint).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER AS $$
DECLARE
  candidate VARCHAR(12);
  chars     TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  attempt   INT  := 0;
BEGIN
  IF NEW.referral_code IS NOT NULL THEN
    RETURN NEW;
  END IF;

  LOOP
    candidate := '';
    FOR i IN 1..8 LOOP
      candidate := candidate || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;

    EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE referral_code = candidate);

    attempt := attempt + 1;
    IF attempt > 20 THEN
      RAISE EXCEPTION 'Unable to generate a unique referral_code after % attempts', attempt;
    END IF;
  END LOOP;

  NEW.referral_code := candidate;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_generate_referral_code ON users;
CREATE TRIGGER users_generate_referral_code
  BEFORE INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION generate_referral_code();

-- ---------------------------------------------------------------------------
-- Backfill: assign referral_code to existing rows that have none.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r         RECORD;
  candidate VARCHAR(12);
  chars     TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  attempt   INT;
BEGIN
  FOR r IN SELECT id FROM users WHERE referral_code IS NULL LOOP
    attempt := 0;
    LOOP
      candidate := '';
      FOR i IN 1..8 LOOP
        candidate := candidate || substr(chars, floor(random() * length(chars) + 1)::int, 1);
      END LOOP;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE referral_code = candidate);
      attempt := attempt + 1;
      IF attempt > 20 THEN
        RAISE EXCEPTION 'Cannot generate referral_code for user %', r.id;
      END IF;
    END LOOP;
    UPDATE users SET referral_code = candidate WHERE id = r.id;
  END LOOP;
END;
$$;

-- Make referral_code NOT NULL now that all rows have a value.
ALTER TABLE users ALTER COLUMN referral_code SET NOT NULL;

CREATE INDEX IF NOT EXISTS users_referred_by_idx ON users (referred_by);
