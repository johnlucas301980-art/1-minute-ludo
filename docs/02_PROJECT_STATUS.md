# PROJECT STATUS

> This file tracks the current development progress of the project.
> Every AI or developer must read this file before starting any new
> work.

------------------------------------------------------------------------

# Project

**Name:** 1 Minute Ludo

**Status:** Active Development

**Platform:** Flutter (Android)

**Backend:** Node.js + Express

**Database:** PostgreSQL

**Realtime:** Socket.IO

------------------------------------------------------------------------

# Current Version

v0.9.0

# Current Phase

✅ Phase 4.3 - Flutter Wallet Screen UI Completed (2026-07-18)

# Completed

-   [x] GitHub Repository Created
-   [x] GitHub Connected
-   [x] Mobile Project Created
-   [x] Backend Project Created
-   [x] PostgreSQL Connected
-   [x] Socket.IO Initialized
-   [x] Environment Configuration
-   [x] Documentation Folder Created
-   [x] Initial Project Structure Completed

# Documentation Completed

-   [x] Architecture
-   [x] Database Design
-   [x] REST API Design
-   [x] Socket Events
-   [x] Deployment Guide

# Phase 2 - Authentication

Status: ✅ Completed (core module — 2026-07-17)

## Phase 2.1 - Users Table (Database Foundation)

Status: ✅ Completed (2026-07-15)

-   [x] users table created (UUID v4 primary key)
-   [x] Auto-generated Player ID (LUD-XXXXXX)
-   [x] Indexes and constraints
-   [x] Automatic updated_at trigger
-   [x] SQL migration created and verified against PostgreSQL

## Phase 2.2–2.5 - Authentication Logic

Status: ✅ Completed (2026-07-17)

-   [x] Register API (POST /api/auth/register)
-   [x] Password hashing (bcrypt, cost factor 12)
-   [x] Login API (POST /api/auth/login) — returns access + refresh tokens
-   [x] JWT Access Token (15 min, HS256)
-   [x] JWT Refresh Token (30 days, separate secret, jti stored in DB)
-   [x] POST /api/auth/refresh — issues new access token
-   [x] POST /api/auth/logout — single device or all devices
-   [x] authenticate middleware — protects future routes via Bearer token
-   [x] Flutter: TokenStorage (flutter_secure_storage — Android Keystore / iOS Keychain)
-   [x] Flutter: ApiClient with auto-refresh interceptor (one retry, no infinite loops)
-   [x] Flutter: AuthService — register, login, logout, isLoggedIn (constructor DI)
-   [x] Flutter: AuthTokens + UserProfile models (fromJson, no password_hash)
-   [x] Flutter: AppConfig with Development / Production environment split
-   [x] Flutter: 23 unit tests — flutter analyze clean, all tests pass
-   [x] Database migrations applied and verified on Replit (users + refresh_tokens tables)
-   [x] End-to-end auth flow verified on Replit: register → login → refresh → logout → revocation confirmed
-   [ ] Google Sign In (deferred to future phase)
-   [ ] Country Detection (deferred to future phase)

## Phase 2.5.1 - Password Reset (Backend + Flutter Service Layer)

Status: ✅ Completed (2026-07-17)

-   [x] Migration 0003: password_reset_otps table (id, user_id FK, otp_hash, expires_at, attempts, used_at, created_at)
-   [x] OTP library: cryptographically random 6-digit OTP, SHA-256 hash, constant-time comparison (timingSafeEqual)
-   [x] Email library: Nodemailer, provider-agnostic (any SMTP); server starts and warns if unconfigured
-   [x] JWT_PASSWORD_RESET_SECRET: separate secret, separate sign/verify functions, prevents token type confusion
-   [x] POST /api/auth/password-reset/request — rate-limited (max 3/hour), account enumeration-safe response
-   [x] POST /api/auth/password-reset/verify — atomic attempt tracking (UPDATE…RETURNING), max 5 attempts
-   [x] POST /api/auth/password-reset/confirm — validates reset JWT + OTP session, updates password, revokes all refresh tokens atomically
-   [x] Hourly cleanup interval for expired OTP rows (.unref() for clean process exit)
-   [x] Flutter: PasswordResetService — requestOtp, verifyOtp, confirmReset; OtpExpiredException subclass
-   [x] End-to-end verified on Replit: request → verify → confirm → new-password login → old refresh token rejected → reset token replay rejected → rate limit enforced

## Phase 2.6 - Flutter Auth UI Screens

Status: ⏳ Pending approval to begin

## Phase 3.1 - Player Profile Foundation

Status: ✅ Completed (2026-07-17)

-   [x] GET /api/profile — returns authenticated player's profile (no password_hash, no google_id)
-   [x] PUT /api/profile — updates mutable fields: full_name, country, avatar (URL or null)
-   [x] authenticate middleware applied to both endpoints
-   [x] Input validation: empty body → 400, full_name length (2–120), country length (≤100), avatar must be http/https URL or null
-   [x] Dynamic SET clause — only provided fields are updated; updated_at maintained by DB trigger
-   [x] 35/35 API tests pass (backend/tests/phase31_profile.sh)
-   [x] No new migration required — users table already contains all required columns

