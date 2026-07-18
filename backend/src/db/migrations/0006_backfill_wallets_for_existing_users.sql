-- 0006_backfill_wallets_for_existing_users.sql
-- Phase 4.1 — Creates a zero-balance wallet for every user who was registered
-- before the wallets table existed.  Safe to run repeatedly (ON CONFLICT DO NOTHING).

INSERT INTO wallets (user_id)
SELECT id FROM users
WHERE id NOT IN (SELECT user_id FROM wallets)
ON CONFLICT (user_id) DO NOTHING;
