#!/usr/bin/env bash
# =============================================================================
# Phase 4.4 — Wallet Payment Foundation Test Suite
# Tests: POST /api/wallet/deposit, POST /api/wallet/withdraw
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique email so the test user doesn't collide with prior runs
TS=$(date +%s)
EMAIL="payment${TS}@example.com"
PASSWORD="PaymentPass123"

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
echo " Phase 4.4 — Wallet Payment Foundation Tests"
echo "═══════════════════════════════════════════════════"
echo ""
echo "▶ Setup: Register & Login"

REG=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Payment Player\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
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

# ── Section 1: Auth Protection — POST /wallet/deposit ────────────────────────

echo "▶ Section 1: Auth Protection — POST /wallet/deposit"

# Test 1 — no token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -d '{"amount":100}')
assert_eq "1 — POST /wallet/deposit no token → 401" "401" "$STATUS"

# Test 2 — invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid.token.here" \
  -d '{"amount":100}')
assert_eq "2 — POST /wallet/deposit invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 2: Auth Protection — POST /wallet/withdraw ───────────────────────

echo "▶ Section 2: Auth Protection — POST /wallet/withdraw"

# Test 3 — no token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -d '{"amount":50}')
assert_eq "3 — POST /wallet/withdraw no token → 401" "401" "$STATUS"

# Test 4 — invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid.token.here" \
  -d '{"amount":50}')
assert_eq "4 — POST /wallet/withdraw invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 3: Input Validation — POST /wallet/deposit ───────────────────────

echo "▶ Section 3: Input Validation — POST /wallet/deposit"

# Test 5 — missing amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}')
assert_eq "5 — missing amount → 400" "400" "$STATUS"

# Test 6 — zero amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":0}')
assert_eq "6 — amount=0 → 400" "400" "$STATUS"

# Test 7 — negative amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":-50}')
assert_eq "7 — amount=-50 → 400" "400" "$STATUS"

# Test 8 — non-numeric amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":"abc"}')
assert_eq "8 — amount=abc → 400" "400" "$STATUS"

# Test 9 — amount exceeds maximum
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":2000000}')
assert_eq "9 — amount exceeds max → 400" "400" "$STATUS"

echo ""

# ── Section 4: Input Validation — POST /wallet/withdraw ──────────────────────

echo "▶ Section 4: Input Validation — POST /wallet/withdraw"

# Test 10 — missing amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}')
assert_eq "10 — missing amount → 400" "400" "$STATUS"

# Test 11 — zero amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":0}')
assert_eq "11 — amount=0 → 400" "400" "$STATUS"

# Test 12 — negative amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":-100}')
assert_eq "12 — amount=-100 → 400" "400" "$STATUS"

# Test 13 — non-numeric amount
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":"xyz"}')
assert_eq "13 — amount=xyz → 400" "400" "$STATUS"

echo ""

# ── Section 5: Deposit — Happy Path ──────────────────────────────────────────

echo "▶ Section 5: POST /wallet/deposit — Happy Path"

# Test 14 — basic deposit succeeds
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":500}')
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq   "14 — deposit 500 → 200"              "200"              "$STATUS"
assert_contains "15 — response has success=true"  '"success":true'   "$BODY"
assert_contains "16 — response has wallet object" '"wallet":'        "$BODY"
assert_contains "17 — response has transaction"   '"transaction":'   "$BODY"
assert_contains "18 — wallet points increased"    '"points":500'     "$BODY"
assert_contains "19 — total_deposit updated"      '"total_deposit":500' "$BODY"
assert_contains "20 — transaction type=deposit"   '"type":"deposit"' "$BODY"
assert_contains "21 — transaction status=completed" '"status":"completed"' "$BODY"
assert_contains "22 — transaction amount=500"     '"amount":500'     "$BODY"

# Test 23 — deposit with reference succeeds
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":250,"reference":"EXT-REF-001"}')
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq      "23 — deposit with reference → 200"  "200"            "$STATUS"
assert_contains "24 — reference stored"  '"reference":"EXT-REF-001"' "$BODY"
assert_contains "25 — cumulative balance 750"  '"points":750'         "$BODY"
assert_contains "26 — total_deposit 750"  '"total_deposit":750'       "$BODY"

echo ""

# ── Section 6: Withdraw — Happy Path ─────────────────────────────────────────

echo "▶ Section 6: POST /wallet/withdraw — Happy Path"

# Test 27 — withdraw within balance succeeds
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":200}')
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq   "27 — withdraw 200 → 200"              "200"               "$STATUS"
assert_contains "28 — response has success=true"   '"success":true'    "$BODY"
assert_contains "29 — response has wallet object"  '"wallet":'         "$BODY"
assert_contains "30 — response has transaction"    '"transaction":'    "$BODY"
assert_contains "31 — wallet points reduced"       '"points":550'      "$BODY"
assert_contains "32 — total_withdraw updated"      '"total_withdraw":200' "$BODY"
assert_contains "33 — transaction type=withdraw"   '"type":"withdraw"' "$BODY"
assert_contains "34 — transaction status=completed" '"status":"completed"' "$BODY"
assert_contains "35 — transaction amount=200"      '"amount":200'      "$BODY"

echo ""

# ── Section 7: Insufficient Balance ──────────────────────────────────────────

echo "▶ Section 7: Insufficient Balance"

# Test 36 — withdraw more than balance → 422
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/wallet/withdraw" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":999999}')
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq      "36 — withdraw > balance → 422"        "422"            "$STATUS"
assert_contains "37 — error response success=false"   '"success":false' "$BODY"
assert_contains "38 — error message present"          '"message":'     "$BODY"

echo ""

# ── Section 8: Balance Consistency Check ─────────────────────────────────────

echo "▶ Section 8: Balance Consistency — GET /wallet after transactions"

# Test 39 — GET /wallet reflects all changes
RESP=$(curl -s -w "\n%{http_code}" -X GET "$BASE/wallet" \
  -H "Authorization: Bearer $TOKEN")
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq      "39 — GET /wallet → 200"              "200"             "$STATUS"
assert_contains "40 — final balance 550"             '"points":550'    "$BODY"
assert_contains "41 — final total_deposit 750"       '"total_deposit":750' "$BODY"
assert_contains "42 — final total_withdraw 200"      '"total_withdraw":200' "$BODY"

echo ""

# ── Section 9: Transaction History ───────────────────────────────────────────

echo "▶ Section 9: Transactions appear in history"

RESP=$(curl -s -w "\n%{http_code}" -X GET "$BASE/wallet/history" \
  -H "Authorization: Bearer $TOKEN")
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq      "43 — GET /wallet/history → 200"      "200"             "$STATUS"
assert_contains "44 — history has deposit entries"   '"type":"deposit"' "$BODY"
assert_contains "45 — history has withdraw entry"    '"type":"withdraw"' "$BODY"
assert_contains "46 — all transactions completed"    '"status":"completed"' "$BODY"

echo ""

# ── Section 10: Decimal Amount Support ───────────────────────────────────────

echo "▶ Section 10: Decimal Amount Support"

# Test 47 — deposit decimal amount
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/wallet/deposit" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"amount":10.50}')
BODY=$(echo "$RESP" | head -n -1)
STATUS=$(echo "$RESP" | tail -n 1)
assert_eq      "47 — deposit 10.50 → 200"            "200"             "$STATUS"
assert_contains "48 — decimal amount accepted"        '"amount":10.5'   "$BODY"

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
