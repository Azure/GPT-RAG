# Architecture and boundaries

- `main.bicep` is the resource-group-scoped orchestrator; keep resource bodies
  in focused AVM or local modules.
- Reuse module families under `modules/ai-foundry`, `networking`, `security`,
  `container-apps`, `app-configuration`, and `bing-search`.
- Use `constants/constants.bicep` for role IDs, abbreviations, and shared types.
- Drive infrastructure shape from typed lists rather than workload-specific
  branches.
- Preserve standard, standalone Zero Trust, and AI Landing Zone integrated
  topology intent. Explicit operator choices remain authoritative.
- Treat `azure.yaml`, pipeline templates, preflight, and integration fixtures as
  architecture verification surfaces, not independent product implementations.
- Evaluate reversibility, migration, consumer-submodule compatibility, Azure
  limits, cost, and operational ownership before changing a boundary.
