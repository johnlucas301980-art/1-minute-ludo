#!/usr/bin/env bash
# =============================================================================
# Phase 10.3 — Match Monitoring: smoke-test suite
#
# Usage:
#   bash backend/tests/phase103_match_monitoring.sh [BASE_URL]
#
# Defaults to http://localhost:3000/api when BASE_URL is omitted.
#
# Optional env vars (for live HTTP tests):
#   ADMIN_TOKEN        — valid access token for a user with role = 'admin'
#   NON_ADMIN_TOKEN    — valid access token for a user with role = 'player'
#   TEST_MATCH_UUID    — UUID of an existing match to test detail/events endpoints
#
# Prerequisites:
#   - Backend running, DATABASE_URL configured, migration 0015 applied.
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
  # Phase 10.3 new files
  "backend/src/db/migrations/0015_admin_audit_log_add_match_cancel.sql"
  "mobile/lib/features/admin/models/admin_match.dart"
  "mobile/lib/features/admin/screens/match_monitor_screen.dart"
  "mobile/lib/features/admin/screens/match_details_screen.dart"
  # Phase 10.3 updated files
  "backend/src/services/admin.service.ts"
  "backend/src/controllers/admin.controller.ts"
  "backend/src/routes/admin.ts"
  "mobile/lib/features/admin/services/admin_service.dart"
  "mobile/lib/features/admin/screens/admin_screen.dart"
  # Phase 10.2 regression
  "backend/src/db/migrations/0014_create_admin_audit_log.sql"
  "mobile/lib/features/admin/models/audit_log_entry.dart"
  "mobile/lib/features/admin/screens/player_list_screen.dart"
  "mobile/lib/features/admin/screens/player_detail_screen.dart"
  "backend/tests/phase102_admin_player_management.sh"
  # Phase 10.1 regression
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

# ─── Migration 0015 content checks ───────────────────────────────────────────

section "Migration 0015 content checks"

M15="$REPO_ROOT/backend/src/db/migrations/0015_admin_audit_log_add_match_cancel.sql"
if [[ -f "$M15" ]]; then
  grep -q "match_cancel"    "$M15" && pass "Adds match_cancel action"          || fail "Missing match_cancel action"
  grep -q "DROP CONSTRAINT" "$M15" && pass "Drops existing constraint first"   || fail "Missing DROP CONSTRAINT"
  grep -q "ADD CONSTRAINT"  "$M15" && pass "Adds updated constraint"           || fail "Missing ADD CONSTRAINT"
  grep -q "'ban'"           "$M15" && pass "Preserves existing actions (ban)"  || fail "Missing existing action ban"
  grep -q "'unban'"         "$M15" && pass "Preserves existing actions (unban)"|| fail "Missing existing action unban"
else
  fail "Migration 0015 not found — skipping content checks"
fi

# ─── Route registration checks ───────────────────────────────────────────────

section "Route registration checks"

ROUTES="$REPO_ROOT/backend/src/routes/admin.ts"
if [[ -f "$ROUTES" ]]; then
  grep -q "admin/matches"            "$ROUTES" && pass "Route file contains /admin/matches"                || fail "Missing /admin/matches route"
  grep -q "admin/matches/:id"        "$ROUTES" && pass "Route file contains /admin/matches/:id"           || fail "Missing /admin/matches/:id route"
  grep -q "admin/matches/:id/events" "$ROUTES" && pass "Route file contains /admin/matches/:id/events"    || fail "Missing /admin/matches/:id/events route"
  grep -q "admin/matches/:id/cancel" "$ROUTES" && pass "Route file contains /admin/matches/:id/cancel"    || fail "Missing /admin/matches/:id/cancel route"
  grep -q "listMatchesHandler"       "$ROUTES" && pass "Imports listMatchesHandler"                       || fail "Missing listMatchesHandler import"
  grep -q "getMatchHandler"          "$ROUTES" && pass "Imports getMatchHandler"                          || fail "Missing getMatchHandler import"
  grep -q "getMatchEventsHandler"    "$ROUTES" && pass "Imports getMatchEventsHandler"                    || fail "Missing getMatchEventsHandler import"
  grep -q "cancelMatchHandler"       "$ROUTES" && pass "Imports cancelMatchHandler"                       || fail "Missing cancelMatchHandler import"
else
  fail "Routes file not found"
