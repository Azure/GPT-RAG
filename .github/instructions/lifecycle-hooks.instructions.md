---
applyTo: "scripts/**/*.ps1,scripts/**/*.sh,azure.yaml"
---

# azd lifecycle hooks

- Keep PowerShell and shell hooks behaviorally equivalent.
- Treat hook ordering and environment-variable propagation as public
  deployment behavior.
- Preserve `azd` environment reuse when component repositories are cloned and
  deployed.
- Do not edit generated content under `infra/`; update root overrides or the
  pinned infrastructure source.
- Quote paths and external input safely. Do not echo secrets or private Azure
  validation environment names.
- Surface failed prerequisites and provisioning steps; do not continue with a
  success-shaped fallback.
- Validate both platform variants when changing shared hook behavior.
- Load `documentation-consistency` when the deployment flow or operator steps
  change.
