# 09_CHANGELOG.md

# CHANGELOG

All significant changes to this project must be recorded here.

------------------------------------------------------------------------

## Versioning

Format:

-   Version
-   Date
-   Author (AI or Developer)
-   Summary
-   Details

------------------------------------------------------------------------

## v2.0.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 4.1 complete — Wallet Backend Foundation (GET /api/wallet, GET /api/wallet/history)

### Details

**Database — new migrations**
-   `backend/src/db/migrations/0004_create_wallets_table.sql` — wallets table: UUID PK, user_id FK UNIQUE with CASCADE, points/total_deposit/total_withdraw NUMERIC(18,2) DEFAULT 0 CHECK >= 0, updated_at maintained by the existing set_updated_at() trigger
-   `backend/src/db/migrations/0005_create_transactions_table.sql` — transactions table: UUID PK, user_id FK, type CHECK IN (deposit/withdraw/reward/entry_fee/refund), amount NUMERIC(18,2), status CHECK IN (pending/completed/failed/reversed) DEFAULT 'completed', reference TEXT, created_at; compound index on (user_id, created_at DESC) for efficient history queries
-   `backend/src/db/migrations/0006_backfill_wallets_for_existing_users.sql` — INSERT … ON CONFLICT DO NOTHING to create zero-balance wallets for all users registered before Phase 4.1

**Backend — new files**
-   `backend/src/services/wallet.service.ts` — `findWalletByUserId()`, `findOrCreateWallet()` (atomic INSERT … ON CONFLICT DO UPDATE upsert that always returns the row), `getTransactions()` (paginated, newest first)
-   `backend/src/controllers/wallet.controller.ts` — `getWallet()` (auto-creates wallet on first access via findOrCreateWallet); `getWalletHistory()` (parses and clamps limit 1–100 default 20 and offset ≥0 default 0; returns transactions array + pagination envelope)
-   `backend/src/routes/wallet.ts` — GET /wallet and GET /wallet/history, both behind authenticate middleware
-   `backend/tests/phase41_wallet.sh` — 31-assertion integration test suite covering: auth protection on both endpoints, wallet initial state (0 points, all fields present, user_id not exposed), wallet idempotency (same id on repeated calls), empty history for new user, pagination params (custom limit, offset, limit clamped at 100, non-numeric falls back to default, negative offset falls back to 0)

**Backend — modified files**
-   `backend/src/routes/index.ts` — walletRouter imported and mounted

**No Flutter changes** — Flutter wallet service layer is a future phase.

**No new architecture** — follows existing controller/service/route separation.

**Design decisions**
-   `findOrCreateWallet` uses `INSERT … ON CONFLICT (user_id) DO UPDATE SET updated_at = wallets.updated_at RETURNING *` so the row is always returned atomically, safe under concurrent requests, with no separate SELECT needed.
-   NUMERIC columns from pg arrive as strings; controller converts with `parseFloat()` before serialising to JSON so clients receive numbers, not strings.
-   History endpoint silently clamps out-of-range pagination params rather than returning 400, consistent with read-only query patterns where clamping is safer than erroring.
-   Transactions table is append-only (no UPDATE/DELETE in schema or service layer) — financial audit trail is preserved by design.

**Verified (Node.js 20 / Express 5)**
-   Migrations 0004–0006 applied ✅
-   pnpm run build — zero TypeScript errors ✅
-   31/31 Phase 4.1 tests pass ✅
-   35/35 Phase 3.1 tests pass (no regressions) ✅
-   25/25 Phase 3.3 tests pass (no regressions) ✅
-   21/21 Phase 3.6 tests pass (no regressions) ✅

------------------------------------------------------------------------

## v1.9.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3.6 complete — Backend Avatar Upload Endpoint (PUT /api/profile/avatar)

### Details

