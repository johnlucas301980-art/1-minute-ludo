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

Phase 2.2 & 2.3 — Register API + Login API

### Details

-   Added POST /api/auth/register endpoint
-   Added POST /api/auth/login endpoint (email or mobile identifier)
-   Password verified with bcrypt.compare() — plaintext never stored or returned
-   Login rejects suspended (403) and banned (403) accounts with distinct messages
-   Unknown account and wrong password both return 401 "Invalid credentials." (no account enumeration)
-   last_login_at stamped on every successful login (hard error on failure)
-   Response includes: id, player_id, full_name, email, mobile, country, avatar, status, created_at
-   password_hash never exposed in any response
-   Added `findByEmailOrMobile`, `updateLastLogin` to `src/services/user.service.ts`

### Notes

JWT, Refresh Token, Google Sign In deferred to Phase 2.4+.

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
