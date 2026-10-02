---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml,pipelines/**/*.yml,pipelines/**/*.yaml"
---

# Validation and deployment pipelines

- Preserve existing branch and path filters unless the change intentionally
  alters coverage.
- Pin validation dependencies and grant the minimum workflow permissions.
- Keep Bicep build and lint aligned between GitHub Actions and Azure DevOps.
- Keep What-If before deployment stages and preserve approval gates.
- Treat Bash inside Azure DevOps templates and PowerShell scripts as separate
  implementations that must agree on shared behavior.
- Propagate native exit codes and surface resource-level failures.
- Never print secrets, service-connection credentials, or private environment
  names.
- Validate edited workflow YAML and the command it invokes.
