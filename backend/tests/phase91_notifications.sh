#!/usr/bin/env bash
# =============================================================================
# Phase 9.1 — In-App Notification Backend Test Suite
# Tests: notification persistence, REST API, read state, and user isolation.
# =============================================================================

set -u

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0
TS=$(date +%s)
EMAIL_A="notification_a${TS}@example.com"
EMAIL_B="notification_b${TS}@example.com"
PASSWORD="NotificationPass123"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $label"
    echo "       expected: $expected"
    echo "       actual  : $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $label"
    echo "       expected to contain: $needle"
    echo "       actual body        : $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ❌ FAIL: $label"
    echo "       must not contain: $needle"
    echo "       actual body: $haystack"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ PASS: $label"
    PASS=$((PASS + 1))
  fi
}

echo ""
echo "═══════════════════════════════════════════════════"
echo " Phase 9.1 — In-App Notification Backend Tests"
echo "═══════════════════════════════════════════════════"
echo ""

echo "▶ Setup: Register & Login two users"
REG_A=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Notification Alpha\",\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")
REG_B=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Notification Beta\",\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")
assert_contains "Register user A succeeds" '"success":true' "$REG_A"
assert_contains "Register user B succeeds" '"success":true' "$REG_B"

LOGIN_A=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")
LOGIN_B=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")
TOKEN_A=$(echo "$LOGIN_A" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
TOKEN_B=$(echo "$LOGIN_B" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
assert_contains "Login user A succeeds" '"success":true' "$LOGIN_A"
assert_contains "Login user B succeeds" '"success":true' "$LOGIN_B"

if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ]; then
  echo "  ❌ FATAL: Could not obtain both access tokens."
  exit 1
fi

echo ""
echo "▶ Section 1: Authentication"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/notifications")
assert_eq "GET /notifications without token → 401" "401" "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/notifications" \
  -H "Authorization: Bearer invalid.token")
assert_eq "GET /notifications invalid token → 401" "401" "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/notifications/read-all")
assert_eq "PUT /notifications/read-all without token → 401" "401" "$STATUS"

echo ""
echo "▶ Section 2: Empty list and pagination"
BODY=$(curl -s "$BASE/notifications" -H "Authorization: Bearer $TOKEN_A")
assert_contains "Empty list returns success" '"success":true' "$BODY"
if echo "$BODY" | fgrep -q '"notifications":[]'; then
  echo "  ✅ PASS: Empty list has notifications array"
  PASS=$((PASS + 1))
else
  echo "  ❌ FAIL: Empty list has notifications array"
  echo "       actual body: $BODY"
  FAIL=$((FAIL + 1))
fi
assert_contains "Default limit is 20" '"limit":20' "$BODY"
assert_contains "Default offset is 0" '"offset":0' "$BODY"
assert_contains "Unread count starts at 0" '"unread_count":0' "$BODY"

BODY=$(curl -s "$BASE/notifications?limit=5&offset=2" \
  -H "Authorization: Bearer $TOKEN_A")
assert_contains "Custom limit is reflected" '"limit":5' "$BODY"
assert_contains "Custom offset is reflected" '"offset":2' "$BODY"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/notifications?limit=0" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "limit=0 → 400" "400" "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/notifications?limit=101" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "limit=101 → 400" "400" "$STATUS"

