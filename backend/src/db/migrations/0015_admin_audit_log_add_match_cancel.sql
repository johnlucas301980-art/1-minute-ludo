-- Migration 0015: extend admin_audit_log action constraint.
-- Phase 10.3 — Match Monitoring.
--
-- Adds 'match_cancel' to the allowed action values so admins can
-- forcibly cancel a match and have the action recorded in the audit log.

ALTER TABLE admin_audit_log
  DROP CONSTRAINT IF EXISTS admin_audit_log_action_check;

ALTER TABLE admin_audit_log
  ADD CONSTRAINT admin_audit_log_action_check
  CHECK (action IN (
    'ban', 'unban', 'promote', 'demote',
    'status_change', 'role_change', 'ticket_status_change',
    'match_cancel'
  ));