**Backend — new files**
-   `backend/src/lib/upload.ts` — multer disk-storage configuration: AVATARS_DIR at `backend/uploads/avatars/`, filename = `<user-id>.<ext>`, fileFilter accepts only `image/jpeg` / `image/png` / `image/webp` (others rejected with coded `INVALID_MIME_TYPE` error), 2 MB size limit; exports `avatarUpload` instance, `AVATARS_DIR` constant, and `MIME_TO_EXT` map used by the controller for stale-file cleanup
-   `backend/tests/phase36_avatar_upload.sh` — 21-assertion integration test suite covering: auth protection (no token, invalid token), validation (no file, disallowed MIME type, file > 2 MB), successful JPEG/PNG/WEBP uploads, GET /profile reflects new avatar URL, static file served at returned URL, second upload replaces first (stale extension cleaned up)
-   `backend/uploads/avatars/.gitkeep` — ensures the uploads directory is tracked in git while binary assets are excluded

**Backend — modified files**
-   `backend/src/app.ts` — added `express.static` for `/uploads` pointing to `backend/uploads/` (resolved relative to bundle output in `dist/`); mounted before the API router
-   `backend/src/controllers/profile.controller.ts` — added `uploadAvatar()` handler: confirms file present, removes stale avatar files with other extensions via `fs.unlink`, constructs public URL from `req.protocol + req.get('host')`, calls `updateProfileById` to persist URL, returns `{ success: true, data: { avatar } }`
-   `backend/src/routes/profile.ts` — added `handleAvatarUpload` wrapper function that runs `avatarUpload.single('avatar')` and converts `MulterError(LIMIT_FILE_SIZE)` → 400 and `INVALID_MIME_TYPE` error → 400 before calling `uploadAvatar`; added `router.put('/profile/avatar', authenticate, handleAvatarUpload, uploadAvatar)`
-   `backend/package.json` — added `multer ^2.2.0` and `@types/multer ^2.2.0`
-   `.gitignore` — added `backend/uploads/avatars/*` / `!backend/uploads/avatars/.gitkeep` to exclude binary uploads from version control

**No Flutter changes** — Flutter service layer is Phase 3.7.

**No database changes** — `avatar TEXT` column already exists in users table from migration 0001.

**Design decisions**
-   Filename strategy `<user-id>.<ext>` ensures one file per user per extension; stale extension cleanup in the controller handles cross-format replacements (e.g. JPEG → PNG) without leaving orphaned files.
-   `AVATARS_DIR` uses `path.resolve(__dirname, '../uploads/avatars')` (one level up from `dist/`) rather than two, because esbuild bundles all source files into `dist/index.mjs`; `import.meta.url` therefore always resolves relative to the bundle output, not the original source path.
-   Multer error handling wrapped in `handleAvatarUpload` in the route file (not the controller) to keep the controller focused on business logic; the route layer owns transport-level concerns.

**Verified (Node.js 20 / Express 5)**
-   pnpm run build — no TypeScript errors ✅
-   21/21 integration tests pass ✅

------------------------------------------------------------------------

## v1.8.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3.5 complete — Flutter Profile Screen UI (Profile Screen + Edit Profile Sheet + Change Password Sheet)

### Details

**Mobile — new production files**
-   `mobile/lib/features/profile/widgets/profile_avatar.dart` — circular avatar widget with gold-gradient ring and box-shadow; falls back to player-initials monogram when no avatar URL is set
-   `mobile/lib/features/profile/widgets/profile_info_tile.dart` — icon + label + value row used inside the profile info card
-   `mobile/lib/features/profile/widgets/profile_status_badge.dart` — colour-coded pill badge: green (active), amber (suspended), red (banned)
-   `mobile/lib/features/profile/widgets/edit_profile_sheet.dart` — modal bottom sheet; edits fullName / country / avatar URL via `ProfileService.updateProfile`; calls `onSuccess(UserProfile)` callback on successful save so the parent screen updates without a second network call
-   `mobile/lib/features/profile/widgets/change_password_sheet.dart` — modal bottom sheet; calls `ChangePasswordService.changePassword`; maps `WrongCurrentPasswordException` to an inline field validation error so the sheet stays open and the player's session is preserved
-   `mobile/lib/features/profile/screens/profile_screen.dart` — stateful screen with loading / error / data states; `RefreshIndicator` for pull-to-refresh; `AnimatedSwitcher` transitions between states; Edit Profile and Change Password action buttons open their respective sheets; receives updated `UserProfile` from the Edit Profile sheet to refresh the display without a second network round-trip

