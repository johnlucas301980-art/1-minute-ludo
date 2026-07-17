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

v0.2.0

# Current Phase

✅ Phase 3.1 - Player Profile Foundation Completed (2026-07-17)

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

ccd6387

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

Last Updated: 2026-07-17
