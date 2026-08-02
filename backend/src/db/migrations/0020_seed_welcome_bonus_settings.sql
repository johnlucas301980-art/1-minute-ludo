-- 0020_seed_welcome_bonus_settings.sql
-- Seeds the two Welcome Bonus admin settings.
-- welcome_bonus_enabled: 'true' | 'false'
-- welcome_bonus_amount:  numeric points to credit (default 100)

INSERT INTO settings (key, value)
VALUES
  ('welcome_bonus_enabled', 'false'),
  ('welcome_bonus_amount',  '100')
ON CONFLICT (key) DO NOTHING;
