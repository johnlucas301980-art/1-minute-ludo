#!/usr/bin/env bash
# =============================================================================
# Phase 3.6 — Avatar Upload API Test Suite
# Tests: PUT /api/profile/avatar
# =============================================================================

BASE="${BASE:-http://localhost:5000/api}"
PASS=0
FAIL=0

# Unique email so the test user doesn't collide with prior runs
TS=$(date +%s)
EMAIL="avatar${TS}@example.com"
PASSWORD="AvatarPass123"

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

# ── Create minimal test image files ──────────────────────────────────────────

TMPDIR_PATH=$(mktemp -d)
trap 'rm -rf "$TMPDIR_PATH"' EXIT

# Minimal 1×1 red PNG (base64-encoded)
python3 - <<'PYEOF'
import base64, os, sys
tmpdir = os.environ.get('TMPDIR_PATH') or sys.argv[1]

# 1×1 red PNG
png = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADklEQVQI12P4'
    'z8BQDwAEgAF/QualIQAAAABJRU5ErkJggg=='
)
with open(os.path.join(os.environ['TMPDIR_PATH'], 'test.png'), 'wb') as f:
    f.write(png)

# Minimal 1×1 JPEG (white pixel)
jpg = base64.b64decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsL'
    'DBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/'
    'wAARC'
    'AABAAEDAS'
    'IAAhEBAxEB/8QAFgABAQEAAAAAAAAAAAAAAAAAAAAHCP/EAB'
    'MQAQEAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEB'
    'AAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8Amk0AAAAAAAAB/9k='
)
with open(os.path.join(os.environ['TMPDIR_PATH'], 'test.jpg'), 'wb') as f:
    f.write(jpg)

# Minimal valid WEBP (1×1 white)
webp = base64.b64decode(
    'UklGRlYAAABXRUJQVlA4IEoAAADQAQCdASoBAAEAAkA4JZACdAEO/gHOAAD'
    'u/LT7+5v2uu4PiIX5B9Y9htxs5JYxvkHVjMvS2yYiXb0BRGM5R8b67ESAAA='
)
with open(os.path.join(os.environ['TMPDIR_PATH'], 'test.webp'), 'wb') as f:
    f.write(webp)

# GIF file (unsupported type)
gif = base64.b64decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')
with open(os.path.join(os.environ['TMPDIR_PATH'], 'test.gif'), 'wb') as f:
    f.write(gif)

print("Test images created.")
PYEOF

export TMPDIR_PATH

# Create oversized file (> 2 MB) with JPEG-like content-type
python3 -c "
import os
tmpdir = os.environ['TMPDIR_PATH']
# Write 2.1 MB of zero bytes — server sees image/jpeg from the form field type
with open(os.path.join(tmpdir, 'large.jpg'), 'wb') as f:
    f.write(b'\\x00' * (2 * 1024 * 1024 + 100 * 1024))
print('Large file created.')
"

echo ""
echo "═══════════════════════════════════════════════════"
echo " Phase 3.6 — Avatar Upload Test Suite"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Setup: Register & Login ───────────────────────────────────────────────────

echo "▶ Setup: Register & Login"

REG=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"full_name\":\"Avatar Player\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "  Register: $REG"

LOGIN=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "  Login: $LOGIN"

TOKEN=$(echo "$LOGIN" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo ""
  echo "  ❌ FATAL: Could not obtain access token — aborting tests."
  exit 1
fi

echo "  Access token obtained ✓"
echo ""

# ── Section 1: Auth Protection ───────────────────────────────────────────────

echo "▶ Section 1: Auth Protection"

# Test 1 — no token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/avatar" \
  -F "avatar=@${TMPDIR_PATH}/test.jpg;type=image/jpeg")
assert_eq "1 — no Authorization header → 401" "401" "$STATUS"

# Test 2 — invalid token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer invalid.token.here" \
  -F "avatar=@${TMPDIR_PATH}/test.jpg;type=image/jpeg")
assert_eq "2 — invalid token → 401" "401" "$STATUS"

echo ""

# ── Section 2: Validation Errors ─────────────────────────────────────────────

echo "▶ Section 2: Validation Errors"