fi

# ─── Service function checks ──────────────────────────────────────────────────

section "Backend service function checks"

SVC="$REPO_ROOT/backend/src/services/admin.service.ts"
if [[ -f "$SVC" ]]; then
  grep -q "export async function listMatches"  "$SVC" && pass "Service exports listMatches"  || fail "Missing listMatches"
  grep -q "export async function getMatchById" "$SVC" && pass "Service exports getMatchById" || fail "Missing getMatchById"
  grep -q "export async function getMatchEvents" "$SVC" && pass "Service exports getMatchEvents" || fail "Missing getMatchEvents"
  grep -q "export async function cancelMatch"  "$SVC" && pass "Service exports cancelMatch"  || fail "Missing cancelMatch"
  grep -q "match_cancel"                       "$SVC" && pass "cancelMatch logs match_cancel action" || fail "Missing match_cancel audit log"
  grep -q "CANCELLABLE_STATUSES"               "$SVC" && pass "CANCELLABLE_STATUSES guard exists" || fail "Missing CANCELLABLE_STATUSES"
else
  fail "Service file not found"
fi

# ─── Flutter model checks ─────────────────────────────────────────────────────

section "Flutter model checks"

MODEL="$REPO_ROOT/mobile/lib/features/admin/models/admin_match.dart"
if [[ -f "$MODEL" ]]; then
  grep -q "class AdminMatch"       "$MODEL" && pass "AdminMatch class exists"       || fail "Missing AdminMatch class"
  grep -q "class AdminMatchPlayer" "$MODEL" && pass "AdminMatchPlayer class exists" || fail "Missing AdminMatchPlayer class"
  grep -q "class AdminMatchEvent"  "$MODEL" && pass "AdminMatchEvent class exists"  || fail "Missing AdminMatchEvent class"
  grep -q "isCancellable"          "$MODEL" && pass "isCancellable getter exists"   || fail "Missing isCancellable getter"
  grep -q "fromJson"               "$MODEL" && pass "fromJson factory exists"       || fail "Missing fromJson factory"
else
  fail "AdminMatch model not found"
fi

# ─── Flutter service method checks ────────────────────────────────────────────

section "Flutter AdminService method checks"

ASVC="$REPO_ROOT/mobile/lib/features/admin/services/admin_service.dart"
if [[ -f "$ASVC" ]]; then
  grep -q "getMatches"       "$ASVC" && pass "AdminService has getMatches"       || fail "Missing getMatches"
  grep -q "getMatchById"     "$ASVC" && pass "AdminService has getMatchById"     || fail "Missing getMatchById"
  grep -q "getMatchEvents"   "$ASVC" && pass "AdminService has getMatchEvents"   || fail "Missing getMatchEvents"
  grep -q "cancelMatch"      "$ASVC" && pass "AdminService has cancelMatch"      || fail "Missing cancelMatch"
  grep -q "searchUsers"      "$ASVC" && pass "AdminService still has searchUsers (10.2 regression)" || fail "10.2 regression: missing searchUsers"
else
  fail "Flutter AdminService not found"
fi

# ─── Flutter screen checks ────────────────────────────────────────────────────

section "Flutter screen checks"

# match_monitor_screen: must have search + filter + navigation to detail
MM="$REPO_ROOT/mobile/lib/features/admin/screens/match_monitor_screen.dart"
if [[ -f "$MM" ]]; then
  grep -q "class MatchMonitorScreen" "$MM"   && pass "MatchMonitorScreen class exists"      || fail "Missing MatchMonitorScreen class"
  grep -q "search"                   "$MM"   && pass "MatchMonitorScreen has search support" || fail "Missing search in MatchMonitorScreen"
  grep -q "_FilterChip\|FilterRow\|statusFilter\|filter" "$MM" \
                                             && pass "MatchMonitorScreen has filter support"  || fail "Missing filter in MatchMonitorScreen"
  grep -q "MatchDetailsScreen"       "$MM"   && pass "MatchMonitorScreen navigates to MatchDetailsScreen" \
                                             || fail "MatchMonitorScreen missing navigation to MatchDetailsScreen"
else
  fail "Missing screen file: match_monitor_screen.dart"
fi