## Phase 3.2 - Flutter Profile Service Layer

Status: ✅ Completed (2026-07-17)

-   [x] UserProfile model extended with optional updatedAt field (updated_at from GET /profile and PUT /profile responses)
-   [x] ProfileService — getProfile() → GET /api/profile → UserProfile
-   [x] ProfileService — updateProfile() → PUT /api/profile (partial update; null clears nullable fields; ArgumentError if no fields given)
-   [x] Constructor-injected ApiClient — no singletons; same pattern as AuthService
-   [x] Automatic token refresh handled by ApiClient (transparent to ProfileService)
-   [x] 15 unit tests written (mobile/test/features/profile/profile_service_test.dart) covering happy paths, error states, token refresh, and network timeout
-   [x] No backend changes — Phase 3.1 backend untouched
-   [x] No new migration required

## Phase 3.3 - Change Password Endpoint

Status: ✅ Completed (2026-07-17)

-   [x] PUT /api/profile/password — authenticated endpoint to change the current player's password
-   [x] Verifies current password via bcrypt.compare before accepting any change
-   [x] New password hashed with bcrypt cost factor 12 (consistent with registration)
-   [x] Validates: current_password required; new_password required, ≥8 chars, ≥1 letter, ≥1 digit, must differ from current
-   [x] Revokes all refresh tokens after successful change (deleteRefreshTokensByUser) — same security posture as password reset
-   [x] authenticate middleware applied — Bearer token required
-   [x] updatePasswordById() added to user.service.ts
-   [x] No new database migration required — password_hash column already exists
-   [x] 25/25 integration tests pass (backend/tests/phase33_change_password.sh)
-   [x] No Flutter changes — Phase 3.4 (ChangePasswordService) is the Flutter layer

## Phase 3.4 - Flutter Change Password Service Layer

Status: ✅ Completed (2026-07-18)

-   [x] WrongCurrentPasswordException added to core/errors/api_exception.dart — typed exception for wrong-password 401 that does NOT clear the player's tokens or end the session
-   [x] ApiClient.authenticatedRequest extended with optional domainRejectionPattern parameter — peeks at the 401 response body and surfaces domain-level rejections directly without attempting a refresh; fully backward-compatible (all existing callers unchanged)
-   [x] ChangePasswordService — changePassword(currentPassword, newPassword) → Future<void>; wraps PUT /api/profile/password via authenticatedRequest; maps "Current password is incorrect" 401 to WrongCurrentPasswordException
-   [x] Constructor-injected ApiClient — no singletons; same pattern as ProfileService and PasswordResetService
-   [x] No client-side field validation — backend is the single source of truth; 400 errors surface as ApiException(400)
-   [x] No new backend changes — Phase 3.3 endpoint reused as-is
-   [x] No new database migration required
-   [x] 11/11 unit tests pass (mobile/test/features/profile/change_password_service_test.dart)
-   [x] 49/49 total Flutter tests pass — no regressions in ApiClient, TokenStorage, AuthService, ProfileService, or widget tests
-   [x] flutter analyze clean — no issues

## Phase 4.3 - Flutter Wallet Screen UI

Status: ✅ Completed (2026-07-18)

-   [x] WalletScreen — StatefulWidget with constructor-injected WalletService; no singletons
-   [x] Three UI states: loading (CircularProgressIndicator), error (icon + message + Retry button), data
-   [x] AnimatedSwitcher transitions between states (280 ms, matching ProfileScreen)
-   [x] RefreshIndicator (pull-to-refresh) reloads wallet and history in parallel via Future.wait
-   [x] _BalanceCard — gold-bordered gradient card showing points (large), TOTAL DEPOSITED (green), TOTAL WITHDRAWN (red)
-   [x] _TransactionTile — coloured icon circle, type label, formatted date, amount with +/- prefix, status pill
-   [x] Transaction type labels: Deposit / Withdrawal / Reward / Entry Fee / Refund
-   [x] Transaction status pills: Completed (green) / Pending (amber) / Failed (red) / Reversed (grey)
-   [x] _EmptyHistoryView — icon + message when no transactions exist
-   [x] No new dependencies added; no backend changes; no new database migration
-   [x] 10 widget tests (mobile/test/features/wallet/wallet_screen_test.dart) using fake WalletService subclasses — no platform-channel dependencies
-   [x] flutter analyze — no issues ✅
-   [x] flutter test — 90/90 passed (80 prior + 10 new, zero regressions) ✅

## Phase 4.2 - Flutter Wallet Service

Status: ✅ Completed (2026-07-18)

-   [x] Wallet model — immutable, `fromJson`, `num` → `double` coercion for all numeric fields
-   [x] WalletTransaction model — immutable, `fromJson`, nullable `reference`, `num` → `double` coercion
-   [x] WalletHistory model — in `wallet.dart`; wraps `transactions` + `pagination` envelope from GET /api/wallet/history; `total` maps to `pagination.count`
-   [x] WalletService — constructor-injected `ApiClient`, no singletons; `getWallet()`, `getHistory({limit, offset})`; query params appended to path string
-   [x] Error propagation identical to ProfileService: `ApiException`, `SessionExpiredException`, raw network exceptions all propagate unchanged
-   [x] No new dependencies added
-   [x] 21 new unit tests — covers success, 401 (expiry + refresh/retry), 500, malformed response, network failure, pagination param verification via request capture, default param verification
-   [x] flutter analyze — no issues
-   [x] flutter test — 80/80 passed (59 prior + 21 new, zero regressions)

