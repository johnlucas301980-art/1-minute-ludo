#!/usr/bin/env bash
# =============================================================================
# Phase 8.4 — Leaderboard Backend Test Suite
# Tests: GET /api/leaderboard
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique timestamp so test users don't collide with prior runs
TS=$(date +%s)
EMAIL_A="ldr_a${TS}@example.com"
EMAIL_B="ldr_b${TS}@example.com"
PASSWORD="LdrPass123"

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

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ❌ FAIL: $label"
    echo "       must NOT contain: $needle"
    echo "       actual body     : $haystack"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ PASS: $label"
    PASS=$((PASS + 1))
  fi
}

# ── Setup: Register & Login two players ──────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo " Phase 8.4 — Leaderboard Backend Tests"
echo "═══════════════════════════════════════════════════"
echo ""
echo "▶ Setup: Register & Login"

REG_A=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Ldr Alpha\",\"email\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")
assert_contains "Register player A" '"success":true' "$REG_A"

REG_B=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Ldr Beta\",\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD\"}")
assert_contains "Register player B" '"success":true' "$REG_B"

LOGIN_A=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL_A\",\"password\":\"$PASSWORD\"}")
assert_contains "Login player A" '"success":true' "$LOGIN_A"

TOKEN_A=$(echo "$LOGIN_A" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN_A" ]; then
  echo ""
  echo "  ❌ FATAL: Could not obtain access token — aborting tests."
  exit 1
fi

echo "  Access token obtained ✓"
echo ""

# ── Section 1: Auth Protection ────────────────────────────────────────────────

echo "▶ Section 1: Auth Protection"

# Test 1 — no token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/leaderboard")
assert_eq "1 — GET /leaderboard no token → 401" "401" "$STATUS"

# Test 2 — invalid token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/leaderboard" \
  -H "Authorization: Bearer invalid.token.here")
assert_eq "2 — GET /leaderboard invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 2: Successful Response ───────────────────────────────────────────

echo "▶ Section 2: Successful Response"

BODY=$(curl -s "$BASE/leaderboard" \
  -H "Authorization: Bearer $TOKEN_A")

# Test 3 — 200 OK
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/leaderboard" \
  -H "Authorization: Bearer $TOKEN_A")
assert_eq "3 — GET /leaderboard 200 OK" "200" "$STATUS"

# Test 4 — success:true
assert_contains "4 — response has success:true" '"success":true' "$BODY"

# Test 5 — has data envelope
assert_contains "5 — response has data envelope" '"data"' "$BODY"

# Test 6 — has leaderboard array
assert_contains "6 — response has leaderboard key" '"leaderboard"' "$BODY"

echo ""

# ── Section 3: Response Shape ─────────────────────────────────────────────────

echo "▶ Section 3: Entry Shape"

# Test 7 — rank field present
assert_contains "7 — entry has rank field" '"rank"' "$BODY"

# Test 8 — player_id field present
assert_contains "8 — entry has player_id field" '"player_id"' "$BODY"

# Test 9 — full_name field present
assert_contains "9 — entry has full_name field" '"full_name"' "$BODY"

# Test 10 — avatar field present (value may be null)
assert_contains "10 — entry has avatar field" '"avatar"' "$BODY"

# Test 11 — wins field present
assert_contains "11 — entry has wins field" '"wins"' "$BODY"

echo ""

# ── Section 4: No Forbidden Fields ───────────────────────────────────────────

echo "▶ Section 4: No Forbidden Fields"

# Test 12 — no email exposed
assert_not_contains "12 — email not in response" '"email"' "$BODY"

# Test 13 — no password_hash exposed
assert_not_contains "13 — password_hash not in response" '"password_hash"' "$BODY"

# Test 14 — no pagination wrapper (leaderboard is not paginated)
assert_not_contains "14 — no pagination envelope" '"pagination"' "$BODY"

echo ""

# ── Section 5: Rank 1 is present when players exist ──────────────────────────

echo "▶ Section 5: Rank Ordering"

# Test 15 — rank 1 is present (we registered at least one user)
assert_contains "15 — rank 1 entry exists" '"rank":1' "$BODY"

# Test 16 — registered players appear in leaderboard
assert_contains "16 — player A name in leaderboard" 'Ldr Alpha' "$BODY"
assert_contains "17 — player B name in leaderboard" 'Ldr Beta' "$BODY"

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────

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

exit $FAIL
