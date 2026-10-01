# Implementation Plan: Agent Landing Zone Rebrand

**Branch**: `002-agent-landing-zone-rebrand` | **Date**: 2026-07-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/002-agent-landing-zone-rebrand/spec.md`

## Summary

GPT-RAG is repositioned as **Agent Landing Zone**: one umbrella repository
(`Azure/agent-landing-zone`) that owns both the infrastructure layer (today the
`bicep-ptn-aiml-landing-zone` submodule) and the application layer (today the
`gpt-rag-ui` / `gpt-rag-orchestrator` / `gpt-rag-ingestion` trio). The work is
delivered in three phases:

1. **v4.0.0-preview.1 (2026-10-02)** — the rebrand. Product name, `agentlz`
   naming conventions, the naming inventory, the README as a landing page, the
   repository renames at the end of the phase, the ADRs, and the constitution
   amendment.
2. **v4.0.0 (2026-10-09), Phase 2** — the platform:
   - infrastructure copied into the repository from `v2.7.3`, with provenance
     and parity workflows;
   - runtime identifiers renamed;
   - `azd provision` deploys infrastructure only;
   - `azd deploy` / `azd up` publish the application;
   - any application, including third-party ones, can be selected through
     `app-definition.json`, which is validated before any change.
3. **v4.0.0, Phase 3** — documentation migrated to the AI Landing Zones site,
   short links retargeted, and end-to-end validation of every deploy option.

The technical approach reuses the existing azd lifecycle hooks and the Python
`config/` modules. Three additions are needed:

- A versioned `app-definition-v1` JSON Schema plus a `config/appdefinition`
  validator. The validator runs in `preProvision` / `preDeploy` and fails closed.
- A `platform-outputs-v1` contract, published to App Configuration.
- Generalising today's trio-specific deploy logic in `scripts/preDeploy.*` and
  `config/deployment/*` so it iterates over the components listed in the app
  definition. The bundled trio becomes one `app-definition.json` whose versions
  come from `manifest.json`.

## Technical Context

**Language/Version**:
- Bicep: the infrastructure, incorporated from `bicep-ptn-aiml-landing-zone` v2.7.3.
- Python 3.11+: the `config/` and `util/` modules.
- PowerShell 7 and POSIX sh: the azd hooks, kept at parity.
- JSON Schema draft 2020-12: the contracts.

**Primary Dependencies**:
- Azure Developer CLI (azd), including the `azure.ai.agent` service host for hosted agents.
- Azure CLI.
- Python's `jsonschema`, `azure-identity`, and `azure-appconfiguration`.
- The existing `hosted-agent/` child azd project.

**Storage**:
- Azure App Configuration, under the label `agent-lz` (renamed from `gpt-rag`).
- The azd environment `.env` files, which hold the environment binding.

**Testing**:
- pytest in `tests/`, extending the existing `test_deployment_modes.py`,
  `test_existing_images.py`, `test_release_contracts.py`, and
  `test_infra_checkout.py`.
- Schema fixture tests for valid and invalid app definitions.
- Hook tests in both shells.
- End-to-end runs per FR-024.

**Target Platform**:
- Azure Container Apps (the classic components).
- The Microsoft Foundry Agent Service (hosted agents).
- Both public and network-isolated topologies.

**Project Type**: An infrastructure and deployment accelerator: an IaC and azd
umbrella with versioned contracts. It contains no runtime application code.

**Performance Goals**: An infra+app `azd up` takes at most 10% longer than the
current baseline (SC-002). `azd provision` publishes zero application images
(SC-005).

**Constraints**:
- **Behavior parity.** The copied infrastructure must behave identically to
  `v2.7.3`, apart from the renamed identifiers (FR-010b).
- **Fail closed.** All validation happens before any resource change (FR-016).
- **No silent fallback.** A hosted deployment never falls back to the classic
  mode.
- **New deployments only.** There is no in-place migration from GPT-RAG.
- **Fixed dates.** 2026-10-02 (preview) and 2026-10-09 (GA). If FR-015 slips,
  the fallback described in spec FR-015h applies.

**Scale/Scope**:
- 4 repositories renamed.
- Roughly 1,000 or more `gpt-rag` identifier occurrences, tracked in the naming
  inventory.
- 1 bundled application (3 components).
- 1 sample custom application, available in both hosting modes.
- About 30 documentation pages migrated.

All Technical Context items are resolved, so no NEEDS CLARIFICATION markers
remain. Choices are recorded in [research.md](./research.md).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Assessed against `.specify/memory/constitution.md` v1.0.0.

| # | Principle / gate | Pre-design status | How the plan complies |
| --- | --- | --- | --- |
| I | Repository and provisioning boundaries: do not edit `infra/` by hand; keep Search and Foundry IQ template-driven | ⚠️ Deliberate change | Copying the infrastructure into the repo makes `infra/` repo-owned source. This is justified in Complexity Tracking and requires ADR-0014 plus a constitution amendment (FR-023) **before** implementation. The Search and Foundry IQ templates stay template-driven. |
| II | Explicit, compatible contracts. The App Configuration label `gpt-rag` is a cross-repo contract | ⚠️ Breaking, by design | The label is renamed to `agent-lz`, together with the env vars and event names, in one coordinated change. The integration order: component releases first, then the umbrella; no in-place migration. Two new versioned contracts are added: `app-definition-v1` and `platform-outputs-v1`. |
| III | Identity and security: managed identity and Key Vault; no private environment names; untrusted input | ✅ | Capability profiles map only to predefined RBAC sets; free-form roles are rejected. App definitions are untrusted input, validated against the schema before any change. Remote URLs and hooks are disallowed. |
| IV | Observable failures: logging, not `print`; no silent degradation | ✅ | The validator reports every error with its JSON path through the logger and exits non-zero. Recovery is an idempotent re-run. |
| V | Verifiable evidence: real commands in both shells | ✅ | The quickstart scenarios cover each deploy option in both shells. FR-024 E2E runs record the exact component combination. |
| G1 | ADR before broad changes | ✅ Planned | ADR-0014 through ADR-0018 are drafted in Phase 1, before code changes. |
| G2 | Human approval before publishing | ✅ | Repository renames, tags, and releases are executed only after Paulo approves them. |
| G3 | `manifest.json` stays consistent with `.gitmodules` | ⚠️ Changed | Both `.gitmodules` and `ailz_tag` are removed together; provenance moves into `manifest.json` `infra.source`. `test_release_contracts.py` is updated to cover the new invariant. |

**Result**: PASS, with three justified deviations (see Complexity Tracking).
None is unjustified.

### Post-design re-check (after Phase 1)

| Area | Result |
| --- | --- |
| `contracts/app-definition.schema.json` | Versioned (`schemaVersion: 1`) and closed (`additionalProperties: false`). It contains no hook, URL, or free-form role fields. ✅ Principles II and III. |
| `contracts/platform-outputs.schema.json` | Read-only for the application and published under `agent-lz`. ✅ Principle II. |
| `contracts/azd-lifecycle.md` | Every failure path ends in a single actionable message with no partial resource change. ✅ Principle IV. |
| `contracts/naming-map.md` | A single source of truth for renames, with a rollback order documented. ✅ Principle II. |
| Data model | Environment-binding state transitions are explicit, and a mismatched `id` is rejected. ✅ Principle IV. |

**Post-design result**: PASS. No new violations were introduced.

## Project Structure

### Documentation (this feature)

```text
specs/002-agent-landing-zone-rebrand/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── app-definition.schema.json
│   ├── platform-outputs.schema.json
│   ├── azd-lifecycle.md
│   └── naming-map.md
├── checklists/
└── tasks.md             # Created by /speckit-tasks (not by this command)
```

### Source Code (repository root)

```text
azure.yaml                       # name: agent-landing-zone; hooks unchanged in shape
manifest.json                    # umbrella v4.0.0; components renamed; infra.source provenance; no ailz_tag
app-definition.json              # NEW – the bundled trio (default app); versions resolved from manifest.json
main.parameters.json             # identifiers renamed (agentlz / AGENTLZ_)
infra/                           # CHANGED – no longer a submodule; repo-owned Bicep copied from v2.7.3
.gitmodules                      # REMOVED
.github/workflows/
├── infra-validate.yml           # NEW (moved from the infra repo) – bicep build/lint/what-if
└── infra-terraform-parity.yml   # NEW (moved) – opens parity PR against the Terraform AVM module
contracts/
├── app-definition-v1.schema.json      # NEW (+ .sha256)
├── platform-outputs-v1.schema.json    # NEW (+ .sha256)
└── README.md                          # updated index
config/
├── appdefinition/               # NEW – load, validate, resolve and bind app definitions
│   ├── __init__.py
│   ├── loader.py                # path/env resolution, manifest version resolution for the trio
│   ├── validator.py             # schema + semantic checks (pinning, profiles, cardinality)
│   ├── profiles.py              # capability profile → RBAC role set mapping
│   ├── binding.py               # environment binding (id in .azure/<env>/.env)
│   └── __main__.py              # CLI: python -m config.appdefinition --validate <path>
├── deployment/                  # CHANGED – iterate over components instead of the fixed trio
│   ├── topology.py, composition.py, existing_images.py, hosted*.py
│   └── outputs.py               # NEW – publish platform outputs to App Configuration
└── (aifoundry, containerapps, search, governance, panel, continuity) – renamed identifiers only
scripts/
├── preProvision.ps1/.sh         # + app-definition validation and binding (fail closed)
├── postProvision.ps1/.sh        # + placeholder images only for containerapp components; publish platform outputs
└── preDeploy.ps1/.sh            # + "run azd provision first" guard; per-component deploy loop
hosted-agent/                    # existing child azd project, generalised for the selected definition
samples/
└── custom-app/                  # NEW – sample app: app-definition.json + azure.yaml, classic and hosted variants
docs/adr/
├── 0014-agent-landing-zone-consolidation.md
├── 0015-infra-incorporation.md
├── 0016-infra-app-layer-boundary.md
├── 0017-custom-app-definition.md
└── 0018-new-deployments-only.md
tests/
├── test_app_definition_schema.py      # NEW
├── test_app_definition_binding.py     # NEW
├── test_platform_outputs.py           # NEW
├── test_provision_only.py             # NEW (SC-005, image preservation)
├── test_naming_inventory.py           # NEW (SC-001 scan)
└── existing tests updated for renamed identifiers
```

**Structure Decision**: Keep the current umbrella layout. Add one focused Python
package, `config/appdefinition/`, rather than growing `config/deployment/`. Add
two contracts in the root `contracts/` folder; the copies under `specs/` are the
design drafts. Replace the `infra/` submodule with repo-owned source. Add
`samples/custom-app/` as the reference third-party application. No runtime
application code enters this repository.

## Delivery Phases

| Phase | Release | Date | Scope (FR) | Exit evidence |
| --- | --- | --- | --- | --- |
| 1. Rebrand | `v4.0.0-preview.1` | 2026-10-02 | FR-001, FR-004–FR-007, FR-009, FR-010, FR-018, FR-021–FR-023; minimal docs section and notices; repository renames at the end of the phase | US1 scenarios 1, 2, and 4; US3-1; US4 scenarios 1–3; SC-007; SC-008 |
| 2. Platform | `v4.0.0` | 2026-10-09 | FR-002, FR-002a, FR-003, FR-010a–FR-010e, FR-011–FR-016 | US2 and US5 scenarios; SC-002, SC-005, SC-009 |
| 3. Docs and validation | `v4.0.0` | 2026-10-09 | FR-017, FR-019, FR-020, FR-024; SC-001 scan | All scenarios; SC-001 through SC-007 and SC-009 |

Release order within each release:

1. The three component releases: `agent-app-ui`, `agent-app-orchestrator`, and
   `agent-app-ingestion`.
2. The `manifest.json` pin.
3. The umbrella release.

The rollback order is the reverse. See
[contracts/naming-map.md](./contracts/naming-map.md).

## Complexity Tracking

| Violation | Why needed | Simpler alternative rejected because |
| --- | --- | --- |
| Infrastructure copied into the repo; `infra/` becomes source (Principle I, G3) | A single product boundary covering infra and app is the core decision from the Weekly Sync. Infra-only deploys and parity workflows need the Bicep to live alongside the app layer. | Keeping the submodule leaves two release trains and two repository identities for one product, and blocks a single `v4.0.0`. A hybrid AVM approach is explicitly out of scope. |
| App Configuration label, env vars, and event names renamed `gpt-rag` → `agent-lz` / `AGENTLZ_` / `agentlz.` (Principle II) | The release must contain no `gpt-rag` identifiers (SC-001). | Keeping the old label leaks the old brand into every component and every operator's view. The umbrella supports only new deployments and writes only the new names, so no data migration is needed. Components read both labels and env prefixes for one release (R14), so component and umbrella releases can roll out and roll back independently. |
| Constitution amendment (FR-023): docs move off the `docs` branch, and infrastructure ownership changes | The constitution currently forbids both changes. | Implementing them without an amendment would violate the governance gate. |
| New contract `app-definition-v1` and the `config/appdefinition` package | Needed to support third-party apps safely: schema-validated, fail-closed, with no hooks or free-form roles. | Ad-hoc environment variables per component cannot express cardinality, pinning, or capability profiles, and cannot be validated before changes are made. |
