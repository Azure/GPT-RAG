---
applyTo: "main.parameters.json,manifest.json,azure.yaml,constants/**/*.json"
---

# Parameters and contracts

- Treat parameter names, values, defaults, manifest fields, constants, and azd
  hook behavior as versioned compatibility surfaces.
- Keep `main.bicep` and `main.parameters.json` aligned.
- Use `${ENV_VAR=default}` substitution consistently and add a safe Bicep
  fallback when substitution can yield empty.
- Keep structured arrays and objects structured; never coerce them to strings.
- Do not place secrets in parameter files. Preserve the established secret
  indirection used by azd and Azure DevOps.
- Preserve `manifest.json` because jumpbox bootstrap and consumer accelerators
  depend on it.
- Keep `manifest.json` release fields aligned during releases.
- Update runtime configuration publication and outputs when consumers require a
  new value.
