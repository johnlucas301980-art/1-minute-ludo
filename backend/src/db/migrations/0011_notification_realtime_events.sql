-- Migration 0011: realtime notification change events
-- Phase 9.2 — Real-Time In-App Notifications.
--
-- PostgreSQL NOTIFY is emitted only after the surrounding transaction commits.
-- The notification delivery listener uses the IDs in this payload to fetch the
-- persisted row before publishing it over Socket.IO.

CREATE OR REPLACE FUNCTION notify_notification_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM pg_notify(
      'notification_changes',
      json_build_object(
        'action', CASE WHEN TG_OP = 'INSERT' THEN 'created' ELSE 'read_state_changed' END,
        'notification_id', NEW.id,
        'user_id', NEW.user_id
      )::text
    );
  ELSIF OLD.is_read IS DISTINCT FROM NEW.is_read THEN
    PERFORM pg_notify(
      'notification_changes',
      json_build_object(
        'action', 'read_state_changed',
        'notification_id', NEW.id,
        'user_id', NEW.user_id
      )::text
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_realtime_change_trigger ON notifications;

CREATE TRIGGER notifications_realtime_change_trigger
AFTER INSERT OR UPDATE OF is_read ON notifications
FOR EACH ROW
EXECUTE FUNCTION notify_notification_change();