**Mobile — new test file**
-   `mobile/test/features/profile/profile_screen_test.dart` — 10 widget tests using fake service subclasses (no platform-channel dependencies) covering: smoke render, loading indicator, profile data display, error state, retry flow, Edit Profile sheet opens, Change Password sheet opens, pull-to-refresh, edit sheet saves and updates screen, wrong-password inline error keeps sheet open

**Mobile — modified files**
-   `mobile/lib/features/profile/screens/profile_screen.dart` — `_PrimaryButton` and `_SecondaryButton` private widgets accept `super.key`; Edit Profile and Change Password buttons tagged with `Key('edit_profile_button')` and `Key('change_password_button')` for reliable widget-test targeting

**No backend changes** — Phase 3.3 endpoints (GET /api/profile, PUT /api/profile, PUT /api/profile/password) reused as-is.

**No database changes** — no new migrations.

**Design decisions**
-   `WrongCurrentPasswordException` mapped to inline field error (not session expiry): consistent with Phase 3.4 service-layer design; the player stays logged in and can correct the mistake without re-authentication.
-   Widget tests use fake `ProfileService` / `ChangePasswordService` subclasses that override service methods directly, eliminating MethodChannel (FlutterSecureStorage) timing dependencies that prevent reliable async flushing in `testWidgets`.
-   Buttons are tagged with widget keys (`Key('edit_profile_button')`, `Key('change_password_button')`) because `OutlinedButton.icon()` returns `_OutlinedButtonWithIcon` (internal Flutter type) which does not always match `find.widgetWithText(OutlinedButton, ...)` across Flutter versions.

**Verified (Flutter 3.32.0)**
-   flutter analyze — no issues ✅
-   10/10 new widget tests pass ✅
-   59/59 total Flutter tests pass (no regressions) ✅

------------------------------------------------------------------------

## v1.7.0

### Date

2026-07-18

### Author

Replit Agent

### Summary

Phase 3.4 complete — Flutter Change Password Service Layer

### Details

**Mobile — new files**
-   `mobile/lib/features/profile/services/change_password_service.dart` — `ChangePasswordService` with `changePassword(currentPassword, newPassword)` → `Future<void>`; wraps PUT /api/profile/password; maps "Current password is incorrect" 401 to `WrongCurrentPasswordException`; passes `domainRejectionPattern` to prevent wrong-password 401s from clearing tokens
-   `mobile/test/features/profile/change_password_service_test.dart` — 11 unit tests covering: successful change, correct request body shape, token refresh + retry, wrong password (WrongCurrentPasswordException), validation failure (ApiException 400), server error (ApiException 500), no token (SessionExpiredException), both tokens expired (SessionExpiredException), network timeout

**Mobile — modified files**
-   `mobile/lib/core/errors/api_exception.dart` — added `WrongCurrentPasswordException extends ApiException`; thrown when the backend rejects the current password with 401; tokens are NOT cleared; the session remains active
-   `mobile/lib/core/network/api_client.dart` — added optional `domainRejectionPattern` parameter to `authenticatedRequest`; when a 401 body message contains the pattern the response is decoded as `ApiException` directly (no refresh, no token clearing); the JSON parsing is isolated in its own try-catch so the resulting `ApiException` propagates correctly; fully backward-compatible — all existing callers pass `null` implicitly and are unaffected

**No backend changes** — Phase 3.3 endpoint (PUT /api/profile/password) reused as-is.

**No database changes** — no new migrations.

**Design decision: domainRejectionPattern vs bypassRefreshOn401**
An earlier approach using `bypassRefreshOn401: true` was rejected because it blindly blocked token refresh for ALL 401s on the endpoint, including genuine token-expiry 401s. The `domainRejectionPattern` approach inspects the 401 response body: if the message matches the pattern it is a domain rejection; if not, the normal refresh/retry flow proceeds. This correctly handles both "wrong password" (no refresh, no token clearing) and "expired access token" (refresh → retry) on the same endpoint.

