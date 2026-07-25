---
name: GitHub push credentials
description: Imported repositories may have an origin remote but no Replit GitHub source-control credentials.
---

An imported repository can have a valid `origin` URL and still reject both direct HTTPS pushes and the supported GitHub push flow when source-control credentials are not attached.

**Why:** Phase work can be committed and verified locally, but remote SHA verification cannot succeed until GitHub credentials are connected.

**How to apply:** If a push fails with authentication or `NO_CREDENTIALS`, keep the local commit intact, report the remote SHA separately, and do not alter remotes or expose credentials.