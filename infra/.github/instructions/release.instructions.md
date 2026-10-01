---
applyTo: "CHANGELOG.md,manifest.json,README.md,docs/**,.github/pull_request_template.md"
---

# Documentation and release surfaces

- Load `documentation-consistency`; load `release-management` for version or
  publishing work.
- Keep the changelog factual and classify compatibility impact.
- Align `manifest.json` `tag` and `ailz_tag`, changelog version, Git tag, and
  GitHub Release title.
- Preserve the manifest bootstrap contract and pinned consumer reproducibility.
- Major or minor changes require Portal and Terraform landing-zone parity
  review.
- Update relevant runbooks and the public `Azure/AI-Landing-Zones` source when
  operator-facing behavior changes.
- Never publish a tag, release, package, or production deployment without
  explicit human approval.
