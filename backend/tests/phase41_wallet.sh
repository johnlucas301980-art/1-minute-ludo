#!/usr/bin/env bash
# =============================================================================
# Phase 4.1 — Wallet Backend Foundation Test Suite
# Tests: GET /api/wallet, GET /api/wallet/history
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique email so the test user doesn't collide with prior runs
TS=$(date +%s)
EMAIL="wallet${TS}@example.com"
PASSWORD="WalletPass123"

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

# ── Setup: Register & Login ───────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo " Phase 4.1 — Wallet Backend Foundation Tests"
echo "═══════════════════════════════════════════════════"
echo ""
echo "▶ Setup: Register & Login"

REG=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Wallet Player\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
assert_contains "Register succeeds" '"success":true' "$REG"

LOGIN=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
assert_contains "Login succeeds" '"success":true' "$LOGIN"

TOKEN=$(echo "$LOGIN" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo ""
  echo "  ❌ FATAL: Could not obtain access token — aborting tests."
  exit 1
fi

echo "  Access token obtained ✓"
echo ""

# ── Section 1: Auth Protection — GET /wallet ─────────────────────────────────

echo "▶ Section 1: Auth Protection — GET /wallet"

# Test 1 — no token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE/wallet")
assert_eq "1 — GET /wallet no token → 401" "401" "$STATUS"

# Test 2 — invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE/wallet" \
  -H "Authorization: Bearer invalid.token.here")
assert_eq "2 — GET /wallet invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 2: Auth Protection — GET /wallet/history ─────────────────────────

echo "▶ Section 2: Auth Protection — GET /wallet/history"

# Test 3 — no token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE/wallet/history")
assert_eq "3 — GET /wallet/history no token → 401" "401" "$STATUS"

# Test 4 — invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE/wallet/history" \
  -H "Authorization: Bearer invalid.token.here")
assert_eq "4 — GET /wallet/history invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 3: GET /wallet — Initial State ────────────────────────────────────

echo "▶ Section 3: GET /wallet — Initial State"

WALLET_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/wallet" \
  -H "Authorization: Bearer $TOKEN")
BODY=$(echo "$WALLET_RESPONSE" | head -n -1)
STATUS=$(echo "$WALLET_RESPONSE" | tail -n 1)

# Test 5 — 200 OK
assert_eq "5 — GET /wallet → 200" "200" "$STATUS"

# Test 6 — success: true
assert_contains "6 — response has success:true" '"success":true' "$BODY"

# Test 7 — response contains wallet object
assert_contains "7 — response contains wallet key" '"wallet"' "$BODY"

# Test 8 — wallet has id field
assert_contains "8 — wallet has id" '"id"' "$BODY"

# Test 9 — wallet has points field
assert_contains "9 — wallet has points" '"points"' "$BODY"

# Test 10 — new wallet starts at 0 points
assert_contains "10 — initial points is 0" '"points":0' "$BODY"

# Test 11 — wallet has total_deposit field
assert_contains "11 — wallet has total_deposit" '"total_deposit"' "$BODY"

# Test 12 — wallet has total_withdraw field
assert_contains "12 — wallet has total_withdraw" '"total_withdraw"' "$BODY"

# Test 13 — wallet has updated_at field
assert_contains "13 — wallet has updated_at" '"updated_at"' "$BODY"

# Test 14 — response does not expose user_id (internal field)
assert_not_contains "14 — response does not expose user_id" '"user_id"' "$BODY"

echo ""

# ── Section 4: GET /wallet — Idempotent (second call) ────────────────────────

echo "▶ Section 4: GET /wallet — Idempotent"

WALLET_2=$(curl -s -X GET "$BASE/wallet" \
  -H "Authorization: Bearer $TOKEN")

# Test 15 — second call also succeeds
assert_contains "15 — second GET /wallet → success:true" '"success":true' "$WALLET_2"

# Test 16 — same id returned on second call (wallet not duplicated)
ID_1=$(echo "$BODY"  | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
ID_2=$(echo "$WALLET_2" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
assert_eq "16 — same wallet id returned on second call" "$ID_1" "$ID_2"

echo ""

# ── Section 5: GET /wallet/history — Empty History ───────────────────────────

echo "▶ Section 5: GET /wallet/history — Empty History"

HISTORY_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/wallet/history" \
  -H "Authorization: Bearer $TOKEN")
BODY=$(echo "$HISTORY_RESPONSE" | head -n -1)
STATUS=$(echo "$HISTORY_RESPONSE" | tail -n 1)

# Test 17 — 200 OK
assert_eq "17 — GET /wallet/history → 200" "200" "$STATUS"

# Test 18 — success: true
assert_contains "18 — response has success:true" '"success":true' "$BODY"

# Test 19 — response contains transactions array
assert_contains "19 — response contains transactions key" '"transactions"' "$BODY"

# Test 20 — empty array for new user (count:0 confirms empty without regex metacharacter issues)
assert_contains "20 — transactions is empty array" '"count":0' "$BODY"

# Test 21 — response contains pagination object
assert_contains "21 — response contains pagination key" '"pagination"' "$BODY"

# Test 22 — pagination has limit
assert_contains "22 — pagination has limit" '"limit"' "$BODY"

# Test 23 — pagination has offset
assert_contains "23 — pagination has offset" '"offset"' "$BODY"

# Test 24 — pagination has count
assert_contains "24 — pagination has count" '"count"' "$BODY"

echo ""

# ── Section 6: GET /wallet/history — Pagination Params ───────────────────────

echo "▶ Section 6: GET /wallet/history — Pagination"

# Test 25 — custom limit is respected
BODY=$(curl -s -X GET "$BASE/wallet/history?limit=5&offset=0" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "25 — custom limit=5 accepted" '"limit":5' "$BODY"

# Test 26 — custom offset is respected
BODY=$(curl -s -X GET "$BASE/wallet/history?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "26 — offset=0 reflected in pagination" '"offset":0' "$BODY"

# Test 27 — limit clamped to 100 (max)
BODY=$(curl -s -X GET "$BASE/wallet/history?limit=999" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "27 — limit=999 clamped to 100" '"limit":100' "$BODY"

# Test 28 — non-numeric limit falls back to default (20)
BODY=$(curl -s -X GET "$BASE/wallet/history?limit=abc" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "28 — non-numeric limit falls back to 20" '"limit":20' "$BODY"

# Test 29 — negative offset falls back to default (0)
BODY=$(curl -s -X GET "$BASE/wallet/history?offset=-5" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "29 — negative offset falls back to 0" '"offset":0' "$BODY"

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