**Verified (Flutter 3.32.0)**
-   flutter analyze — no issues ✅
-   11/11 new tests pass ✅
-   49/49 total Flutter tests pass (no regressions in ApiClient, TokenStorage, AuthService, ProfileService, or widget tests) ✅

------------------------------------------------------------------------

## v1.6.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 3.3 complete — Change Password endpoint (PUT /api/profile/password)

### Details

**Backend — new files**
-   `backend/tests/phase33_change_password.sh` — 25-assertion integration test suite covering all validation paths, wrong-password rejection, auth protection, successful change, and post-change verification (new password accepted, old password rejected, old refresh token revoked)

**Backend — modified files**
-   `backend/src/services/user.service.ts` — added `updatePasswordById(id, newPasswordHash)`: issues `UPDATE users SET password_hash = $1 WHERE id = $2`, returns boolean indicating whether a row was updated
-   `backend/src/controllers/profile.controller.ts` — added `changePassword()` handler: extracts and validates fields, verifies current password via `bcrypt.compare`, hashes new password (cost 12), calls `updatePasswordById`, revokes all refresh tokens via `deleteRefreshTokensByUser`
-   `backend/src/routes/profile.ts` — added `router.put('/profile/password', authenticate, changePassword)`

**No Flutter changes** — Flutter service layer is Phase 3.4.

**No database changes** — `password_hash TEXT` column already exists in the users table (migration 0001).

**Verified flows (25/25 integration tests pass)**
-   PUT /profile/password empty body → 400 with errors array ✅
-   PUT /profile/password missing current_password → 400, error field = current_password ✅
-   PUT /profile/password missing new_password → 400, error field = new_password ✅
-   PUT /profile/password new_password < 8 chars → 400 ✅
-   PUT /profile/password new_password no letter → 400 ✅
-   PUT /profile/password new_password no digit → 400 ✅
-   PUT /profile/password new_password same as current → 400 ✅
-   PUT /profile/password wrong current_password → 401 "Current password is incorrect." ✅
-   PUT /profile/password no token → 401 ✅
-   PUT /profile/password invalid token → 401 ✅
-   PUT /profile/password valid change → 200, success + message ✅
-   Login with new password → 200 ✅
-   Login with old password → 401 ✅
-   Old refresh token after change → 401 (revoked) ✅

------------------------------------------------------------------------

## v1.5.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 3.2 complete — Flutter Profile Service Layer (getProfile, updateProfile)

### Details

**Flutter — modified files**
-   `mobile/lib/features/auth/models/user_profile.dart` — extended with optional `updatedAt` field (`updated_at` key); present on GET /profile and PUT /profile responses, null for auth responses; existing `fromJson` factory updated to parse it; no breaking changes to existing call sites

**Flutter — new files**
-   `mobile/lib/features/profile/services/profile_service.dart` — `ProfileService` with two methods:
    -   `getProfile()` — calls GET /api/profile, returns `UserProfile` (including `updatedAt`)
    -   `updateProfile({String? fullName, Object? country, Object? avatar})` — calls PUT /api/profile; partial update (only provided fields are sent); `country` and `avatar` accept explicit `null` to clear; throws `ArgumentError` if no fields are provided
    -   Uses private `_Absent` sentinel to distinguish "field not provided" from "explicit null" without boolean flags
