---
applyTo: "manifest.json,CHANGELOG.md,.gitmodules,scripts/preDeploy.ps1,scripts/preDeploy.sh"
---

# Multi-repository release surfaces

- Follow `.github/copilot-instructions.md` and load `multi-repo-release`.
- `manifest.json` is the authoritative list of runtime components and tags.
- Keep the umbrella `manifest.json` `tag` equal to the release branch,
  changelog, Git tag, and GitHub Release version.
- Keep `manifest.json` `ailz_tag`, `.gitmodules` `infra.branch`, and the
  recorded `infra/` submodule gitlink aligned to the same validated AI Landing
  Zone release commit.
- Keep PowerShell and shell deployment behavior aligned with the same manifest
  contract.
- Validate the exact component and infrastructure combination before changing
  the platform release pin.
- Keep changelog, release notes, documentation, and manifest versions
  consistent.
- Never infer a version from stale prose or a previous release table.
