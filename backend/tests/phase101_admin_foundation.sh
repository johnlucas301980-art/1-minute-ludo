#!/usr/bin/env bash
# =============================================================================
# Phase 10.1 — Admin Foundation: smoke-test suite
#
# Usage:
#   bash backend/tests/phase101_admin_foundation.sh [BASE_URL]
#
# Defaults to http://localhost:3000/api when BASE_URL is omitted.
#
# Prerequisites:
#   - Backend is running and DATABASE_URL is configured.
#   - jq is installed (for JSON parsing).
#   - curl is installed.
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
# =============================================================================

set -euo pipefail

BASE_URL="${1:-http://localhost:3000/api}"
PASS=0
FAIL=0
ERRORS=()

# ─── Helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }

pass() {
  PASS=$((PASS + 1))
  green "  ✓ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
  red "  ✗ $1"
}

# Perform a curl request and return the HTTP status code.
http_status() {
  curl -s -o /dev/null -w "%{http_code}" "$@"
}

# Perform a curl request and return the response body.
http_body() {
  curl -s "$@"
}

# ─── Static file checks ───────────────────────────────────────────────────────

section() { echo; yellow "── $1"; }

section "File existence checks"

FILES=(
  "backend/src/db/migrations/0013_add_user_roles.sql"
  "backend/src/middlewares/requireAdmin.ts"
  "backend/src/services/admin.service.ts"
  "backend/src/controllers/admin.controller.ts"
  "backend/src/routes/admin.ts"
  "mobile/lib/features/admin/models/admin_user.dart"
  "mobile/lib/features/admin/models/admin_stats.dart"
  "mobile/lib/features/admin/models/admin_ticket.dart"
  "mobile/lib/features/admin/services/admin_service.dart"
  "mobile/lib/features/admin/screens/admin_screen.dart"
)

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

for f in "${FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    pass "Exists: $f"
  else
    fail "Missing: $f"
  fi
done

# ─── Migration content checks ─────────────────────────────────────────────────

section "Migration 0013 content checks"

MIGRATION="$REPO_ROOT/backend/src/db/migrations/0013_add_user_roles.sql"
if [[ -f "$MIGRATION" ]]; then
  grep -q "ADD COLUMN" "$MIGRATION"                   && pass "Migration adds a column"         || fail "Migration missing ADD COLUMN"
  grep -q "role"       "$MIGRATION"                   && pass "Migration references 'role'"     || fail "Migration missing 'role' column"
  grep -q "player"     "$MIGRATION"                   && pass "Migration includes 'player' role" || fail "Migration missing 'player' value"
  grep -q "admin"      "$MIGRATION"                   && pass "Migration includes 'admin' role"  || fail "Migration missing 'admin' value"
else
  fail "Migration file not found — skipping content checks"
fi

# ─── TypeScript compilation check ─────────────────────────────────────────────

section "TypeScript compilation"

if command -v pnpm &>/dev/null; then
  if (cd "$REPO_ROOT" && pnpm --filter @workspace/backend exec tsc --noEmit 2>&1); then
    pass "TypeScript compilation succeeded"
  else
    fail "TypeScript compilation failed (see output above)"
  fi
else
  yellow "  ⚠ pnpm not found — skipping TypeScript check"
fi

# ─── Live HTTP checks (optional — require a running backend) ──────────────────

section "Live HTTP checks (require running backend at $BASE_URL)"

if ! curl -s --max-time 3 "$BASE_URL/health" &>/dev/null; then
  yellow "  ⚠ Backend not reachable at $BASE_URL — skipping live checks"
else
  # 1. Unauthenticated requests should get 401.
  STATUS=$(http_status -X GET "$BASE_URL/admin/stats")
  if [[ "$STATUS" == "401" ]]; then
    pass "GET /admin/stats — unauthenticated → 401"
  else
    fail "GET /admin/stats — unauthenticated expected 401, got $STATUS"
  fi

  STATUS=$(http_status -X GET "$BASE_URL/admin/users")
  if [[ "$STATUS" == "401" ]]; then
    pass "GET /admin/users — unauthenticated → 401"
  else
    fail "GET /admin/users — unauthenticated expected 401, got $STATUS"
  fi

  STATUS=$(http_status -X GET "$BASE_URL/admin/tickets")
  if [[ "$STATUS" == "401" ]]; then
    pass "GET /admin/tickets — unauthenticated → 401"
  else
    fail "GET /admin/tickets — unauthenticated expected 401, got $STATUS"
  fi

  # 2. If an access token is provided for a non-admin user, expect 403.
  if [[ -n "${NON_ADMIN_TOKEN:-}" ]]; then
    STATUS=$(http_status -X GET "$BASE_URL/admin/stats" \
      -H "Authorization: Bearer $NON_ADMIN_TOKEN")
    if [[ "$STATUS" == "403" ]]; then
      pass "GET /admin/stats — non-admin token → 403"
    else
      fail "GET /admin/stats — non-admin token expected 403, got $STATUS"
    fi
  else
    yellow "  ⚠ NON_ADMIN_TOKEN not set — skipping 403 check"
  fi

  # 3. If an admin access token is provided, expect 200.
  if [[ -n "${ADMIN_TOKEN:-}" ]]; then
    STATUS=$(http_status -X GET "$BASE_URL/admin/stats" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if [[ "$STATUS" == "200" ]]; then
      pass "GET /admin/stats — admin token → 200"
    else
      fail "GET /admin/stats — admin token expected 200, got $STATUS"
    fi

    STATUS=$(http_status -X GET "$BASE_URL/admin/users" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if [[ "$STATUS" == "200" ]]; then
      pass "GET /admin/users — admin token → 200"
    else
      fail "GET /admin/users — admin token expected 200, got $STATUS"
    fi

    STATUS=$(http_status -X GET "$BASE_URL/admin/tickets" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if [[ "$STATUS" == "200" ]]; then
      pass "GET /admin/tickets — admin token → 200"
    else
      fail "GET /admin/tickets — admin token expected 200, got $STATUS"
    fi

    # 4. Invalid status value should return 400.
    STATUS=$(http_status -X PATCH "$BASE_URL/admin/users/00000000-0000-0000-0000-000000000000/status" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"status":"invalid"}')
    if [[ "$STATUS" == "400" ]]; then
      pass "PATCH /admin/users/:id/status — invalid status → 400"
    else
      fail "PATCH /admin/users/:id/status — invalid status expected 400, got $STATUS"
    fi

    STATUS=$(http_status -X PATCH "$BASE_URL/admin/tickets/00000000-0000-0000-0000-000000000000/status" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"status":"invalid"}')
    if [[ "$STATUS" == "400" ]]; then
      pass "PATCH /admin/tickets/:id/status — invalid status → 400"
    else
      fail "PATCH /admin/tickets/:id/status — invalid status expected 400, got $STATUS"
    fi
  else
    yellow "  ⚠ ADMIN_TOKEN not set — skipping authenticated admin checks"
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo
echo "─────────────────────────────────────"
green "Passed: $PASS"
if [[ $FAIL -gt 0 ]]; then
  red "Failed: $FAIL"
  echo
  red "Failures:"
  for e in "${ERRORS[@]}"; do
    red "  • $e"
  done
  exit 1
else
  green "All checks passed."
fi
