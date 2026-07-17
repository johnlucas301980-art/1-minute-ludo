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
