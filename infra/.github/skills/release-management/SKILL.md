---
name: release-management
description: Prepares and validates AI Landing Zone semantic releases. Use for changelog entries, manifest versions, release branches, tags, GitHub Releases, and post-release branch reconciliation.
---

# AI Landing Zone release management

1. Read the release and branching rules in `AGENTS.md` and scoped instructions.
2. Confirm `develop`, when used, includes the latest release from `main`.
3. Determine semantic-version impact from compatibility and behavior.
4. Keep `manifest.json` `tag` and `ailz_tag`, changelog version, Git tag, and
   GitHub Release title equal to `vMAJOR.MINOR.PATCH`.
5. Verify the exact commit with Copilot asset validation, targeted tests, Bicep
   build and lint, preflight, and Azure evidence appropriate to the change.
6. Confirm repository and public documentation status.
7. For major or minor changes, record Portal and Terraform parity follow-up.
8. Publish notes from the changelog and verify the created tag and release.
9. Reconcile `develop` with `main` immediately after release.

Never infer a version from stale prose. Never publish a tag, release, package,
or production deployment without explicit human approval.
