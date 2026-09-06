# Implementation Plan: Enforce Module Boundaries and Modularize the UI

**Branch**: `feature/python-module-boundaries` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: `specs/001-python-module-boundaries/spec.md`, [issue #681](https://github.com/Azure/GPT-RAG/issues/681)

**Status**: Phase 1 design complete; maintainer approved implementation through
pull requests on 2026-09-06. No merge, publication, deployment or settings change
is implied. The Spec Kit feature identifier is `001-python-module-boundaries`;
it is independent of the Git branch.

## Summary

Introduce repository-local Ruff, mypy, dependency, and error-boundary checks in
the three Python components. Preserve their existing test runners. Use a
reviewed typing scope and individual-finding debt ratchet, not error counts or
mypy's incremental cache. Use Import Linter for package contracts and a small,
tested static-import adapter for flat modules and complete first-party cycles.

Remove confirmed pre-existing static cycles before making architecture gates
blocking. Migrate the UI in dependency order into `src/gpt_rag_ui`, retaining
startup/public-import adapters and one owner for mutable state. Keep the
orchestrator and ingestion layouts, identity flows, wire contracts, configuration
defaults, and data ownership unchanged. No runtime changes, tool installations,
GitHub settings changes, releases, or deployments occur in this planning phase.

The coordinated decision is recorded in
[ADR-0005](../../docs/adr/ADR-0005-python-quality-gates-and-ui-package.md).
Detailed decisions and immutable evidence are in [research.md](research.md).

## Technical Context

**Language/Version**: Python 3.12, matching all three CI workflows and the UI
container. Preserve existing frontend tooling where present.

**Primary Dependencies**: Existing Chainlit 2.9.4, FastAPI, Pydantic, HTTPX and
Azure SDKs; orchestrator agent-framework dependencies remain unchanged.
All three component implementation checkpoints exercised development-only
Ruff 0.16.5, mypy 2.3.1, Import Linter 2.14 and Grimp 3.16 on Python 3.12.9.
The researched Ruff 0.16.6 / Import Linter 2.15 / Grimp 3.17 candidates were
unavailable from the implementation package index. This tool-version refinement,
with exact checkpoint evidence in [research.md](research.md#implementation-checkpoints),
does not relax the quality contract or establish complete gate acceptance.
Pin the exercised toolchain and stubs exactly, independently of runtime
dependencies. UI packaging uses standard setuptools src discovery and
explicit legacy `py-modules`, without replacing `requirements.txt` initially.

**Storage**: No application data change. Versioned quality-policy, scope,
exception, and baseline records plus CI report artifacts only. Existing Cosmos,
managed Conversations, Search, and Blob ownership remains unchanged.

**Testing**: Existing pytest in orchestrator/ingestion; existing unittest in UI.
Add focused quality-policy fixtures to each existing runner, preserving existing
behavior/security suites. Validation commands and stage prerequisites are in
[quickstart.md](quickstart.md).

**Target Platform**: Linux CI and containers; Windows contributor workflows.
Support source-checkout execution and installed UI code with staged deployment
assets. No `sys.path` edits to make packaging appear successful.

**Project Type**: Coordinated engineering change across three runtime
repositories, with the specification and coordination ADR in the umbrella.

**Performance Goals**: Preserve existing runtime behavior and responsiveness;
no new runtime performance target is introduced. Quality jobs receive explicit
timeouts and record duration. Do not create a performance benchmark program.

**Constraints**: No shared CI framework/repository, JWT implementation, Azure
client repository, contract replacement, ingestion src migration, or orchestrator
reorganization. No new application configuration key or resource is needed.
Preserve network-isolated builds and both lifecycle-hook platforms if touched.

**Scale/Scope**: Three independently gated repositories; one UI package
migration. Source inspection covers the development snapshots below; they are
planning baselines, not a newly deployment-validated release combination.

| Repository | Development snapshot | Shipped baseline from manifest |
| --- | --- | --- |
| gpt-rag-orchestrator | `c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18` | `v4.1.1` / `9b64a5b962067161cb55252c6e0917a2738ba984` |
| gpt-rag-ingestion | `38a395586ee1d440a8e1ca8233413f8c25b3fdc2` | `v2.7.3` / same commit |
| gpt-rag-ui | `c635bc6696714b543feec24b4a062a8a8f3ff6d0` | `v2.6.2` / `f59cca919f0bc59631d7bba7f3e223dff3718244` |

## Constitution Check

Evaluated against constitution 1.0.0 before research and again after design.

| Principle / gate | Pre-research | Post-design evidence |
| --- | --- | --- |
| I. Repository/provisioning boundaries | Pass: component-owned implementation | Pass: no runtime code in umbrella, no infrastructure changes; package and checker ownership specified below |
| II. Explicit compatible contracts | Pass: preservation required | Pass: quality and compatibility contracts, unchanged wire/data contracts, sequencing and recovery recorded |
| III. Identity and confidentiality | Pass: no new identity design | Pass: startup order, delegated identity, fail-closed tests, unprivileged CI and no customer data in reports |
| IV. Observable failures | Pass: distinguishes contractual best-effort behavior | Pass: handler inventory, visible gate failures, no broad auto-exemptions; public-failure tests required |
| V. Verifiable evidence | Pass for planning, not runtime acceptance | Pass: immutable source evidence, concrete existing commands and future acceptance fixtures; no invented passing runs |
| Architecture decision | Required before implementation | Pass: ADR-0005 accepted by the maintainer for implementation through PRs on 2026-09-06; concrete policy changes still receive component review |
| Documentation consistency | No shipped change in this phase | Pass: affected contributor guidance and conditional operator pages identified |
| Publishing authorization | Not requested | Pass: no pins, tags, release metadata, settings, or deployments changed |

No constitution waiver is requested. Implementation must stop if it cannot
preserve an identified contract, establish a tested import graph, or obtain the
required merge-policy approval; those failures cannot be hidden in a baseline.

## Project Structure

### Documentation (this feature)

```text
specs/001-python-module-boundaries/
|-- spec.md
|-- plan.md
|-- research.md
|-- data-model.md
|-- quickstart.md
|-- checklists/requirements.md
`-- contracts/
    |-- quality-gates.md
    `-- ui-compatibility.md
docs/adr/ADR-0005-python-quality-gates-and-ui-package.md
```

`tasks.md` is intentionally not generated by `/speckit-plan`.

### Source Code (component-owned, proposed unless marked existing)

```text
Each runtime repository:
|-- pyproject.toml                 # existing in orchestrator; new tool settings elsewhere
|-- requirements-quality.txt       # exact development tool/stub pins
|-- .quality/
|   |-- policy.json
|   |-- typing-scope.json
|   |-- typing-baseline.json
|   `-- exceptions.json
|-- .github/scripts/check-quality.py
|-- .github/workflows/             # extend existing PR workflow with checks + aggregate
|-- .github/CODEOWNERS             # resolve actual maintainer owners before activation
`-- tests/                        # preserve that repository's runner

gpt-rag-ui:
|-- main.py, app.py                # existing names, thin adapters after migration
|-- <legacy module adapters>       # only inventoried compatibility exports
|-- connectors/                   # legacy public import adapters
|-- src/gpt_rag_ui/
|   |-- __init__.py                # inert: no app/client creation
|   |-- bootstrap.py               # startup composition and registration order
|   |-- api/                      # routes, Chainlit callbacks and data-layer adapter
|   |-- auth/                     # identity, sessions, tokens and embedding checks
|   |-- clients/                  # backend, Blob and persistence transport adapters
|   |-- config/                   # settings and existing AppConfig provider/singleton
|   |-- services/                 # chat, history, citations, continuity and feedback
|   |-- telemetry/                # existing instrumentation
|   `-- util/                     # constants/pure helpers only
|-- public/, .chainlit/            # existing deployment assets retained
`-- VERSION, chainlit.md, chainlit.config.yaml

gpt-rag-orchestrator:
`-- src/                          # existing structure retained, local cycle fixes only

gpt-rag-ingestion:
|-- main.py, dependencies.py       # existing flat layout retained
`-- api/, jobs/, chunking/, tools/, telemetry/, utils/
```

**Structure Decision**: A `config` area is added to the illustrative UI layout
because source shows clients, auth and telemetry all consume configuration.
Keeping its provider below those consumers avoids a manufactured clients/auth
cycle. Moving entire mixed-responsibility files without splitting composition
would not satisfy the dependency contract. The exact responsibility map and
public/private policy are in [ui-compatibility.md](contracts/ui-compatibility.md).

## Delivery Design

### 1. Establish evidence and bootstrap the gates

In each component, branch from current `develop`, record its exact SHA, rerun
the existing focused suites, and reconcile drift from the research snapshots.
Inventory supported imports, covered modules, public failure boundaries, and
existing exception sites before adding suppressions.

Introduce exact tool pins, policy records, checker fixtures and reports in a
bootstrap PR. Run checks on that PR, but do not advertise required enforcement
until the protected policy and repository rules are actually active. No lint
auto-fix, blanket `noqa`, global `ignore_missing_imports`, or automatic baseline
rewrite is allowed.

Initial typing files (diagnostics must be measured, not assumed absent):

| Component | Initial blocking files | Subsequent expansion |
| --- | --- | --- |
| Orchestrator | `src/schemas.py`, `src/connectors/types.py`, `src/plugins/retrieval/retrieval_types.py`, `src/plugins/nl2sql/nl2sql_types.py` | audit contracts/sanitizers, orchestration, strategies and connector boundaries |
| Ingestion | `telemetry/audit_contract.py`, `telemetry/audit_sanitizer.py` | typed configuration, delegated-auth and retrieval/operator boundaries |
| UI | `chat_backend.py`, `panel_config.py`, `hosted_continuity_config.py` | mapped package equivalents, token/client contracts, services and callbacks |

All new modules enter blocking typing coverage; existing uncovered modules stay
visible in the coverage report and enter the stated expansion sequence. Moves
preserve identity and coverage. Runtime lint and architecture checks scan all
first-party runtime files, not merely these typing seeds.

### 2. Remove cycles and establish a green protected policy

The source-confirmed cycles include function-local imports; a delayed import is
not a dependency-boundary fix:

| Component | Confirmed cycle | Local remedy, with compatibility tests |
| --- | --- | --- |
| UI | `app -> datalayer -> app.replace_source_reference_links` | Move reusable citation transformation into a service with explicit context; both consumers use it |
| Orchestrator | `connectors.search -> connectors.foundry_iq -> connectors.search.acquire_obo_token` | Extract the existing OBO acquisition implementation into a focused connector helper; preserve a public re-export and exact claims/scopes/errors |
| Ingestion | `main -> api.admin -> main`, also `main -> api.panel -> api.admin -> main` | Expose existing scheduler/registry state through a focused jobs runtime-state interface; routes receive/use it without importing the application entry point |

Do not impose a simplistic total layer ordering on existing orchestrator or
ingestion packages: current configuration/telemetry utility relationships do not
support it. Start with the source-grounded prohibitions in the quality contract.
Check the full graph for additional cycles; repair them locally or stop for
review if repair would alter behavior. No cycle baseline is accepted at final
activation.

Classify broad handlers before enabling enforcement. Preserve explicitly
contractual best-effort audit emission and UI owner-index notification. Narrow
handlers where supported; retain broad boundary translation/re-raise only with
scoped approved records and tests. A comment or logging call alone is insufficient.

An administrator then configures required quality/test checks and protected
review of policy files on development and release-target paths. Research found
no effective required-status-check rules on the inspected `develop` branches;
the work is not complete with workflow files alone.

#### MAF primary-failure correction

Implementation inspection at orchestrator `8d0ac05` resolves the previously
recorded MAF failure question without introducing a new transport contract.
Both `MafLiteStrategy.initiate_agent_flow` and
`MafAgentServiceStrategy.initiate_agent_flow` catch primary failures and yield
exception details as ordinary assistant text. This prevents the existing
orchestration failure path from running and falsely emits normal completion.

Remove that interception so the existing `Orchestrator.stream_response`
failure path emits `outcome.rejected` / `request.failed`, and `stream_turn`
supplies its existing safe `TurnErrorEvent`. The classic serializer and SSE
generator already support and deduplicate that terminal error. Preserve their
wire spelling, status codes, typed models, audit schema and cancellation
behavior. This corrects an observable failed-operation outcome; it is not a
claim that the old MAF fallback was an approved compatibility guarantee.

The propagation change must also prevent raw upstream exception details from
escaping through the enclosing SSE logger or automatic OpenTelemetry exception
capture/status descriptions. Prove both MAF strategies, failure before and
after partial output, safe diagnostics and distinct cancellation through the
existing runners. Keep normal successful history/persistence behavior intact.
Do not apply a blanket fatal-error rule to separate optional profile, intent
or context-provider operations; their established contracts require individual
disposition. Required broad boundaries still need genuine review, not an
agent-created approval. Document the candidate behavior as unshipped until
its component is released.

### 3. Migrate the UI by dependency slice

Introduce package metadata/install support first, with runtime dependencies
still sourced from `requirements.txt`. Preserve the Docker command
`uvicorn main:app --host 0.0.0.0 --port 8080`.

Move config/pure helpers, auth/clients, services, and finally composition in
small independently green PRs. At every step, maintain one canonical module for
state, explicit legacy exports, old/new public-import smoke coverage, and the
existing security suites. Package code must not import a legacy adapter.

Extract citation logic to remove the UI cycle; keep token creation, conversation
ownership and allowed-download behavior unchanged. Separate route/callback
registration from reusable logic when a file currently mixes both. Do not
silently eager-load hosted-only stores for classic deployments.

Root `main.py` supplies the deployment asset root to bootstrap before any
Chainlit import; `app.py` remains an event-registration adapter. Tests that patch
private globals must patch the canonical owner after a move; keep separate
public compatibility tests rather than emulating arbitrary module mutation.
See the resource and lifecycle rules in the UI contract.

### 4. Integrate evidence, documentation and recovery

CI-only component PRs can land independently. UI slices depend only on preceding
merged UI slices. Runtime cycle-removal changes must pass against the shipped
peer components, then against the final candidate combination.

Record candidate SHAs and the previous known-good combination with each
integration result. Future tags and the binding manifest update are release
work, not guessed here. Update the manifest only after compatible component
releases exist and publishing has explicit approval.

For recovery, revert the affected component's latest code/package slice and
redeploy its preceding compatible artifact; if manifest pins were subsequently
changed, restore the full recorded previous combination. No data/configuration
migration or key/RBAC change is needed. Do not remove quality protections as a
shortcut; repair a bad checker in a separately reviewed policy change.

## Documentation and Acceptance Handoff

Update each component's `AGENTS.md` responsibility map and contributor commands
when its checks/layout ship. Update `docs/contributing.md` on the umbrella's
`docs` branch with the required checks and repository-specific setup. Check
`docs/deploy.md`, `docs/howto_authentication.md`, and
`docs/hosted_continuity_platform_contract.md` for affected examples; preserve
their current claims if operator behavior is unchanged. Do not publish planned
behavior as already shipped.

FR-001 through FR-008 are covered by the quality contract and negative fixtures;
FR-009 through FR-012 by the UI compatibility matrix; FR-013 through FR-015 by
the staged delivery, exact-ref evidence, ADR and documentation handoff. The
quickstart maps these to existing commands and post-implementation scenarios.

Phase 1 leaves no unresolved design choice. Tool integration, baseline capture,
package builds, component regressions, rule activation and Azure smoke evidence
remain implementation/adoption work,
not results claimed by this plan. Maintainer acceptance of the architectural
direction has since been recorded in ADR-0005; repository settings activation
and evidence for the actual implementation remain outstanding.
