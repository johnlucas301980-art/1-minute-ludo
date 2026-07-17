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
