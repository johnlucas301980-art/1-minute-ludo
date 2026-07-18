#!/usr/bin/env bash
# =============================================================================
# Phase 5.1 — Matchmaking Backend Foundation — REST Test Suite
# Tests: GET /api/match/queue/status
# Socket.IO tests are in phase51_matchmaking_socket.mjs
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

TS=$(date +%s)
EMAIL="matchrest${TS}@example.com"
PASSWORD="MatchPass123"

# ── Helpers ──────────────────────────────────────────────────────────────────

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

# ── Setup: Register & Login ───────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "  PHASE 5.1 — REST: Queue Status"
echo "═══════════════════════════════════════════════════"

echo ""
echo "── Setup: register and login ────────────────────────"

REGISTER_BODY=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Match Tester\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

echo "  Register response: $REGISTER_BODY"

LOGIN_BODY=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

TOKEN=$(echo "$LOGIN_BODY" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"//')

if [ -z "$TOKEN" ]; then
  echo "  ❌ FATAL: could not obtain access token. Aborting."
  echo "$LOGIN_BODY"
  exit 1
fi
echo "  ✅ Access token obtained."

# ── 1. Unauthenticated access → 401 ─────────────────────────────────────────

echo ""
echo "── 1. Auth protection ───────────────────────────────"

STATUS_NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/queue/status")
assert_eq "GET /match/queue/status without token → 401" "401" "$STATUS_NO_AUTH"

STATUS_BAD_TOKEN=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/queue/status" \
  -H "Authorization: Bearer badtoken")
assert_eq "GET /match/queue/status with bad token → 401" "401" "$STATUS_BAD_TOKEN"

# ── 2. Valid token — player not in queue ─────────────────────────────────────

echo ""
echo "── 2. Queue status (not in queue) ───────────────────"

BODY=$(curl -s "$BASE/match/queue/status" \
  -H "Authorization: Bearer $TOKEN")

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/queue/status" \
  -H "Authorization: Bearer $TOKEN")

assert_eq "GET /match/queue/status → 200" "200" "$HTTP_CODE"
assert_contains "response has success:true"  '"success":true' "$BODY"
assert_contains "response has inQueue field" '"inQueue":'     "$BODY"
assert_contains "response has queueSize"     '"queueSize":'   "$BODY"
assert_contains "response has joinedAt"      '"joinedAt":'    "$BODY"
assert_contains "inQueue is false"           '"inQueue":false' "$BODY"
assert_contains "joinedAt is null"           '"joinedAt":null' "$BODY"

# ── 3. Response structure ─────────────────────────────────────────────────────

echo ""
echo "── 3. Response structure ────────────────────────────"

# queueSize should be a number (integer)
QUEUE_SIZE=$(echo "$BODY" | grep -o '"queueSize":[0-9]*' | sed 's/"queueSize"://')
assert_eq "queueSize is a number" "true" "$([ -n "$QUEUE_SIZE" ] && echo true || echo false)"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "  REST Results: PASS=$PASS  FAIL=$FAIL"
echo "═══════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
