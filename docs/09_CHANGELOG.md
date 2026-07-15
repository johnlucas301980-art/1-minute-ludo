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

## Unreleased

### Date

In Progress

### Author

Replit Agent

### Summary

Phase 2.2–2.5 — Register, Login, JWT Authentication, Flutter Auth Layer

### Details

**Backend (Phase 2.2–2.4)**
-   Added POST /api/auth/register — bcrypt password hashing, duplicate detection
-   Added POST /api/auth/login — returns access_token + refresh_token + profile
-   Added POST /api/auth/refresh — issues new access token from valid refresh token
-   Added POST /api/auth/logout — single device (by jti) or all devices
-   JWT Access Token: 15 min expiry, signed with JWT_ACCESS_SECRET
-   JWT Refresh Token: 30 day expiry, signed with JWT_REFRESH_SECRET; only jti stored in DB
-   New `refresh_tokens` table (migration 0002): jti, user_id, expires_at, created_at
-   New `authenticate` middleware: reads Bearer token, verifies, attaches req.user
-   Revoked tokens rejected via jti DB lookup; tampered/expired tokens rejected by JWT verify
-   password_hash never exposed in any response

**Flutter (Phase 2.5)**
-   `TokenStorage` — flutter_secure_storage wrapper (Android Keystore / iOS Keychain); keys never logged
-   `ApiClient` — HTTP client with auto-refresh interceptor; retries original request exactly once after a successful refresh; throws `SessionExpiredException` and clears tokens when refresh fails
-   `AuthService` — register, login, logout (single device or all devices), isLoggedIn; constructor DI, no singletons
-   `AuthTokens` / `UserProfile` — Dart models with `fromJson`; password_hash never stored
-   `AppConfig` updated — Development / Production environment split; no hardcoded ports
-   Error hierarchy: `ApiException`, `SessionExpiredException`, `AccountForbiddenException`
-   23 unit tests (TokenStorage, ApiClient, AuthService) — `flutter analyze` clean, all pass

### Notes

Google Sign In and Country Detection deferred to future phases.
UI screens (login, register) deferred to Phase 2.6+.

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
