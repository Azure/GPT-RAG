---
name: multi-repo-release
description: Prepares and validates GPT-RAG umbrella releases across component repositories and the AI Landing Zone. Use for manifest pins, changelog entries, release branches, tags, and GitHub Release notes.
---

# GPT-RAG multi-repository release

Read `.github/copilot-instructions.md` completely before changing a release
artifact. Its branching, versioning, changelog, and release-note requirements
are authoritative.

1. Determine the intended semantic version and create the release branch from
   `develop` using `release/x.y.z`.
2. Update `manifest.json` `tag` to `vX.Y.Z` and verify it matches the release
   branch version, changelog heading, Git tag, and GitHub Release title.
3. Read every runtime component tag from `manifest.json` `components[]` and the
   infrastructure tag from `ailz_tag`; never copy a previous version table.
4. Require the AI Landing Zone pins to agree: `manifest.json` `ailz_tag`, the
   `.gitmodules` `infra.branch`, and the recorded `infra/` submodule gitlink
   must identify the same validated release commit.
5. Confirm that the exact pinned combination was validated and record the
   relevant commands and Azure deployment mode without private environment or
   resource group names.
6. Replace `[Unreleased]` with `## [vX.Y.Z] - YYYY-MM-DD` for the release.
7. Keep `CHANGELOG.md` and GitHub Release notes consistent, including the full
   required component version table.
8. Use exactly `vX.Y.Z` for both the tag and GitHub Release title.
9. Target the release pull request to `main`.
10. Re-fetch published release notes and verify headings, lists, tables, and the
   absence of private `gptrag-*` and `rg-gptrag-*` validation names.

Do not publish a tag, release, package, image, or production deployment without
explicit human approval. Report incompatible pins, missing validation, or
documentation drift as blockers rather than filling gaps by assumption.
