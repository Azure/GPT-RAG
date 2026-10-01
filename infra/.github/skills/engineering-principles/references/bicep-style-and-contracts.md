# Bicep style and contracts

- Add `@description` to parameters and outputs; use typed objects and arrays.
- Preserve existing parameter names, defaults, allowed values, nullable
  semantics, and `SCREAMING_SNAKE_CASE` output names by default.
- Guard values that azd substitution can resolve to empty before resource use.
- Keep a new capability consistent across `main.bicep`,
  `main.parameters.json`, runtime configuration publication, and outputs.
- Reuse `const.roles` and `const.abbrs`; do not duplicate role GUIDs or naming
  abbreviations.
- Preserve CAF and legacy naming modes, length limits, deterministic tokens, and
  explicit-name overrides.
- Keep optional resources behind feature-flag conditions and return existing
  empty or false output fallbacks when a feature is disabled.
- Extend module interfaces additively where possible. Breaking parameter,
  output, naming, or topology changes require migration guidance and semantic
  version classification.
- Run Bicep build and lint after contract changes; inspect warnings instead of
  suppressing them without a documented reason.
