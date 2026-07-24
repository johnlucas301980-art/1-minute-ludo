-- Migration 0014: admin_audit_log table
-- Phase 10.2 — Admin Player Management.
--
-- Records every privileged admin action taken against a user or ticket
-- so that changes are traceable and reversible.

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id        UUID         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  target_user_id  UUID         REFERENCES users(id) ON DELETE SET NULL,
  action          VARCHAR(50)  NOT NULL
                               CHECK (action IN (
                                 'ban', 'unban', 'promote', 'demote',
                                 'status_change', 'role_change', 'ticket_status_change'
                               )),
  old_value       VARCHAR(100),
  new_value       VARCHAR(100),
  details         JSONB,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_admin
  ON admin_audit_log (admin_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_target
  ON admin_audit_log (target_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_action
  ON admin_audit_log (action, created_at DESC);