# match_details_screen: must have cancel action and timeline events
MD="$REPO_ROOT/mobile/lib/features/admin/screens/match_details_screen.dart"
if [[ -f "$MD" ]]; then
  grep -q "class MatchDetailsScreen"               "$MD" && pass "MatchDetailsScreen class exists"       || fail "Missing MatchDetailsScreen class"
  grep -q "cancelMatch\|cancel_match_button\|isCancellable\|Cancel Match" "$MD" \
                                                         && pass "MatchDetailsScreen has cancel support"  || fail "Missing cancel support in MatchDetailsScreen"
  grep -q "events\|Timeline\|AdminMatchEvent"      "$MD" && pass "MatchDetailsScreen shows event timeline" || fail "Missing events timeline in MatchDetailsScreen"
  grep -q "showDialog\|confirm"                    "$MD" && pass "MatchDetailsScreen has confirmation dialog" || fail "Missing confirmation dialog in MatchDetailsScreen"
else
  fail "Missing screen file: match_details_screen.dart"
fi

ADMIN_SCR="$REPO_ROOT/mobile/lib/features/admin/screens/admin_screen.dart"
if [[ -f "$ADMIN_SCR" ]]; then
  grep -q "Matches\|match_monitor\|MatchMonitor" "$ADMIN_SCR" \
    && pass "AdminScreen includes Matches tab" || fail "Missing Matches tab in AdminScreen"
else
  fail "admin_screen.dart not found"
fi

# ─── TypeScript compilation ───────────────────────────────────────────────────

section "TypeScript compilation"

cd "$REPO_ROOT"
if pnpm --filter @workspace/backend run typecheck > /dev/null 2>&1; then
  pass "TypeScript compilation succeeded"
else
  fail "TypeScript compilation failed"
fi

# ─── Phase 10.1 + 10.2 regression (file-existence sub-check) ─────────────────

section "Phase 10.1 regression — still present"

