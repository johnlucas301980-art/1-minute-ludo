-- Migration 0009: notifications table
-- Durable in-app notifications for authenticated users.
-- Phase 9.1 — In-App Notification Backend.

CREATE TABLE IF NOT EXISTS notifications (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type          VARCHAR(64)  NOT NULL,
  title         VARCHAR(255) NOT NULL,
  message       TEXT         NOT NULL,
  related_type  VARCHAR(64),
  related_id    UUID,
  event_key     VARCHAR(255),
  is_read       BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  read_at       TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_user_event
  ON notifications (user_id, event_key)
  WHERE event_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, is_read, created_at DESC);