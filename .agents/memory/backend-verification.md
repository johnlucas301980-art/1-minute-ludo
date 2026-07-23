---
name: Backend verification
description: Environment-specific setup and regression context for validating this imported backend.
---

The imported workspace can have no `node_modules` even when the pnpm lockfile is complete. A frozen workspace install restores the declared dependencies without changing dependency declarations.

**Why:** The configured backend workflow cannot build until workspace dependencies are installed, and the package helper may target the workspace root instead of respecting the existing workspace layout.

**How to apply:** When backend verification fails with a missing declared package, use the existing lockfile install path before changing package manifests. Separate unrelated pre-existing database or gameplay regressions from the feature under test.