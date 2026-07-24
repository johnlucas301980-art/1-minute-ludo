-- Migration 0013: add role column to users table
-- Phase 10.1 — Admin Foundation.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'player'
    CHECK (role IN ('player', 'admin'));

CREATE INDEX IF NOT EXISTS idx_users_role
  ON users (role);
