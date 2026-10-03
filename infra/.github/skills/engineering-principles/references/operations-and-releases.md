# Operations and releases

- Start operations with read-only evidence and establish subscription, resource
  group, deployment mode, identity, and parameter source before mutation.
- Preflight and What-If are required risk controls but do not grant deployment
  approval.
- Preserve PowerShell 7 behavior across azd Windows and POSIX hooks.
- Preserve `install.ps1` timeout budgets, bounded external operations, and
  fatal-versus-optional bootstrap steps.
- Keep `README.md`, `CHANGELOG.md`, runbooks, pipeline guidance, and the public
  AI Landing Zones documentation aligned with shipped behavior.
- Use semantic versioning. Align manifest versions, changelog, tag, release
  title, and exact release commit.
- Major or minor changes require Portal and Terraform landing-zone parity
  review.
- Tags, releases, packages, and production changes require explicit human
  approval and a rollback or roll-forward path.
