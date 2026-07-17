#!/usr/bin/env bash
# =============================================================================
# Phase 3.3 — Change Password API Test Suite
# Tests: PUT /api/profile/password
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique email so the test user doesn't collide with prior runs
TS=$(date +%s)
EMAIL="changepw${TS}@example.com"
PASSWORD="OldPass123"
NEW_PASSWORD="NewPass456"

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
echo " Phase 3.3 — Change Password Test Suite"
echo "═══════════════════════════════════════════════════"
echo ""
echo "▶ Setup: Register & Login"

REG=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Change PW Player\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "  Register: $REG"

LOGIN=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "  Login: $LOGIN"

TOKEN=$(echo "$LOGIN" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
REFRESH=$(echo "$LOGIN" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo ""
  echo "  ❌ FATAL: Could not obtain access token — aborting tests."
  exit 1
fi

echo "  Access token obtained ✓"
echo "  Refresh token obtained ✓"
echo ""

# ── Section 1: Validation errors ─────────────────────────────────────────────

echo "▶ Section 1: Validation Errors"

# Test 1 — no body
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}')
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}')
assert_eq "1 — empty body → 400" "400" "$STATUS"
assert_contains "1 — empty body has errors array" '"errors"' "$BODY"

# Test 2 — missing current_password
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"new_password\":\"$NEW_PASSWORD\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"new_password\":\"$NEW_PASSWORD\"}")
assert_eq "2 — missing current_password → 400" "400" "$STATUS"
assert_contains "2 — error field is current_password" '"current_password"' "$BODY"

# Test 3 — missing new_password
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\"}")
assert_eq "3 — missing new_password → 400" "400" "$STATUS"
assert_contains "3 — error field is new_password" '"new_password"' "$BODY"

# Test 4 — new_password too short
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"Ab1\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"Ab1\"}")
assert_eq "4 — new_password < 8 chars → 400" "400" "$STATUS"
assert_contains "4 — error mentions new_password" '"new_password"' "$BODY"

# Test 5 — new_password no letter
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"12345678\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"12345678\"}")
assert_eq "5 — new_password no letter → 400" "400" "$STATUS"
assert_contains "5 — error mentions new_password" '"new_password"' "$BODY"

# Test 6 — new_password no digit
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"NoDigitPw\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"NoDigitPw\"}")
assert_eq "6 — new_password no digit → 400" "400" "$STATUS"
assert_contains "6 — error mentions new_password" '"new_password"' "$BODY"

# Test 7 — new_password identical to current_password
BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"$PASSWORD\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"$PASSWORD\"}")
assert_eq "7 — new_password same as current → 400" "400" "$STATUS"
assert_contains "7 — error mentions new_password" '"new_password"' "$BODY"

echo ""

# ── Section 2: Wrong current password ────────────────────────────────────────

echo "▶ Section 2: Wrong Current Password"

BODY=$(curl -s -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"WrongPass999\",\"new_password\":\"$NEW_PASSWORD\"}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"WrongPass999\",\"new_password\":\"$NEW_PASSWORD\"}")
assert_eq "8 — wrong current_password → 401" "401" "$STATUS"
assert_contains "8 — message: Current password is incorrect" "Current password is incorrect" "$BODY"

echo ""

# ── Section 3: Auth protection ───────────────────────────────────────────────

echo "▶ Section 3: Auth Protection"

# Test 9 — no token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"$NEW_PASSWORD\"}")
assert_eq "9 — no Authorization header → 401" "401" "$STATUS"

# Test 10 — invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid.token.here" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"$NEW_PASSWORD\"}")
assert_eq "10 — invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 4: Successful password change ─────────────────────────────────────

echo "▶ Section 4: Successful Password Change"

# Capture body and HTTP status in a single request — the change is not
# idempotent (old password becomes invalid after first success), so two
# separate curl calls would give a false 401 on the second.
CHANGE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/profile/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"current_password\":\"$PASSWORD\",\"new_password\":\"$NEW_PASSWORD\"}")
BODY=$(echo "$CHANGE_RESPONSE" | head -n -1)
STATUS=$(echo "$CHANGE_RESPONSE" | tail -n 1)
assert_eq "11 — valid change → 200" "200" "$STATUS"
assert_contains "11 — success: true" '"success":true' "$BODY"
assert_contains "11 — message: Password changed successfully" "Password changed successfully" "$BODY"

echo ""

# ── Section 5: Post-change verification ──────────────────────────────────────

echo "▶ Section 5: Post-Change Verification"

# Test 12 — login with new password succeeds
LOGIN2=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$NEW_PASSWORD\"}")
STATUS2=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$NEW_PASSWORD\"}")
assert_eq "12 — login with new password → 200" "200" "$STATUS2"
assert_contains "12 — new login returns access_token" '"access_token"' "$LOGIN2"

# Test 13 — login with old password fails
STATUS3=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
assert_eq "13 — login with old password → 401" "401" "$STATUS3"

# Test 14 — old refresh token revoked
REFRESH_BODY=$(curl -s -X POST "$BASE/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH\"}")
REFRESH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH\"}")
assert_eq "14 — old refresh token revoked → 401" "401" "$REFRESH_STATUS"

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
