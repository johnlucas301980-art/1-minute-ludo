#!/usr/bin/env bash
# =============================================================================
# Phase 9.3 — Help & Support Backend Test Suite
# Tests: FAQ endpoint, ticket creation, ticket list, ticket detail,
#        input validation, authentication guards, and user isolation.
# =============================================================================

set -u

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0
TS=$(date +%s)
EMAIL_A="support_a${TS}@example.com"
EMAIL_B="support_b${TS}@example.com"
PASSWORD="SupportPass123"

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
echo " Phase 9.3 — Help & Support Backend Tests"
echo "═══════════════════════════════════════════════════"
echo ""

echo "▶ Setup: Register & Login two users"
REG_A=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Support Alpha\",\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")
REG_B=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Support Beta\",\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")
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

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 1: Authentication guards"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/support/faqs")
assert_eq "GET /support/faqs without token → 401" "401" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/support/tickets")
assert_eq "GET /support/tickets without token → 401" "401" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/support/tickets" \
  -H "Content-Type: application/json" \
  -d '{"subject":"test","message":"test message here"}')
assert_eq "POST /support/tickets without token → 401" "401" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "$BASE/support/tickets/00000000-0000-4000-8000-000000000000")
assert_eq "GET /support/tickets/:id without token → 401" "401" "$STATUS"

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 2: FAQ endpoint"
BODY=$(curl -s "$BASE/support/faqs" -H "Authorization: Bearer $TOKEN_A")
assert_contains "GET /support/faqs returns success" '"success":true' "$BODY"
assert_contains "FAQ response contains faqs array" '"faqs":[' "$BODY"
assert_contains "FAQ items have id field" '"id":' "$BODY"
assert_contains "FAQ items have question field" '"question":' "$BODY"
assert_contains "FAQ items have answer field" '"answer":' "$BODY"
assert_contains "FAQ items have category field" '"category":' "$BODY"

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 3: Ticket creation — validation"
# Missing subject
BODY=$(curl -s -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"message":"This is my problem description which is long enough."}')
STATUS=$(echo "$BODY" | grep -o '"success":[^,}]*' | head -1 | cut -d: -f2)
assert_eq "POST ticket without subject → 400" "false" "$STATUS"

# Subject too short (< 3 chars)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"subject":"ab","message":"This is my problem description which is long enough."}')
assert_eq "POST ticket with subject < 3 chars → 400" "400" "$STATUS"

# Missing message
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"subject":"Valid Subject"}')
assert_eq "POST ticket without message → 400" "400" "$STATUS"

# Message too short (< 10 chars)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"subject":"Valid Subject","message":"short"}')
assert_eq "POST ticket with message < 10 chars → 400" "400" "$STATUS"

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 4: Ticket creation — happy path"
BODY=$(curl -s -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"subject":"I cannot withdraw","message":"Every time I try to withdraw my points I get an error. Please help me resolve this issue."}')
assert_contains "Create ticket returns success" '"success":true' "$BODY"
assert_contains "Created ticket has id" '"id":' "$BODY"
assert_contains "Created ticket has subject" '"subject":"I cannot withdraw"' "$BODY"
assert_contains "Created ticket has status open" '"status":"open"' "$BODY"
assert_contains "Created ticket has created_at" '"created_at":' "$BODY"
assert_contains "Created ticket has updated_at" '"updated_at":' "$BODY"

TICKET_A_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$TICKET_A_ID" ]; then
  echo "  ❌ FATAL: Could not extract ticket A ID."
  exit 1
fi

# Create a second ticket for user A
curl -s -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"subject":"Matchmaking issue","message":"I have been waiting in the matchmaking queue for a very long time and cannot find an opponent."}' \
  > /dev/null

# Create a ticket for user B
BODY_B=$(curl -s -X POST "$BASE/support/tickets" \
  -H "Authorization: Bearer $TOKEN_B" \
  -H "Content-Type: application/json" \
  -d '{"subject":"Profile update not working","message":"I am unable to update my profile avatar. The upload always fails with a generic error message."}')
TICKET_B_ID=$(echo "$BODY_B" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 5: Ticket list"
BODY=$(curl -s "$BASE/support/tickets" -H "Authorization: Bearer $TOKEN_A")
assert_contains "GET /support/tickets returns success" '"success":true' "$BODY"
assert_contains "Ticket list contains tickets array" '"tickets":[' "$BODY"
assert_contains "Ticket list contains pagination" '"pagination":{' "$BODY"
assert_contains "Ticket list contains total" '"total":' "$BODY"
assert_contains "Ticket list contains limit" '"limit":' "$BODY"
assert_contains "Ticket list contains offset" '"offset":' "$BODY"

# User A should see 2 tickets
TICKET_COUNT=$(echo "$BODY" | grep -o '"id":"' | wc -l | tr -d ' ')
assert_eq "User A sees 2 tickets" "2" "$TICKET_COUNT"

# Pagination: limit=1
BODY=$(curl -s "$BASE/support/tickets?limit=1" -H "Authorization: Bearer $TOKEN_A")
assert_contains "limit=1 returns 1 ticket" '"limit":1' "$BODY"
TICKET_COUNT=$(echo "$BODY" | grep -o '"subject":' | wc -l | tr -d ' ')
assert_eq "limit=1 returns exactly 1 subject" "1" "$TICKET_COUNT"

# Invalid limit
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/support/tickets?limit=0" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "limit=0 → 400" "400" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/support/tickets?limit=101" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "limit=101 → 400" "400" "$STATUS"

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 6: Ticket detail"
BODY=$(curl -s "$BASE/support/tickets/$TICKET_A_ID" -H "Authorization: Bearer $TOKEN_A")
assert_contains "GET /support/tickets/:id returns success" '"success":true' "$BODY"
assert_contains "Ticket detail has correct subject" '"subject":"I cannot withdraw"' "$BODY"
assert_contains "Ticket detail has status" '"status":"open"' "$BODY"

# Invalid UUID
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/support/tickets/not-a-uuid" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "Invalid UUID → 400" "400" "$STATUS"

# Non-existent ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "$BASE/support/tickets/00000000-0000-4000-8000-000000000000" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "Non-existent ticket → 404" "404" "$STATUS"

# ---------------------------------------------------------------------------
echo ""
echo "▶ Section 7: User isolation"
# User A cannot see User B's ticket
BODY=$(curl -s "$BASE/support/tickets/$TICKET_B_ID" -H "Authorization: Bearer $TOKEN_A")
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$BASE/support/tickets/$TICKET_B_ID" -H "Authorization: Bearer $TOKEN_A")
assert_eq "User A cannot view User B ticket → 404" "404" "$STATUS_CODE"

# User B's list should contain only User B's ticket
BODY=$(curl -s "$BASE/support/tickets" -H "Authorization: Bearer $TOKEN_B")
TICKET_COUNT=$(echo "$BODY" | grep -o '"id":"' | wc -l | tr -d ' ')
assert_eq "User B sees 1 ticket" "1" "$TICKET_COUNT"
assert_not_contains "User B list does not contain User A ticket" \
  '"I cannot withdraw"' "$BODY"

# ---------------------------------------------------------------------------
echo ""
echo "───────────────────────────────────────────────────"
echo " Results: $PASS passed, $FAIL failed"
echo "───────────────────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