## Phase 4.1 - Wallet Backend Foundation

Status: ✅ Completed (2026-07-18)

-   [x] Migration 0004: wallets table (id, user_id FK UNIQUE, points, total_deposit, total_withdraw, updated_at; CHECK points >= 0; auto updated_at trigger)
-   [x] Migration 0005: transactions table (id, user_id FK, type CHECK IN deposit/withdraw/reward/entry_fee/refund, amount, status CHECK IN pending/completed/failed/reversed, reference, created_at; compound index on user_id + created_at DESC)
-   [x] Migration 0006: backfill wallets for all existing users (INSERT … ON CONFLICT DO NOTHING)
-   [x] wallet.service.ts — findWalletByUserId(), findOrCreateWallet() (atomic upsert), getTransactions() (paginated, newest first)
-   [x] wallet.controller.ts — getWallet() auto-creates wallet on first access; getWalletHistory() with limit (1–100, default 20) and offset (≥0, default 0) clamping
-   [x] routes/wallet.ts — GET /wallet and GET /wallet/history, both behind authenticate middleware
-   [x] routes/index.ts — walletRouter mounted
-   [x] No balance modification logic, no deposit/withdraw endpoints, no payment gateway, no Socket.IO events
-   [x] 31/31 integration tests pass (backend/tests/phase41_wallet.sh)
-   [x] All prior backend tests still pass: 35/35 (phase31) + 25/25 (phase33) + 21/21 (phase36)
-   [x] pnpm run build — zero TypeScript errors

## Phase 3.6 - Backend Avatar Upload Endpoint

Status: ✅ Completed (2026-07-18)

-   [x] PUT /api/profile/avatar — multipart/form-data upload (field: avatar)
-   [x] Accepted MIME types: image/jpeg, image/png, image/webp (all others → 400)
-   [x] Maximum file size: 2 MB (exceeded → 400)
-   [x] Files stored as backend/uploads/avatars/<user-id>.<ext> — new upload replaces previous file
-   [x] Stale avatar files with other extensions removed automatically on replace
-   [x] Express static middleware serves uploads at /uploads/avatars/<filename>
-   [x] Public avatar URL (protocol + host + path) persisted to avatar column via updateProfileById
-   [x] authenticate middleware applied — Bearer token required
-   [x] multer added as backend dependency; AVATARS_DIR created at startup via fs.mkdirSync
-   [x] No new database migration required — avatar TEXT column already exists in users table
-   [x] 21/21 integration tests pass (backend/tests/phase36_avatar_upload.sh)
-   [x] pnpm run build passes — no TypeScript errors

## Phase 3.5 - Flutter Profile Screen UI

Status: ✅ Completed (2026-07-18)

-   [x] ProfileAvatar widget — circular avatar with gold-gradient ring; falls back to player initials
-   [x] ProfileInfoTile widget — icon + label + value row used inside the profile info card
-   [x] ProfileStatusBadge widget — colour-coded pill: green (active), amber (suspended), red (banned)
-   [x] EditProfileSheet — modal bottom sheet; edits fullName / country / avatar via ProfileService.updateProfile; calls onSuccess(UserProfile) to update the parent screen without a second network round-trip
-   [x] ChangePasswordSheet — modal bottom sheet; calls ChangePasswordService.changePassword; maps WrongCurrentPasswordException to inline field error (sheet stays open, session preserved)
-   [x] ProfileScreen — stateful screen: loading / error / data states; RefreshIndicator; AnimatedSwitcher; Edit Profile and Change Password action buttons with widget keys for testability
-   [x] 10 widget tests (mobile/test/features/profile/profile_screen_test.dart) using fake service subclasses — no platform-channel timing dependencies
-   [x] 59/59 total Flutter tests pass — no regressions
-   [x] flutter analyze clean — no issues
-   [x] No backend changes — Phase 3.3 endpoints reused as-is
-   [x] No new database migration required

# Future Phases

3.  Lobby & Profile
4.  Match Setup
5.  Matchmaking
6.  Classic Ludo
7.  1 Minute Ludo
8.  Game Features
9.  Wallet & Points
10. Admin Panel
11. Testing
12. Release

# Current GitHub Branch

main

# Latest Commit

phase-4.2

# Development Rules

-   Read PROJECT_MASTER_BLUEPRINT.md first.
-   Read this file before starting any task.
-   Never skip phases.
-   Complete one phase before starting the next.
-   Push every completed phase to GitHub.
-   Update this file after every phase.

# Notes

The old project is used only as a reference for UI, game logic, and
design ideas.

No code should be copied directly from the old project.

All new development follows the current project architecture.

Last Updated: 2026-07-18
