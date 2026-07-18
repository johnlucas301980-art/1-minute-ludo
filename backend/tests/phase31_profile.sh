#!/usr/bin/env bash
# =============================================================================
# Phase 3.1 — Player Profile API Test Suite
# Tests: GET /api/profile, PUT /api/profile
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique email so the test user doesn't collide with prior runs
TS=$(date +%s)
EMAIL="testplayer${TS}@example.com"
PASSWORD="Test1234"

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
echo " Phase 3.1 — Player Profile API Tests"
echo "═══════════════════════════════════════════════════"
echo ""
echo "▶  Setup: register test user ($EMAIL)"

REG=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Test Player\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
assert_contains "Register succeeds" '"success":true' "$REG"

echo ""
echo "▶  Setup: login"

LOGIN=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
assert_contains "Login succeeds" '"success":true' "$LOGIN"

TOKEN=$(echo "$LOGIN" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo ""
  echo "❌ Cannot continue — failed to get access token."
  exit 1
fi

echo "   Access token obtained."

# ── Test 1: GET /api/profile — happy path ────────────────────────────────────

echo ""
echo "▶  Test 1: GET /api/profile — authenticated"

R=$(curl -s -X GET "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN")

assert_contains "1.1  success=true"           '"success":true'                    "$R"
assert_contains "1.2  profile object present" '"profile":'                        "$R"
assert_contains "1.3  player_id present"      '"player_id":'                      "$R"
assert_contains "1.4  full_name = Test Player" '"full_name":"Test Player"'         "$R"
assert_contains "1.5  email present"          "\"email\":\"$EMAIL\""              "$R"
assert_not_contains "1.6  password_hash absent from response" 'password_hash' "$R"

# ── Test 2: GET /api/profile — no token ──────────────────────────────────────

echo ""
echo "▶  Test 2: GET /api/profile — no token → 401"

R=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/profile")
assert_eq "2.1  HTTP 401 without token" "401" "$R"

# ── Test 3: GET /api/profile — invalid token ─────────────────────────────────

echo ""
echo "▶  Test 3: GET /api/profile — invalid token → 401"

R=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/profile" \
  -H "Authorization: Bearer invalidtoken.abc.xyz")
assert_eq "3.1  HTTP 401 with invalid token" "401" "$R"

# ── Test 4: PUT /api/profile — update full_name ──────────────────────────────

echo ""
echo "▶  Test 4: PUT /api/profile — update full_name"

R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"full_name":"Updated Name"}')

assert_contains "4.1  success=true"              '"success":true'          "$R"
assert_contains "4.2  full_name updated"         '"full_name":"Updated Name"' "$R"
assert_contains "4.3  profile returned"          '"profile":'              "$R"

# Verify GET reflects the change
R2=$(curl -s "$BASE/profile" -H "Authorization: Bearer $TOKEN")
assert_contains "4.4  GET reflects new full_name" '"full_name":"Updated Name"' "$R2"

# ── Test 5: PUT /api/profile — update country ────────────────────────────────

echo ""
echo "▶  Test 5: PUT /api/profile — update country"

R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"country":"Nigeria"}')

assert_contains "5.1  success=true"       '"success":true'     "$R"
assert_contains "5.2  country updated"    '"country":"Nigeria"' "$R"

# ── Test 6: PUT /api/profile — update avatar ─────────────────────────────────

echo ""
echo "▶  Test 6: PUT /api/profile — update avatar URL"

AVATAR_URL="https://example.com/avatars/player123.png"
R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"avatar\":\"$AVATAR_URL\"}")

assert_contains "6.1  success=true"    '"success":true'  "$R"
assert_contains "6.2  avatar updated"  "\"avatar\":\"$AVATAR_URL\"" "$R"

# ── Test 7: PUT /api/profile — clear avatar (null) ───────────────────────────

echo ""
echo "▶  Test 7: PUT /api/profile — clear avatar (null)"

R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"avatar":null}')

assert_contains "7.1  success=true"      '"success":true'   "$R"
assert_contains "7.2  avatar is null"    '"avatar":null'    "$R"

# ── Test 8: PUT /api/profile — clear country (null) ──────────────────────────

echo ""
echo "▶  Test 8: PUT /api/profile — clear country (null)"

R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"country":null}')

assert_contains "8.1  success=true"       '"success":true'   "$R"
assert_contains "8.2  country is null"    '"country":null'   "$R"

# ── Test 9: PUT /api/profile — validation: empty body ────────────────────────

echo ""
echo "▶  Test 9: PUT /api/profile — empty body → 400"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')

assert_eq "9.1  HTTP 400 on empty body" "400" "$HTTP"

R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
assert_contains "9.2  success=false"   '"success":false'  "$R"
assert_contains "9.3  errors present"  '"errors":'        "$R"

# ── Test 10: PUT /api/profile — validation: full_name too short ──────────────

echo ""
echo "▶  Test 10: PUT /api/profile — full_name too short → 400"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"full_name":"A"}')

assert_eq "10.1 HTTP 400 for 1-char full_name" "400" "$HTTP"

# ── Test 11: PUT /api/profile — validation: invalid avatar URL ───────────────

echo ""
echo "▶  Test 11: PUT /api/profile — invalid avatar URL → 400"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"avatar":"not-a-url"}')

assert_eq "11.1 HTTP 400 for invalid avatar URL" "400" "$HTTP"

R=$(curl -s -X PUT "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"avatar":"not-a-url"}')
assert_contains "11.2 error mentions avatar" '"avatar"' "$R"

# ── Test 12: PUT /api/profile — no token → 401 ───────────────────────────────

echo ""
echo "▶  Test 12: PUT /api/profile — no token → 401"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile" \
  -H "Content-Type: application/json" \
  -d '{"full_name":"Hacker"}')

assert_eq "12.1 HTTP 401 without token" "401" "$HTTP"

# ── Test 13: GET /api/profile — final state verification ─────────────────────

echo ""
echo "▶  Test 13: GET /api/profile — final state"

R=$(curl -s "$BASE/profile" -H "Authorization: Bearer $TOKEN")
assert_contains "13.1 success=true"               '"success":true'           "$R"
assert_contains "13.2 full_name = Updated Name"   '"full_name":"Updated Name"' "$R"
assert_contains "13.3 avatar is null"             '"avatar":null'            "$R"
assert_contains "13.4 country is null"            '"country":null'           "$R"
assert_contains "13.5 player_id format LUD-"      '"player_id":"LUD-'        "$R"
assert_contains "13.6 updated_at present"         '"updated_at":'            "$R"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo " Results: $PASS/$TOTAL passed  |  $FAIL failed"
echo "═══════════════════════════════════════════════════"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