-   `mobile/test/features/profile/profile_service_test.dart` — 15 unit tests covering:
    -   `getProfile` success (all fields including `updatedAt`) ✅
    -   `getProfile` 401 → `SessionExpiredException` ✅
    -   `getProfile` 500 → `ApiException` ✅
    -   Automatic token refresh after expired access token (401 → refresh → retry) ✅
    -   Network timeout / offline → throws `Exception` ✅
    -   `updateProfile` full_name update ✅
    -   `updateProfile` country update ✅
    -   `updateProfile` avatar URL update ✅
    -   `updateProfile` avatar cleared by passing null ✅
    -   `updateProfile` country cleared by passing null ✅
    -   `updateProfile` 400 validation error → `ApiException` ✅
    -   `updateProfile` 401 with failed refresh → `SessionExpiredException` ✅
    -   `updateProfile` no fields → `ArgumentError` ✅
    -   `UserProfile.fromJson` all fields parsed correctly including `updatedAt` ✅
    -   `UserProfile.fromJson` nullable fields without cast error ✅

**No backend changes** — Phase 3.1 backend is complete and untouched.

**No database changes** — no new migration required.

------------------------------------------------------------------------

## v1.4.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 3.1 complete — Player Profile Foundation (GET /profile, PUT /profile)

### Details

**Backend — new files**
-   `backend/src/services/profile.service.ts` — findProfileById, updateProfileById (dynamic SET clause, updated_at maintained by DB trigger)
-   `backend/src/controllers/profile.controller.ts` — getProfile, updateProfile (validation: empty body, full_name 2–120 chars, country ≤100 chars, avatar http/https URL or null)
-   `backend/src/routes/profile.ts` — GET /profile and PUT /profile, both behind authenticate middleware
-   `backend/tests/phase31_profile.sh` — 35-assertion test suite covering happy paths, field updates, null-clears, and all validation error cases

**Backend — modified files**
-   `backend/src/routes/index.ts` — mounts profileRouter at root (alongside existing auth/password-reset routers)

**Database**
-   No new migration required — all required columns (full_name, country, avatar, player_id, etc.) already exist in users table from migration 0001
-   Applied all 3 existing migrations (0001–0003) to Replit's built-in PostgreSQL for this environment

**Verified flows (curl + test suite — 35/35 pass)**
-   GET /profile with valid token → 200, profile object without password_hash ✅
-   GET /profile with no token → 401 ✅
-   GET /profile with invalid token → 401 ✅
-   PUT /profile full_name update → 200, GET reflects change ✅
-   PUT /profile country update → 200 ✅
-   PUT /profile avatar URL update → 200 ✅
-   PUT /profile avatar null (clear) → 200, avatar=null ✅
-   PUT /profile country null (clear) → 200, country=null ✅
-   PUT /profile empty body → 400 with errors array ✅
-   PUT /profile full_name < 2 chars → 400 ✅
-   PUT /profile invalid avatar URL → 400, error field = avatar ✅
-   PUT /profile no token → 401 ✅
-   GET /profile final state confirms all updates persisted ✅

------------------------------------------------------------------------

## v1.3.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 2.5.1 complete — Password Reset module (backend + Flutter service layer) verified end-to-end

### Details

**Database**
-   Applied migration 0003_create_password_reset_otps_table.sql — table live with indexes and FK cascade

**Backend — new files**
-   `backend/src/lib/otp.ts` — cryptographically random 6-digit OTP, SHA-256 hash, constant-time comparison
-   `backend/src/lib/email.ts` — Nodemailer SMTP; skips silently when SMTP env vars unset, warns at startup
-   `backend/src/services/password_reset.service.ts` — countRecentOtpRequests, createOtp, incrementLatestOtpAttempt, findOtpById, applyPasswordReset (transactional), deleteExpiredOtps
-   `backend/src/controllers/password_reset.controller.ts` — requestPasswordReset, verifyPasswordResetOtp, confirmPasswordReset
-   `backend/src/routes/password_reset.ts` — mounts three routes under /auth/password-reset/

**Backend — modified files**
-   `backend/src/config/env.ts` — JWT_PASSWORD_RESET_SECRET (required, throws), SMTP_* vars (optional, warns)
-   `backend/src/lib/jwt.ts` — PasswordResetTokenPayload, signPasswordResetToken, verifyPasswordResetToken (JWT_PASSWORD_RESET_SECRET)
-   `backend/src/routes/index.ts` — mounts passwordResetRouter at /auth
-   `backend/src/index.ts` — hourly setInterval for deleteExpiredOtps() with .unref()

