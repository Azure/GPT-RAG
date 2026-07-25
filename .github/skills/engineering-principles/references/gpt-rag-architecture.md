# GPT-RAG architecture

## Purpose and boundaries

GPT-RAG is an Azure solution accelerator, not a monolithic application. This
repository owns platform configuration, deployment composition, shared
contracts, and release pins. Runtime behavior belongs to the component
repositories referenced by `manifest.json`.

Preserve these boundaries:

- `config/` configures provisioned Azure services.
- `scripts/` coordinates `azd` lifecycle operations.
- `main.parameters.json` expresses deployment topology.
- `manifest.json` binds a validated multi-repository release.
- `.gitmodules` binds the AI Landing Zone source.
- `contracts/` contains shared versioned schemas.
- `infra/` is generated from the pinned submodule and is not edited directly.

## Design questions

Before changing a boundary, ask:

1. Which repository owns the behavior?
2. Is the change configuration, provisioning, runtime behavior, or a shared
   contract?
3. Which identities and trust boundaries are crossed?
4. Does it preserve Basic, network-isolated, and supported upgrade paths?
5. Which component versions must be validated together?
6. What is the rollback or roll-forward path?

Prefer a focused module or adapter over adding conditionals to an unrelated
setup path. Prefer explicit, typed contracts over implicit dictionaries or
duplicated environment-variable knowledge.

## Sources of truth

- Read release and component versions from `manifest.json`.
- Read deployment defaults and topology from `main.parameters.json` and the
  pinned infrastructure source.
- Read runtime behavior from the pinned component repository and tag.
- Read product documentation from the `docs` branch.
- Record significant platform decisions in `docs/adr/`.
