#!/usr/bin/env bash
# =============================================================================
# Phase 8.1 — Match History Backend Test Suite
# Tests: GET /api/match/history
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique email so test users don't collide with prior runs
TS=$(date +%s)
EMAIL="history${TS}@example.com"
PASSWORD="HistoryPass123"

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
echo " Phase 8.1 — Match History Backend Tests"
echo "═══════════════════════════════════════════════════"
echo ""
echo "▶ Setup: Register & Login"

REG=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"History Player\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
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

# ── Section 1: Auth Protection ────────────────────────────────────────────────

echo "▶ Section 1: Auth Protection"

# Test 1 — no token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history")
assert_eq "1 — GET /match/history no token → 401" "401" "$STATUS"

# Test 2 — invalid token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history" \
  -H "Authorization: Bearer invalid.token.here")
assert_eq "2 — GET /match/history invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 2: Empty History ──────────────────────────────────────────────────

echo "▶ Section 2: Empty History (new player, no matches)"

BODY=$(curl -s "$BASE/match/history" \
  -H "Authorization: Bearer $TOKEN")

# Test 3 — 200 OK
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "3 — GET /match/history 200 OK" "200" "$STATUS"

# Test 4 — success:true
assert_contains "4 — response has success:true" '"success":true' "$BODY"

# Test 5 — matches is empty array (fgrep for literal brackets)
if echo "$BODY" | fgrep -q '"matches":[]'; then
  echo "  ✅ PASS: 5 — matches array is empty"
  PASS=$((PASS + 1))
else
  echo "  ❌ FAIL: 5 — matches array is empty"
  echo "       actual body: $BODY"
  FAIL=$((FAIL + 1))
fi

# Test 6 — total is 0
assert_contains "6 — pagination.total is 0" '"total":0' "$BODY"

# Test 7 — limit defaults to 20
assert_contains "7 — pagination.limit defaults to 20" '"limit":20' "$BODY"

# Test 8 — offset defaults to 0
assert_contains "8 — pagination.offset defaults to 0" '"offset":0' "$BODY"

echo ""

# ── Section 3: Pagination Params — valid values ───────────────────────────────

echo "▶ Section 3: Pagination Params — valid values"

# Test 9 — custom limit reflected
BODY=$(curl -s "$BASE/match/history?limit=5" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "9 — limit=5 reflected in response" '"limit":5' "$BODY"

# Test 10 — custom offset reflected
BODY=$(curl -s "$BASE/match/history?limit=10&offset=5" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "10 — offset=5 reflected in response" '"offset":5' "$BODY"

# Test 11 — limit=1 (minimum valid)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history?limit=1" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "11 — limit=1 (min valid) → 200" "200" "$STATUS"

# Test 12 — limit=100 (maximum valid)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history?limit=100" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "12 — limit=100 (max valid) → 200" "200" "$STATUS"

echo ""

# ── Section 4: Pagination Params — invalid values ────────────────────────────

echo "▶ Section 4: Pagination Params — invalid limit values"

# Test 13 — limit=0 → 400
BODY=$(curl -s "$BASE/match/history?limit=0" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history?limit=0" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "13 — limit=0 (<1) → 400" "400" "$STATUS"
assert_contains "13b — error message mentions limit" '"message"' "$BODY"

# Test 14 — limit=-1 → 400
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history?limit=-1" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "14 — limit=-1 (<1) → 400" "400" "$STATUS"

# Test 15 — limit=101 → 400
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history?limit=101" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "15 — limit=101 (>100) → 400" "400" "$STATUS"

# Test 16 — limit=999 → 400
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/match/history?limit=999" \
  -H "Authorization: Bearer $TOKEN")
assert_eq "16 — limit=999 (>100) → 400" "400" "$STATUS"

# Test 17 — non-numeric limit → 200 with default limit=20
BODY=$(curl -s "$BASE/match/history?limit=abc" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "17 — non-numeric limit falls back to default 20" '"limit":20' "$BODY"

echo ""

# ── Section 5: Pagination Params — invalid offset ────────────────────────────

echo "▶ Section 5: Pagination Params — offset edge cases"

# Test 18 — negative offset → clamped to 0 (silent)
BODY=$(curl -s "$BASE/match/history?offset=-5" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "18 — negative offset clamped to 0" '"offset":0' "$BODY"

# Test 19 — non-numeric offset → default 0
BODY=$(curl -s "$BASE/match/history?offset=abc" \
  -H "Authorization: Bearer $TOKEN")
assert_contains "19 — non-numeric offset falls back to 0" '"offset":0' "$BODY"

echo ""

# ── Section 6: Response Shape ─────────────────────────────────────────────────

echo "▶ Section 6: Response Shape"

BODY=$(curl -s "$BASE/match/history" \
  -H "Authorization: Bearer $TOKEN")

# Test 20 — has data envelope
assert_contains "20 — response has data envelope" '"data"' "$BODY"

# Test 21 — has matches key
assert_contains "21 — response has matches key" '"matches"' "$BODY"

# Test 22 — has pagination key
assert_contains "22 — response has pagination key" '"pagination"' "$BODY"

# Test 23 — pagination has total
assert_contains "23 — pagination has total" '"total"' "$BODY"

# Test 24 — pagination has limit
assert_contains "24 — pagination has limit" '"limit"' "$BODY"

# Test 25 — pagination has offset
assert_contains "25 — pagination has offset" '"offset"' "$BODY"

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