**Flutter**
-   `mobile/lib/features/auth/services/password_reset_service.dart` — requestOtp, verifyOtp, confirmReset
-   `mobile/lib/core/errors/api_exception.dart` — OtpExpiredException subclass added

**Secrets**
-   JWT_PASSWORD_RESET_SECRET added to Replit secrets

**Verified flows (curl)**
-   Request OTP → confirm DB row created ✅
-   Wrong OTP → 400 "OTP is incorrect" ✅
-   Correct OTP → reset token issued with sub + otp_id payload ✅
-   Confirm with reset token → password updated, OTP marked used, all refresh tokens deleted ✅
-   Login with new password → succeeds ✅
-   Login with old password → rejected ✅
-   Old refresh token → rejected ✅
-   Reset token replay → "Reset session is no longer valid" ✅
-   Rate limit (3 OTPs/hour) → 429 on 4th request ✅

------------------------------------------------------------------------

## v1.2.0

### Date

2026-07-17

### Author

Replit Agent

### Summary

Phase 2.2–2.5 verified end-to-end on Replit — Authentication Module complete

### Details

**Database (Replit environment)**
-   Applied migration 0001_create_users_table.sql — users table live with all triggers and indexes
-   Applied migration 0002_create_refresh_tokens_table.sql — refresh_tokens table live
-   schema_migrations table tracking applied migrations

**End-to-End Verification (Replit)**
-   POST /api/auth/register — new user created, auto player_id (LUD-XXXXXX) generated ✅
-   POST /api/auth/login — access + refresh tokens returned, profile included ✅
-   POST /api/auth/refresh — new access token issued from valid refresh token ✅
-   POST /api/auth/logout — refresh token revoked on server ✅
-   Post-logout refresh attempt — correctly rejected with "Invalid or revoked refresh token." ✅

### Notes

Google Sign In and Country Detection deferred to future phases.
UI screens (login, register) are Phase 2.6 — pending owner approval to begin.

------------------------------------------------------------------------

## v1.1.0

### Date

2026-07-15

### Author

Replit Agent

### Summary

Phase 2.1 — Users Table (Database Foundation)

### Details

-   Added `users` table: id (UUID v4), player_id (LUD-XXXXXX, auto-generated), full_name, email, mobile, password_hash, google_id, country, avatar, is_verified, status, last_login_at, created_at, updated_at
-   Added SQL migration `backend/src/db/migrations/0001_create_users_table.sql`
-   Added migration runner `backend/src/db/migrate.ts` (`pnpm --filter @workspace/backend run migrate`)
-   Added partial unique indexes on email, mobile, google_id; indexes on status and created_at
-   Added trigger to auto-generate `player_id` on insert
-   Added trigger to auto-update `updated_at` on update
-   Verified migration runs successfully against PostgreSQL

### Notes

No authentication logic (register/login/JWT) or Flutter changes included — deferred to Phase 2.2.

------------------------------------------------------------------------

## v1.0.0

### Date

2026-07-14

### Author

Replit Agent + ChatGPT

### Summary

Project Foundation Completed

### Details

-   Initial Flutter project structure
-   Initial Backend structure
-   Express server
-   PostgreSQL configuration
-   Socket.IO foundation
-   GitHub repository connected
-   Documentation started

------------------------------------------------------------------------

## Future Entries

### Template

Version:

Date:

Author:

Summary:

Changes:

-   Added
-   Updated
-   Fixed
-   Removed

Notes:

------------------------------------------------------------------------

# Rules

-   Update this file after every completed feature.
-   Never remove old entries.
-   Add newest entries at the top.
-   Keep version numbers consistent.
-   Mention breaking changes clearly.

------------------------------------------------------------------------

# Example

## v1.1.0

Date: YYYY-MM-DD

Author: Developer / AI

Summary: Authentication System

Changes:

-   Added login
-   Added register
-   Added JWT
-   Added password reset

Notes:

Ready for Phase 3.
