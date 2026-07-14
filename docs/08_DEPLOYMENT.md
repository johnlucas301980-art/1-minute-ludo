# 08_DEPLOYMENT.md

# DEPLOYMENT GUIDE

## Purpose

This document explains how to deploy the 1 Minute Ludo project from
development to production.

------------------------------------------------------------------------

# Technology Stack

-   Flutter (Android App)
-   Node.js + Express
-   PostgreSQL
-   Socket.IO
-   TypeScript

------------------------------------------------------------------------

# Production Requirements

## Backend Server

-   Linux VPS or Cloud Server
-   Node.js LTS
-   PM2 (recommended)
-   Nginx (reverse proxy)
-   SSL certificate (HTTPS)

## Database

-   PostgreSQL
-   Daily backups
-   Automatic recovery plan

------------------------------------------------------------------------

# Environment Variables

Required:

-   PORT
-   DATABASE_URL
-   SESSION_SECRET
-   CORS_ORIGIN
-   LOG_LEVEL

Never commit secrets to GitHub.

------------------------------------------------------------------------

# Flutter Release

Development:

flutter run

Release APK:

flutter build apk --release

Future:

flutter build appbundle

------------------------------------------------------------------------

# Backend Deployment

Install dependencies:

pnpm install

Build:

pnpm build

Start:

pnpm start

Recommended:

pm2 start

------------------------------------------------------------------------

# Reverse Proxy

Use Nginx to:

-   Enable HTTPS
-   Forward API requests
-   Forward Socket.IO traffic
-   Improve security

------------------------------------------------------------------------

# Security Checklist

-   HTTPS enabled
-   JWT authentication
-   Secure environment variables
-   Rate limiting
-   Input validation
-   Database backups
-   Error logging

------------------------------------------------------------------------

# Monitoring

Monitor:

-   CPU
-   Memory
-   Database
-   Socket connections
-   API response time
-   Server logs

------------------------------------------------------------------------

# Backup Strategy

Backup:

-   PostgreSQL database
-   Uploaded files
-   Environment configuration
-   GitHub repository

------------------------------------------------------------------------

# Deployment Flow

1.  Pull latest code from GitHub.
2.  Install dependencies.
3.  Configure environment variables.
4.  Run database migrations.
5.  Build backend.
6.  Start backend.
7.  Build Flutter release.
8.  Test APIs and Socket.IO.
9.  Monitor logs.
10. Go live.

------------------------------------------------------------------------

# Rollback Plan

If deployment fails:

-   Restore previous release.
-   Restore database backup if necessary.
-   Verify application health.
-   Redeploy after fixes.

------------------------------------------------------------------------

# Goal

Ensure safe, repeatable and production-ready deployments with minimal
downtime.