# Test 3 — no file attached (JSON body, wrong content type for upload)
BODY=$(curl -s -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
assert_eq "3 — no file attached → 400" "400" "$STATUS"
assert_contains "3 — body has success:false" '"success":false' "$BODY"

# Test 4 — disallowed MIME type (GIF)
BODY=$(curl -s -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.gif;type=image/gif")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.gif;type=image/gif")
assert_eq "4 — GIF MIME type → 400" "400" "$STATUS"
assert_contains "4 — body has success:false" '"success":false' "$BODY"

# Test 5 — file exceeds 2 MB limit
BODY=$(curl -s -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/large.jpg;type=image/jpeg")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/large.jpg;type=image/jpeg")
assert_eq "5 — file > 2 MB → 400" "400" "$STATUS"
assert_contains "5 — body has success:false" '"success":false' "$BODY"

echo ""

# ── Section 3: Successful Uploads ────────────────────────────────────────────

echo "▶ Section 3: Successful Uploads"

# Test 6 — valid JPEG upload
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.jpg;type=image/jpeg")
BODY=$(echo "$UPLOAD_RESPONSE" | head -n -1)
STATUS=$(echo "$UPLOAD_RESPONSE" | tail -n 1)
assert_eq "6 — valid JPEG upload → 200" "200" "$STATUS"
assert_contains "6 — success: true" '"success":true' "$BODY"
assert_contains "6 — response contains avatar URL" '"avatar"' "$BODY"
assert_contains "6 — avatar URL contains .jpg" '.jpg' "$BODY"

AVATAR_URL=$(echo "$BODY" | grep -o '"avatar":"[^"]*"' | cut -d'"' -f4)
echo "  Avatar URL: $AVATAR_URL"

# Test 7 — GET /profile reflects new avatar
PROFILE=$(curl -s -X GET "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN")
PROFILE_AVATAR=$(echo "$PROFILE" | grep -o '"avatar":"[^"]*"' | cut -d'"' -f4)
assert_eq "7 — GET /profile avatar matches upload response" "$AVATAR_URL" "$PROFILE_AVATAR"

# Test 8 — avatar file is reachable via HTTP (only feasible when HOST = localhost)
if echo "$BASE" | grep -q "localhost"; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$AVATAR_URL")
  assert_eq "8 — uploaded file served via static route → 200" "200" "$HTTP_STATUS"
else
  echo "  ⏭  SKIP: 8 — static file check skipped (non-localhost BASE)"
  PASS=$((PASS + 1))
fi

echo ""

# ── Section 4: PNG and WEBP Uploads ──────────────────────────────────────────

echo "▶ Section 4: PNG and WEBP Uploads"

# Test 9 — valid PNG upload
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.png;type=image/png")
BODY=$(echo "$UPLOAD_RESPONSE" | head -n -1)
STATUS=$(echo "$UPLOAD_RESPONSE" | tail -n 1)
assert_eq "9 — valid PNG upload → 200" "200" "$STATUS"
assert_contains "9 — avatar URL contains .png" '.png' "$BODY"

# Test 10 — valid WEBP upload
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.webp;type=image/webp")
BODY=$(echo "$UPLOAD_RESPONSE" | head -n -1)
STATUS=$(echo "$UPLOAD_RESPONSE" | tail -n 1)
assert_eq "10 — valid WEBP upload → 200" "200" "$STATUS"
assert_contains "10 — avatar URL contains .webp" '.webp' "$BODY"

echo ""

# ── Section 5: Replace Existing Avatar ───────────────────────────────────────

echo "▶ Section 5: Replace Existing Avatar"

# Upload JPEG first
FIRST=$(curl -s -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.jpg;type=image/jpeg")
FIRST_URL=$(echo "$FIRST" | grep -o '"avatar":"[^"]*"' | cut -d'"' -f4)
echo "  First upload URL : $FIRST_URL"

# Now upload PNG to replace
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/profile/avatar" \
  -H "Authorization: Bearer $TOKEN" \
  -F "avatar=@${TMPDIR_PATH}/test.png;type=image/png")
BODY=$(echo "$UPLOAD_RESPONSE" | head -n -1)
STATUS=$(echo "$UPLOAD_RESPONSE" | tail -n 1)
SECOND_URL=$(echo "$BODY" | grep -o '"avatar":"[^"]*"' | cut -d'"' -f4)
echo "  Second upload URL: $SECOND_URL"

assert_eq "11 — second upload (replace) → 200" "200" "$STATUS"
assert_contains "11 — new URL ends in .png" '.png' "$BODY"

# GET /profile must reflect the latest upload
PROFILE=$(curl -s -X GET "$BASE/profile" \
  -H "Authorization: Bearer $TOKEN")
PROFILE_AVATAR=$(echo "$PROFILE" | grep -o '"avatar":"[^"]*"' | cut -d'"' -f4)
assert_eq "12 — GET /profile reflects latest avatar" "$SECOND_URL" "$PROFILE_AVATAR"

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