PHASE101_FILES=(
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
for f in "${PHASE101_FILES[@]}"; do
  [[ -f "$REPO_ROOT/$f" ]] \
    && pass "10.1 regression — still present: $f" \
    || fail "10.1 regression — MISSING: $f"
done

section "Phase 10.2 regression — routes still present"

grep -q "ban"             "$ROUTES" && pass "10.2 regression — ban route present"       || fail "10.2 regression — ban route missing"
grep -q "unban"           "$ROUTES" && pass "10.2 regression — unban route present"     || fail "10.2 regression — unban route missing"
grep -q "promote"         "$ROUTES" && pass "10.2 regression — promote route present"   || fail "10.2 regression — promote route missing"
grep -q "demote"          "$ROUTES" && pass "10.2 regression — demote route present"    || fail "10.2 regression — demote route missing"
grep -q "audit-log"       "$ROUTES" && pass "10.2 regression — audit-log route present" || fail "10.2 regression — audit-log route missing"

# ─── Live HTTP checks ─────────────────────────────────────────────────────────

section "Live HTTP checks (require running backend at $BASE_URL)"

if curl -s --max-time 3 "$BASE_URL/admin/stats" > /dev/null 2>&1 ||
   curl -s --max-time 3 "$BASE_URL/admin/matches" > /dev/null 2>&1; then

  if [[ -n "${NON_ADMIN_TOKEN:-}" ]]; then
    # Route protection
    STATUS=$(http_status -X GET "$BASE_URL/admin/matches" \
      -H "Authorization: Bearer $NON_ADMIN_TOKEN")
    [[ "$STATUS" == "403" ]] \
      && pass "GET /admin/matches without admin → 403" \
      || fail "GET /admin/matches without admin expected 403, got $STATUS"

    STATUS=$(http_status -X POST \
      "$BASE_URL/admin/matches/00000000-0000-4000-8000-000000000000/cancel" \
      -H "Authorization: Bearer $NON_ADMIN_TOKEN" \
      -H "Content-Type: application/json")
    [[ "$STATUS" == "403" ]] \
      && pass "POST /admin/matches/:id/cancel without admin → 403" \
      || fail "POST /admin/matches/:id/cancel without admin expected 403, got $STATUS"
  else
    yellow "  ⚠ NON_ADMIN_TOKEN not set — skipping route-protection checks"
  fi

  if [[ -n "${ADMIN_TOKEN:-}" ]]; then
    # List matches
    BODY=$(http_body -X GET "$BASE_URL/admin/matches?limit=5" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    echo "$BODY" | grep -q '"matches"' \
      && pass "GET /admin/matches → matches array present" \
      || fail "GET /admin/matches missing matches array"
    echo "$BODY" | grep -q '"pagination"' \
      && pass "GET /admin/matches → pagination present" \
      || fail "GET /admin/matches missing pagination"

    # Status filter validation
    STATUS=$(http_status -X GET "$BASE_URL/admin/matches?status=invalid" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "400" ]] \
      && pass "GET /admin/matches?status=invalid → 400" \
      || fail "GET /admin/matches?status=invalid expected 400, got $STATUS"

    # Status filters
    for S in waiting in_progress finished cancelled; do
      STATUS=$(http_status -X GET "$BASE_URL/admin/matches?status=$S" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      [[ "$STATUS" == "200" ]] \
        && pass "GET /admin/matches?status=$S → 200" \
        || fail "GET /admin/matches?status=$S expected 200, got $STATUS"
    done

    # Search
    STATUS=$(http_status -X GET "$BASE_URL/admin/matches?search=ABC" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "200" ]] \
      && pass "GET /admin/matches?search=ABC → 200" \
      || fail "GET /admin/matches?search=ABC expected 200, got $STATUS"

    # Pagination
    STATUS=$(http_status -X GET "$BASE_URL/admin/matches?limit=5&offset=0" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "200" ]] \
      && pass "GET /admin/matches?limit=5&offset=0 → 200" \
      || fail "GET /admin/matches?limit=5&offset=0 expected 200, got $STATUS"

    FAKE_UUID="00000000-0000-4000-8000-000000000000"

    # Non-existent match → 404
    STATUS=$(http_status -X GET "$BASE_URL/admin/matches/$FAKE_UUID" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "404" ]] \
      && pass "GET /admin/matches/nonexistent → 404" \
      || fail "GET /admin/matches/nonexistent expected 404, got $STATUS"

    STATUS=$(http_status -X GET "$BASE_URL/admin/matches/$FAKE_UUID/events" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "404" ]] \
      && pass "GET /admin/matches/nonexistent/events → 404" \
      || fail "GET /admin/matches/nonexistent/events expected 404, got $STATUS"

    # Cancel non-existent match → 404
    STATUS=$(http_status -X POST "$BASE_URL/admin/matches/$FAKE_UUID/cancel" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json")
    [[ "$STATUS" == "404" ]] \
      && pass "POST /admin/matches/nonexistent/cancel → 404" \
      || fail "POST /admin/matches/nonexistent/cancel expected 404, got $STATUS"

    # Invalid UUID → 400
    STATUS=$(http_status -X GET "$BASE_URL/admin/matches/not-a-uuid" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "400" ]] \
      && pass "GET /admin/matches/not-a-uuid → 400" \
      || fail "GET /admin/matches/not-a-uuid expected 400, got $STATUS"

    if [[ -n "${TEST_MATCH_UUID:-}" ]]; then
      # Detail endpoint
      BODY=$(http_body -X GET "$BASE_URL/admin/matches/$TEST_MATCH_UUID" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      echo "$BODY" | grep -q '"match"' \
        && pass "GET /admin/matches/:id → match object present" \
        || fail "GET /admin/matches/:id missing match object"

      # Events endpoint
      BODY=$(http_body -X GET "$BASE_URL/admin/matches/$TEST_MATCH_UUID/events" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
      echo "$BODY" | grep -q '"events"' \
        && pass "GET /admin/matches/:id/events → events array present" \
        || fail "GET /admin/matches/:id/events missing events array"
    else
      yellow "  ⚠ TEST_MATCH_UUID not set — skipping detail/events/cancel live tests"
    fi

    # Audit log still works (10.2 regression)
    STATUS=$(http_status -X GET "$BASE_URL/admin/audit-log?limit=5" \
      -H "Authorization: Bearer $ADMIN_TOKEN")
    [[ "$STATUS" == "200" ]] \
      && pass "10.2 regression — GET /admin/audit-log → 200" \
      || fail "10.2 regression — GET /admin/audit-log failed"

  else
    yellow "  ⚠ ADMIN_TOKEN not set — skipping admin-authenticated live checks"
  fi

else
  yellow "  ⚠ Backend not reachable at $BASE_URL — skipping live checks"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo
echo "──────────────────────────────────────────────────────────────"
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
