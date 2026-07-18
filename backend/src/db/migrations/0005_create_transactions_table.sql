-- 0005_create_transactions_table.sql
-- Phase 4.1 — Immutable ledger of all wallet movements.
-- Rows are never updated or deleted (financial audit trail).

CREATE TABLE IF NOT EXISTS transactions (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type       VARCHAR(20) NOT NULL
               CHECK (type IN ('deposit', 'withdraw', 'reward', 'entry_fee', 'refund')),
  amount     NUMERIC(18,2) NOT NULL,
  status     VARCHAR(20) NOT NULL DEFAULT 'completed'
               CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
  reference  TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Optimise the most common query: all transactions for a user, newest first.
CREATE INDEX IF NOT EXISTS transactions_user_id_created_at_idx
  ON transactions (user_id, created_at DESC);
