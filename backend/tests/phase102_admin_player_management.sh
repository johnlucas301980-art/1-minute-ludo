#!/usr/bin/env bash
# =============================================================================
# Phase 10.2 — Admin Player Management: smoke-test suite
#
# Usage:
#   bash backend/tests/phase102_admin_player_management.sh [BASE_URL]
#
# Defaults to http://localhost:3000/api when BASE_URL is omitted.
#
# Optional env vars (for live HTTP tests):
#   ADMIN_TOKEN        — valid access token for a user with role = 'admin'
#   NON_ADMIN_TOKEN    — valid access token for a user with role = 'player'
#   TEST_TARGET_UUID   — UUID of an existing player to test ban/unban/promote/demote
#
# Prerequisites:
#   - Backend running, DATABASE_URL configured, migration 0014 applied.
#   - jq and curl available.
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

pass() { PASS=$((PASS + 1)); green "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); ERRORS+=("$1"); red "  ✗ $1"; }

section() { echo; yellow "── $1"; }

http_status() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
http_body()   { curl -s "$@"; }

# ─── Static file checks ───────────────────────────────────────────────────────

section "File existence checks"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

FILES=(
  # Phase 10.2 new files
  "backend/src/db/migrations/0014_create_admin_audit_log.sql"
  "mobile/lib/features/admin/models/audit_log_entry.dart"
  "mobile/lib/features/admin/screens/player_list_screen.dart"
  "mobile/lib/features/admin/screens/player_detail_screen.dart"
  # Phase 10.2 updated files
  "backend/src/services/admin.service.ts"
  "backend/src/controllers/admin.controller.ts"
  "backend/src/routes/admin.ts"
  "mobile/lib/features/admin/services/admin_service.dart"
  "mobile/lib/features/admin/screens/admin_screen.dart"
  # Phase 10.1 regression — must still be present
  "backend/src/db/migrations/0013_add_user_roles.sql"
  "backend/src/middlewares/requireAdmin.ts"
  "backend/tests/phase101_admin_foundation.sh"
)

for f in "${FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    pass "Exists: $f"
  else
    fail "Missing: $f"
  fi
done

# ─── Migration 0014 content checks ───────────────────────────────────────────

section "Migration 0014 content checks"

M14="$REPO_ROOT/backend/src/db/migrations/0014_create_admin_audit_log.sql"
if [[ -f "$M14" ]]; then
  grep -q "admin_audit_log"  "$M14" && pass "Creates admin_audit_log table"      || fail "Missing admin_audit_log table"
  grep -q "admin_id"         "$M14" && pass "Has admin_id column"                 || fail "Missing admin_id column"
  grep -q "target_user_id"   "$M14" && pass "Has target_user_id column"           || fail "Missing target_user_id column"
  grep -q "action"           "$M14" && pass "Has action column"                   || fail "Missing action column"
  grep -qE "'ban'.*'unban'"  "$M14" && pass "CHECK includes ban/unban"            || fail "CHECK missing ban/unban"
  grep -q "promote"          "$M14" && pass "CHECK includes promote"              || fail "CHECK missing promote"
  grep -q "demote"           "$M14" && pass "CHECK includes demote"               || fail "CHECK missing demote"
  grep -q "CREATE INDEX"     "$M14" && pass "Has indexes"                         || fail "Missing indexes"
else
  fail "Migration 0014 not found — skipping content checks"
fi

# ─── TypeScript compilation ───────────────────────────────────────────────────

section "TypeScript compilation"

TSC="$(find "$REPO_ROOT/node_modules/.pnpm" -name "tsc" -path "*/typescript/bin/tsc" 2>/dev/null | head -1)"
if [[ -n "$TSC" ]]; then
  if (cd "$REPO_ROOT/backend" && node "$TSC" -p tsconfig.json --noEmit 2>&1); then
    pass "TypeScript compilation succeeded"
  else
    fail "TypeScript compilation failed"
  fi
elif command -v pnpm &>/dev/null; then
  if (cd "$REPO_ROOT" && pnpm --filter @workspace/backend run typecheck 2>&1); then
    pass "TypeScript typecheck passed"
  else
    fail "TypeScript typecheck failed"
  fi
else
  yellow "  ⚠ TypeScript compiler not found — skipping"
fi

# ─── Phase 10.1 regression ───────────────────────────────────────────────────

section "Phase 10.1 regression (file-existence sub-check)"

P101_FILES=(
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
  "backend/tests/phase101_admin_foundation.sh"
)

for f in "${P101_FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    pass "10.1 regression — still present: $f"
  else
    fail "10.1 regression — MISSING: $f"
  fi
done

# ─── Route registration checks ────────────────────────────────────────────────

section "Route registration checks"

ROUTES_FILE="$REPO_ROOT/backend/src/routes/admin.ts"
if [[ -f "$ROUTES_FILE" ]]; then
  grep -q "ban"        "$ROUTES_FILE" && pass "Route file contains ban endpoint"      || fail "Route file missing ban endpoint"
  grep -q "unban"      "$ROUTES_FILE" && pass "Route file contains unban endpoint"    || fail "Route file missing unban endpoint"
  grep -q "promote"    "$ROUTES_FILE" && pass "Route file contains promote endpoint"  || fail "Route file missing promote endpoint"
  grep -q "demote"     "$ROUTES_FILE" && pass "Route file contains demote endpoint"   || fail "Route file missing demote endpoint"
  grep -q "audit-log"  "$ROUTES_FILE" && pass "Route file contains audit-log endpoint" || fail "Route file missing audit-log endpoint"
else
  fail "admin.ts routes file not found"
fi

SERVICE_FILE="$REPO_ROOT/backend/src/services/admin.service.ts"
if [[ -f "$SERVICE_FILE" ]]; then
  grep -q "logAdminAction" "$SERVICE_FILE" && pass "Service exports logAdminAction"  || fail "Service missing logAdminAction"
  grep -q "getAuditLog"    "$SERVICE_FILE" && pass "Service exports getAuditLog"     || fail "Service missing getAuditLog"
  grep -q "banUser"        "$SERVICE_FILE" && pass "Service exports banUser"         || fail "Service missing banUser"
  grep -q "unbanUser"      "$SERVICE_FILE" && pass "Service exports unbanUser"       || fail "Service missing unbanUser"
  grep -q "promoteUser"    "$SERVICE_FILE" && pass "Service exports promoteUser"     || fail "Service missing promoteUser"
  grep -q "demoteUser"     "$SERVICE_FILE" && pass "Service exports demoteUser"      || fail "Service missing demoteUser"
  grep -q "search"         "$SERVICE_FILE" && pass "listUsers supports search param" || fail "listUsers missing search param"
else
  fail "admin.service.ts not found"
fi

# ─── Live HTTP checks (optional) ─────────────────────────────────────────────

section "Live HTTP checks (require running backend at $BASE_URL)"

if ! curl -s --max-time 3 "$BASE_URL/health" &>/dev/null; then
  yellow "  ⚠ Backend not reachable at $BASE_URL — skipping live checks"
else

  # ── Authorization tests ────────────────────────────────────────────────────

  for ENDPOINT in \
    "GET /admin/stats" \
    "GET /admin/users" \
    "GET /admin/audit-log" \
    "POST /admin/users/00000000-0000-0000-0000-000000000000/ban" \
    "POST /admin/users/00000000-0000-0000-0000-000000000000/unban" \
    "POST /admin/users/00000000-0000-0000-0000-000000000000/promote" \
    "POST /admin/users/00000000-0000-0000-0000-000000000000/demote"; do
    METHOD="${ENDPOINT%% *}"
    PATH_="${ENDPOINT##* }"
    STATUS=$(http_status -X "$METHOD" "$BASE_URL$PATH_")
    if [[ "$STATUS" == "401" ]]; then
      pass "$METHOD $PATH_ — unauthenticated → 401"
    else
      fail "$METHOD $PATH_ — unauthenticated expected 401, got $STATUS"
    fi
  done

  # ── Non-admin 403 tests ────────────────────────────────────────────────────

  if [[ -n "${NON_ADMIN_TOKEN:-}" ]]; then
    for ENDPOINT in "GET /admin/users" "GET /admin/audit-log"; do
      METHOD="${ENDPOINT%% *}"
      PATH_="${ENDPOINT##* }"
      STATUS=$(http_status -X "$METHOD" "$BASE_URL$PATH_" \
        -H "Authorization: Bearer $NON_ADMIN_TOKEN")
      if [[ "$STATUS" == "403" ]]; then
        pass "$METHOD $PATH_ — player token → 403"
      else
        fail "$METHOD $PATH_ — player token expected 403, got $STATUS"
      fi
    done
  else
    yellow "  ⚠ NON_ADMIN_TOKEN not set — skipping 403 authorization tests"
  fi

  # ── Admin-authenticated tests ──────────────────────────────────────────────

  if [[ -n "${ADMIN_TOKEN:-}" ]]; then

    # Search test
    STATUS=$(http_status -X GET "$BASE_URL/admin/users?search=test" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if [[ "$STATUS" == "200" ]]; then
      pass "GET /admin/users?search=test — admin → 200"
    else
      fail "GET /admin/users?search=test — admin expected 200, got $STATUS"
    fi

    # Pagination test
    BODY=$(http_body -X GET "$BASE_URL/admin/users?limit=5&offset=0" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if echo "$BODY" | grep -q '"pagination"'; then
      pass "GET /admin/users — response contains pagination object"
    else
      fail "GET /admin/users — response missing pagination object"
    fi

    # Audit log — should return 200 even if empty
    STATUS=$(http_status -X GET "$BASE_URL/admin/audit-log" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if [[ "$STATUS" == "200" ]]; then
      pass "GET /admin/audit-log — admin → 200"
    else
      fail "GET /admin/audit-log — admin expected 200, got $STATUS"
    fi

    # Invalid action filter should return 400
    STATUS=$(http_status -X GET "$BASE_URL/admin/audit-log?action=invalid_action" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    if [[ "$STATUS" == "400" ]]; then
      pass "GET /admin/audit-log?action=invalid_action → 400"
    else
      fail "GET /admin/audit-log?action=invalid_action expected 400, got $STATUS"
    fi

    # Ban/unban/promote/demote on a real user
    if [[ -n "${TEST_TARGET_UUID:-}" ]]; then

      STATUS=$(http_status -X POST "$BASE_URL/admin/users/$TEST_TARGET_UUID/ban" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      if [[ "$STATUS" == "200" ]]; then
        pass "POST /admin/users/:id/ban — admin → 200"
      else
        fail "POST /admin/users/:id/ban — expected 200, got $STATUS"
      fi

      STATUS=$(http_status -X POST "$BASE_URL/admin/users/$TEST_TARGET_UUID/unban" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      if [[ "$STATUS" == "200" ]]; then
        pass "POST /admin/users/:id/unban — admin → 200"
      else
        fail "POST /admin/users/:id/unban — expected 200, got $STATUS"
      fi

      STATUS=$(http_status -X POST "$BASE_URL/admin/users/$TEST_TARGET_UUID/promote" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      if [[ "$STATUS" == "200" ]]; then
        pass "POST /admin/users/:id/promote — admin → 200"
      else
        fail "POST /admin/users/:id/promote — expected 200, got $STATUS"
      fi

      STATUS=$(http_status -X POST "$BASE_URL/admin/users/$TEST_TARGET_UUID/demote" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      if [[ "$STATUS" == "200" ]]; then
        pass "POST /admin/users/:id/demote — admin → 200"
      else
        fail "POST /admin/users/:id/demote — expected 200, got $STATUS"
      fi

      # After ban/unban cycle, audit log should have at least 2 new entries
      AUDIT_BODY=$(http_body -X GET \
        "$BASE_URL/admin/audit-log?target_user_id=$TEST_TARGET_UUID&limit=10" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      if echo "$AUDIT_BODY" | grep -q '"ban"'; then
        pass "Audit log contains ban entry for test target"
      else
        fail "Audit log missing ban entry for test target"
      fi
      if echo "$AUDIT_BODY" | grep -q '"unban"'; then
        pass "Audit log contains unban entry for test target"
      else
        fail "Audit log missing unban entry for test target"
      fi

    else
      yellow "  ⚠ TEST_TARGET_UUID not set — skipping ban/unban/promote/demote live tests"

      # Non-existent UUID should return 404
      FAKE_UUID="00000000-0000-4000-8000-000000000000"
      STATUS=$(http_status -X POST "$BASE_URL/admin/users/$FAKE_UUID/ban" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      if [[ "$STATUS" == "404" ]]; then
        pass "POST /admin/users/nonexistent/ban → 404"
      else
        fail "POST /admin/users/nonexistent/ban expected 404, got $STATUS"
      fi
    fi

  else
    yellow "  ⚠ ADMIN_TOKEN not set — skipping admin-authenticated live checks"
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo
echo "─────────────────────────────────────────────────────"
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
