# 10_CODING_RULES.md

# CODING RULES

## Purpose

These rules must be followed by every AI assistant and developer working
on this project.

------------------------------------------------------------------------

# General Rules

-   Write clean, readable code.
-   Keep functions small and focused.
-   Reuse existing components.
-   Avoid duplicate code.
-   Never leave dead code.

------------------------------------------------------------------------

# Project Rules

-   Do not change the technology stack.
-   Do not rename project folders without approval.
-   Do not rewrite completed modules unless requested.
-   Follow the current project phase.

------------------------------------------------------------------------

# Flutter Rules

-   Use reusable widgets.
-   Separate UI from business logic.
-   Keep constants centralized.
-   Avoid hardcoded values.
-   Use meaningful file names.

------------------------------------------------------------------------

# Backend Rules

-   Use TypeScript.
-   Keep controllers, services and routes separated.
-   Validate all inputs.
-   Never trust client data.
-   Keep business logic in the backend.

------------------------------------------------------------------------

# Database Rules

-   Use foreign keys.
-   Never store plain-text passwords.
-   Use transactions for financial operations.
-   Never delete transaction history.

------------------------------------------------------------------------

# API Rules

-   Use REST conventions.
-   Return consistent JSON responses.
-   Handle errors gracefully.
-   Protect private endpoints with authentication.

------------------------------------------------------------------------

# Socket.IO Rules

-   Validate every event.
-   Server is the source of truth.
-   Broadcast only required data.
-   Handle reconnects safely.

------------------------------------------------------------------------

# Git Rules

Before pushing:

-   Build successfully.
-   Test changes.
-   Update PROJECT_STATUS.md.
-   Update CHANGELOG.md.
-   Commit with a clear message.
-   Push to GitHub.

------------------------------------------------------------------------

# Documentation Rules

Whenever architecture or features change:

-   Update related documentation.
-   Keep documentation synchronized with code.

------------------------------------------------------------------------

# Code Quality

-   Production-ready only.
-   No temporary hacks.
-   No commented-out blocks.
-   Remove unused imports.
-   Use descriptive names.

------------------------------------------------------------------------

# Final Rule

Every change should make the project easier to maintain, extend and
understand.
