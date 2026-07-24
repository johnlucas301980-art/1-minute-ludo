#!/usr/bin/env bash
# Phase 10.4 — Admin wallet monitoring, reports, and settings smoke checks.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ✓ %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  ✗ %s\n' "$1"; }
check_file() {
  if [[ -f "$ROOT/$1" ]]; then pass "Exists: $1"; else fail "Missing: $1"; fi
}
check_contains() {
  if grep -q "$2" "$ROOT/$1"; then pass "$3"; else fail "$3"; fi
}

for file in \
  backend/src/db/migrations/0016_create_settings_table.sql \
  backend/src/services/admin.service.ts \
  backend/src/controllers/admin.controller.ts \
  backend/src/routes/admin.ts \
  backend/tests/phase104_admin_operations.sh; do
  check_file "$file"
done

check_contains backend/src/db/migrations/0016_create_settings_table.sql "CREATE TABLE IF NOT EXISTS settings" "Settings table migration exists"
check_contains backend/src/db/migrations/0016_create_settings_table.sql "UNIQUE" "Settings keys are unique"

check_contains backend/src/routes/admin.ts "admin/wallets" "Wallet monitoring routes registered"
check_contains backend/src/routes/admin.ts "admin/reports" "Reports route registered"
check_contains backend/src/routes/admin.ts "admin/settings" "Settings routes registered"
check_contains backend/src/routes/admin.ts "listWalletsHandler" "Wallet monitoring handler imported"
check_contains backend/src/routes/admin.ts "getReportHandler" "Reports handler imported"
check_contains backend/src/routes/admin.ts "updateSettingHandler" "Settings handler imported"

check_contains backend/src/services/admin.service.ts "export async function listWallets" "Wallet list service exists"
check_contains backend/src/services/admin.service.ts "export async function listWalletTransactions" "Wallet transaction service exists"
check_contains backend/src/services/admin.service.ts "export async function getAdminReport" "Report service exists"
check_contains backend/src/services/admin.service.ts "export async function listSettings" "Settings list service exists"
check_contains backend/src/services/admin.service.ts "export async function updateSetting" "Settings update service exists"

check_contains backend/src/controllers/admin.controller.ts "export async function listWalletsHandler" "Wallet list controller exists"
check_contains backend/src/controllers/admin.controller.ts "export async function getReportHandler" "Report controller exists"
check_contains backend/src/controllers/admin.controller.ts "export async function listSettingsHandler" "Settings list controller exists"
check_contains backend/src/controllers/admin.controller.ts "export async function updateSettingHandler" "Settings update controller exists"
check_contains backend/src/controllers/admin.controller.ts "REPORT_DATE_PATTERN" "Report date validation exists"

if [[ "$FAIL" -gt 0 ]]; then
  printf '\nFailed: %s\n' "$FAIL"
  exit 1
fi
printf '\nPassed: %s\n' "$PASS"