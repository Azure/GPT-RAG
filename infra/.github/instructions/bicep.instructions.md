---
applyTo: "main.bicep,modules/**/*.bicep,constants/**/*.bicep,tests/**/*.bicep"
---

# Bicep implementation

- Load `engineering-principles`.
- Keep `main.bicep` as orchestrator and reusable resource bodies in focused
  modules.
- Reuse AVM and existing local module patterns before creating new resources.
- Add descriptions and explicit types to public parameters and outputs.
- Preserve feature-flag conditions, disabled-feature output fallbacks, module
  dependencies, and idempotency.
- Use `const.roles` and `const.abbrs` instead of duplicated literals.
- Preserve CAF and legacy naming behavior and explicit-name overrides.
- Treat identity, role scope, private DNS, private endpoints, subnet delegation,
  routes, and public access as security-sensitive.
- Run Bicep build and lint; run the size gate when compiled output changes.
