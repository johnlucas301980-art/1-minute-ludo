# 11_FOLDER_STRUCTURE.md

# PROJECT FOLDER STRUCTURE

## Purpose

This document explains the purpose of every major folder in the project.
Do not change the folder structure without approval.

------------------------------------------------------------------------

# Root Structure

    1-minute-ludo/
    ├── mobile/
    ├── backend/
    ├── docs/
    ├── .env.example
    ├── .gitignore
    ├── README.md
    └── replit.md

------------------------------------------------------------------------

# mobile/

Flutter application.

Main folders:

    mobile/
    ├── android/
    ├── lib/
    │   ├── core/
    │   ├── screens/
    │   ├── widgets/
    │   ├── services/
    │   ├── models/
    │   └── main.dart
    ├── test/
    └── pubspec.yaml

Purpose:

-   User Interface
-   Game Screens
-   API Calls
-   Socket.IO Client
-   Local Storage

------------------------------------------------------------------------

# backend/

Node.js + Express backend.

    backend/
    ├── src/
    │   ├── config/
    │   ├── db/
    │   ├── routes/
    │   ├── socket/
    │   ├── middlewares/
    │   ├── services/
    │   ├── controllers/
    │   ├── models/
    │   ├── lib/
    │   ├── app.ts
    │   └── index.ts
    ├── package.json
    └── .env.example

Purpose:

-   REST API
-   Authentication
-   Matchmaking
-   Game Logic
-   Wallet Logic
-   Socket.IO
-   Database Access

------------------------------------------------------------------------

# docs/

Project documentation.

Recommended files:

-   00_START_HERE.md
-   01_AI_HANDOVER.md
-   02_PROJECT_STATUS.md
-   03_PROJECT_MASTER_BLUEPRINT.md
-   04_ARCHITECTURE.md
-   05_DATABASE.md
-   06_API.md
-   07_SOCKET_EVENTS.md
-   08_DEPLOYMENT.md
-   09_CHANGELOG.md
-   10_CODING_RULES.md
-   11_FOLDER_STRUCTURE.md
-   12_ROADMAP.md

------------------------------------------------------------------------

# Configuration Files

-   .env.example
-   .gitignore
-   README.md
-   replit.md

------------------------------------------------------------------------

# Rules

-   Keep folders organized.
-   One responsibility per folder.
-   Avoid unnecessary nesting.
-   Never mix frontend and backend code.
-   Keep documentation inside docs/.

------------------------------------------------------------------------

# Goal

A clean, scalable and easy-to-maintain project structure that any AI or
developer can understand quickly.
