# 04_ARCHITECTURE.md

# SYSTEM ARCHITECTURE

## Overview

The system follows a client-server architecture.

    Flutter App
         │
     REST API + Socket.IO
         │
    Node.js + Express
         │
     PostgreSQL

------------------------------------------------------------------------

# Components

## Mobile (Flutter)

Responsibilities: - User Interface - Authentication - Match Setup -
Gameplay - Profile - Wallet - API Communication - Socket Communication

------------------------------------------------------------------------

## Backend

Responsibilities: - Authentication - Business Logic - Matchmaking - Game
State - Wallet Logic - Admin APIs - Socket.IO Events

------------------------------------------------------------------------

## Database

Responsibilities: - Users - Matches - Wallet - Transactions - Rankings -
Game History - Settings

------------------------------------------------------------------------

# Communication

## REST API

Used for:

-   Login
-   Register
-   Profile
-   Wallet
-   History
-   Settings

## Socket.IO

Used for:

-   Matchmaking
-   Live Game
-   Dice Roll
-   Pawn Movement
-   Timer
-   Winner
-   Player Disconnect
-   Reconnect

------------------------------------------------------------------------

# Folder Layout

    mobile/
    backend/
    docs/

------------------------------------------------------------------------

# Design Principles

-   Modular architecture
-   Separation of concerns
-   Stateless REST APIs
-   Real-time communication with Socket.IO
-   Secure database access
-   Scalable project structure

------------------------------------------------------------------------

# Data Flow

1.  User opens app.
2.  User authenticates.
3.  REST API returns profile.
4.  User joins match.
5.  Socket.IO establishes realtime connection.
6.  Backend manages game state.
7.  Database stores permanent data.
8.  Match ends and results are saved.

------------------------------------------------------------------------

# Scalability Goals

-   Support thousands of concurrent users.
-   Allow future game modes.
-   Easy deployment.
-   Easy maintenance.
-   AI-friendly documentation.

------------------------------------------------------------------------

# Rules

-   Never bypass backend validation.
-   Never expose database directly to client.
-   Keep business logic inside backend.
-   Keep UI logic inside Flutter.
-   Keep database isolated.
