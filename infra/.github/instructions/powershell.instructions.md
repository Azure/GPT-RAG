---
applyTo: "**/*.ps1,azure.yaml"
---

# PowerShell and azd automation

- Target PowerShell 7 for shared scripts unless `install.ps1` requires Windows
  PowerShell compatibility under Custom Script Extension.
- Keep azd Windows and POSIX hooks behaviorally identical through their shared
  PowerShell command.
- Quote paths and external input; do not print secrets or private validation
  environment names.
- Fail explicitly on unmet prerequisites and non-transient errors. Do not return
  success-shaped fallbacks.
- Preserve idempotency, `SupportsShouldProcess`, and `-WhatIf` behavior where
  present.
- Preserve `install.ps1` wall-clock budgets, bounded operations, process-tree
  cleanup, and fatal-versus-optional step behavior.
- Add deterministic tests for parsing, validation, and branching logic.
- Load `documentation-consistency` when operator commands or deployment flow
  change.