echo ""
echo "▶ Section 3: Seed persisted notifications for API/read-state tests"
USER_A_ID=$(echo "$LOGIN_A" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
USER_B_ID=$(echo "$LOGIN_B" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$USER_A_ID" ] || [ -z "$USER_B_ID" ]; then
  echo "  ❌ FATAL: Could not obtain user IDs."
  exit 1
fi

NOTIFICATION_IDS=$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 <<SQL
INSERT INTO notifications
  (user_id, type, title, message, related_type, event_key)
VALUES
  ('$USER_A_ID', 'system', 'Welcome', 'First notification', 'system', 'phase91:${TS}:a1'),
  ('$USER_A_ID', 'system', 'Reminder', 'Second notification', NULL, 'phase91:${TS}:a2'),
  ('$USER_B_ID', 'system', 'Private', 'User B notification', NULL, 'phase91:${TS}:b1')
RETURNING id;
SQL
)

NOTIFICATION_A1=$(echo "$NOTIFICATION_IDS" | sed -n '1p')
NOTIFICATION_A2=$(echo "$NOTIFICATION_IDS" | sed -n '2p')
NOTIFICATION_B1=$(echo "$NOTIFICATION_IDS" | sed -n '3p')

assert_contains "Seeded user A notification id" "-" "$NOTIFICATION_A1"
assert_contains "Seeded user B notification id" "-" "$NOTIFICATION_B1"

echo ""
echo "▶ Section 4: Listing and user isolation"
BODY=$(curl -s "$BASE/notifications" -H "Authorization: Bearer $TOKEN_A")
assert_contains "User A sees notification list" '"notifications"' "$BODY"
assert_contains "User A sees unread count 2" '"unread_count":2' "$BODY"
assert_contains "User A sees first notification" 'First notification' "$BODY"
assert_not_contains "User A cannot see user B notification" 'User B notification' "$BODY"
assert_not_contains "Notification list does not expose user_id" '"user_id"' "$BODY"
assert_not_contains "Notification list does not expose event_key" '"event_key"' "$BODY"

BODY=$(curl -s "$BASE/notifications" -H "Authorization: Bearer $TOKEN_B")
assert_contains "User B sees own notification" 'User B notification' "$BODY"
assert_not_contains "User B cannot see user A notification" 'First notification' "$BODY"

echo ""
echo "▶ Section 5: Mark one notification read"
BODY=$(curl -s -X PUT "$BASE/notifications/$NOTIFICATION_A1/read" \
  -H "Authorization: Bearer $TOKEN_A")
assert_contains "Mark one returns success" '"success":true' "$BODY"
assert_contains "Marked notification is read" '"is_read":true' "$BODY"
assert_contains "Marked notification has read_at" '"read_at"' "$BODY"

BODY=$(curl -s "$BASE/notifications" -H "Authorization: Bearer $TOKEN_A")
assert_contains "Unread count decreases to 1" '"unread_count":1' "$BODY"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PUT "$BASE/notifications/$NOTIFICATION_B1/read" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "User A cannot mark user B notification → 404" "404" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PUT "$BASE/notifications/not-a-uuid/read" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "Invalid notification id → 400" "400" "$STATUS"

echo ""
echo "▶ Section 6: Mark all notifications read"
BODY=$(curl -s -X PUT "$BASE/notifications/read-all" \
  -H "Authorization: Bearer $TOKEN_A")
assert_contains "Mark all returns success" '"success":true' "$BODY"
assert_contains "Mark all reports two changed notifications" '"marked_count":1' "$BODY"
assert_contains "Mark all reports zero unread" '"unread_count":0' "$BODY"

BODY=$(curl -s "$BASE/notifications" -H "Authorization: Bearer $TOKEN_A")
assert_contains "All user A notifications are read" '"unread_count":0' "$BODY"

echo ""
echo "▶ Section 7: Idempotent event key"
DUPLICATE_COUNT=$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 <<SQL
INSERT INTO notifications
  (user_id, type, title, message, event_key)
VALUES
  ('$USER_A_ID', 'system', 'Duplicate', 'Should not duplicate', 'phase91:${TS}:a1')
ON CONFLICT (user_id, event_key) WHERE event_key IS NOT NULL
DO UPDATE SET id = notifications.id;
SELECT COUNT(*) FROM notifications
 WHERE user_id = '$USER_A_ID'
   AND event_key = 'phase91:${TS}:a1';
SQL
)
DUPLICATE_COUNT=$(echo "$DUPLICATE_COUNT" | tail -n 1)
assert_eq "Duplicate event key keeps one row" "1" "$DUPLICATE_COUNT"

echo ""
echo "═══════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo " Results: $PASS/$TOTAL passed"
if [ "$FAIL" -eq 0 ]; then
  echo " ✅ All tests passed."
else
  echo " ❌ $FAIL test(s) failed."
fi
echo "═══════════════════════════════════════════════════"
echo ""

exit "$FAIL"