# Research: Python Quality Gates and UI Packaging

**Date**: 2026-09-06

**Scope**: Phase 0 for [spec.md](spec.md). Findings are source observations and
design decisions, not claims that proposed tools or runtime changes passed.

## Evidence ledger

| ID | Immutable source / primary reference | Finding |
| --- | --- | --- |
| U1 | [UI AGENTS](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/AGENTS.md) | Python 3.12, flat runtime ownership, unittest, compatibility/security rules |
| U2 | [main.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/main.py) | Auth/environment setup precedes Chainlit import; module creates `app`; asset paths currently use `__file__` |
| U3 | [app.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/app.py) | Import-time config, telemetry, conditional hosted clients, callbacks and data-layer registration |
| U4 | [datalayer.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/datalayer.py) | Function-local `from app import replace_source_reference_links` creates a static back edge |
| U5 | [Dockerfile](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/Dockerfile), [requirements](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/requirements.txt), [CI](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/.github/workflows/tests.yml) | Python 3.12 container, Chainlit 2.9.4, requirements install, `uvicorn main:app`, unittest |
| U6 | [test_main_policy.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/tests/test_main_policy.py), [test_app_panel_wiring.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/tests/test_app_panel_wiring.py) | Tests mutate config singleton, patch root globals and reload `app`; moves need canonical test targets |
| U7 | [chat_backend.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/chat_backend.py), [panel_config.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/panel_config.py), [hosted_continuity_config.py](https://github.com/Azure/gpt-rag-ui/blob/c635bc6696714b543feec24b4a062a8a8f3ff6d0/hosted_continuity_config.py) | Existing Protocol, dataclasses and Literal-based typing seeds; executable defaults must prevail over prose |
| O1 | [orchestrator AGENTS](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/AGENTS.md), [pyproject](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/pyproject.toml) | Existing src layout; Python >=3.12; pytest imports from src; typed schema boundaries |
| O2 | [PR pipeline](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/.github/workflows/pr_pipeline.yaml) | `pytest -q` and separate Node 20 frontend build; preserve both |
| O3 | [search.py](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/src/connectors/search.py), [foundry_iq.py](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/src/connectors/foundry_iq.py) | Search imports Foundry IQ; Foundry IQ locally imports Search's OBO acquisition helper |
| O4 | [schemas.py](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/src/schemas.py), [connectors/types.py](https://github.com/Azure/gpt-rag-orchestrator/blob/c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18/src/connectors/types.py) | Existing Pydantic contracts; do not generate replacements |
| I1 | [ingestion AGENTS](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/AGENTS.md), [CI](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/.github/workflows/tests.yml) | Flat main/dependencies plus packages; Python 3.12; pytest; best-effort audit is not a general failure policy |
| I2 | [api/admin.py](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/api/admin.py), [api/panel.py](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/api/panel.py), [main.py](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/main.py) | Admin imports main-owned scheduler/registry state; panel imports admin helpers, creating an additional indirect cycle |
| I3 | [audit_contract.py](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/telemetry/audit_contract.py), [audit_sanitizer.py](https://github.com/Azure/gpt-rag-ingestion/blob/38a395586ee1d440a8e1ca8233413f8c25b3fdc2/telemetry/audit_sanitizer.py) | Typed contracts/sanitization exist; JSON audit contracts remain byte-identical |
| P1 | [manifest](../../manifest.json), [ADR-0004](../../docs/adr/ADR-0004-hosted-panel-conversations-contract.md) | Shipped refs, stateless hosted-container invariant, authenticated UI ownership and independent panel gates |
| D1 | [contributing docs](https://github.com/Azure/GPT-RAG/blob/dfa448127a162b86c0836d374b9f2689c61d4ea7/docs/contributing.md), [deployment docs](https://github.com/Azure/GPT-RAG/blob/dfa448127a162b86c0836d374b9f2689c61d4ea7/docs/deploy.md) | Contributor workflow needs gate guidance; deployed component flow should not change |
| C1 | [Chainlit 2.9.4 config](https://github.com/Chainlit/chainlit/blob/2.9.4/backend/chainlit/config.py) | `CHAINLIT_APP_ROOT` or cwd controls writable `.files`, `.chainlit` and public paths |

Orchestrator develop is one merge commit ahead of its manifest pin. Ingestion
develop equals its pin. UI develop is three commits ahead; the GitHub comparison
reports only `.github/copilot-instructions.md` changed from its manifest pin.
Do not silently replace shipped refs with these development refs in a release.

## R1. Quality tools

**Decision**: Ruff for required syntax/error-handler hygiene; mypy for typing;
Import Linter/Grimp for package contracts; narrow standard-library analysis in
the repository-local quality checker for gaps. Tests use the repository's
existing runner, including unittest in UI.

**Rationale**: Ruff is issue-mandated. Mypy documents gradual adoption with a
fixed scope. Import Linter supplies declarative forbidden/protected contracts.
No existing lint/type/import gate was found in the inspected component configs.
The additional adapter is not a general Python interpreter or new shared product.

**Alternatives considered**: Pyright is viable, but a second type checker adds
duplicate maintenance without an existing repository convention requiring it.
Tach supports flat modules and interface declarations, but its configured module
granularity still requires proof for within-module cycles and transitively
forbidden paths. A wholly custom analyzer costs more than using Grimp's graph
for package imports. Tests/manual review alone do not satisfy the issue.

Sources: [Ruff configuration](https://docs.astral.sh/ruff/configuration/),
[mypy existing code](https://mypy.readthedocs.io/en/stable/existing_code.html),
[Import Linter contracts](https://import-linter.readthedocs.io/en/stable/contract_types/),
[Tach configuration](https://docs.gauge.sh/usage/configuration/).

Ruff 0.16.6, mypy 2.3.1, Import Linter 2.15 and Grimp 3.17 were reported by their
official PyPI metadata during research as Python-3.12-compatible candidates.
Import Linter 2.15 requires Grimp >=3.17. Exact pins remain subject to component
installation and fixture evidence; this phase installed none of them.

## R2. Incremental typing without accepting new debt

**Decision**: Explicit monotonic scope plus structured individual diagnostic
baseline anchored to the protected base revision. Prefer zero baseline debt
in the small seed set; record unavoidable inherited diagnostics individually.
Only a separately reviewed policy change may grow baseline debt or shrink scope.

**Rationale**: Mypy's incremental option is a cache, not a debt baseline. A count
comparison permits removing error A and introducing B. File/line-only matching
breaks when UI modules move. Stable module IDs, enclosing symbols, normalized
source-context fingerprints, diagnostic code/message and multiplicity provide
conservative identity. Ambiguous matches fail for explicit review.

**Alternatives considered**: Blanket ignores hide new violations; baseline by
count is unsafe; immediate strict typing everywhere expands the work into a
rewrite; basedpyright's native path/rule/column baseline does not remove the
need for reviewed move identity and policy protection.

Mypy follows imports beyond selected files. Do not confuse `exclude` with an
import firewall or globally skip imports to make seeds pass. Keep imported
diagnostics in reports; classify blocking scope explicitly. Use precise stubs
or documented third-party overrides, not global `Any` fallbacks.

Sources: [mypy CLI](https://mypy.readthedocs.io/en/stable/command_line.html),
[configuration](https://mypy.readthedocs.io/en/stable/config_file.html),
[following imports](https://mypy.readthedocs.io/en/stable/running_mypy.html#following-imports),
[basedpyright baseline](https://docs.basedpyright.com/latest/benefits-over-pyright/baseline/).

## R3. Graph completeness and existing cycles

**Decision**: Include direct, relative, deferred function-local and
`TYPE_CHECKING` first-party imports in the architectural graph. Cover all runtime
modules, including flat root files; reject cycles without baselining them at
activation. Use explicit protected public/private surfaces, not naming guesses.

**Rationale**: Import Linter roots must be importable packages, not arbitrary
single-file modules. `acyclic_siblings` is not a universal cycle detector: it
omits some parent/child or out-of-root paths. Protected contracts are direct
access rules; a transitive forbidden rule would incorrectly block a permitted
public facade forwarding to a private implementation.

Read-only AST inspection identified U3/U4, O3 and I2 back edges, confirmed by
reading the cited source. This was a discovery probe, not a certified graph or
exhaustive violation count. A naive collector also showed why `from . import
sibling` must resolve to the actual sibling, not invent a dependency on every
export in the parent facade. The production adapter must have fixtures for
that case before any finding drives refactoring.

**Alternatives considered**: Excluding late imports hides the existing problem;
moving ingestion into src to satisfy a tool violates scope; enforcing a total
orchestrator layer order would invent rules inconsistent with current utilities.
Use a tested graph plus a small explicit initial prohibition set instead.

Sources: [Grimp graph API](https://grimp.readthedocs.io/en/stable/usage.html),
[Import Linter configuration](https://import-linter.readthedocs.io/en/stable/get_started/configure/),
[protected contract](https://import-linter.readthedocs.io/en/stable/contract_types/protected/),
[acyclic siblings](https://import-linter.readthedocs.io/en/stable/contract_types/acyclic_siblings/),
[graphlib](https://docs.python.org/3.12/library/graphlib.html).

## R4. Exception handling is more than a lint rule

**Decision**: Enable `E722`, `BLE001`, `PGH003`, `PGH004`, `RUF100` alongside
selected correctness rules. Add a syntax-level broad-handler inventory tied to
reviewed exceptions and public-failure regression tests.

**Rationale**: Ruff's `BLE001` intentionally allows broad handlers which re-raise
or log exception information. Logging does not establish a valid boundary or
prove absence of a success-shaped fallback. Conversely, audit export and the
UI's owner-index callback have explicit best-effort contracts that must survive
the refactor. The existing disconnected UI readiness page and disabled-panel
503 responses are intentional, not successful substitutes for failed chat.

**Alternatives considered**: Forbid every catch mechanically (breaks boundary
translation/cleanup); allow every logged catch (accepts hidden failures);
mass-generate `noqa` comments (hides debt without approval).

Sources: [bare-except](https://docs.astral.sh/ruff/rules/bare-except/),
[blind-except](https://docs.astral.sh/ruff/rules/blind-except/), U2/U3, I1/P1.

## R5. UI migration, startup, state and assets

**Decision**: Standard installed src package with thin public adapters. Add a
low-level config area; split composition from reusable behavior; retain assets
as deployment files and pass their root explicitly to bootstrap.

**Rationale**: Moving files verbatim changes `__file__`-relative paths and can
import Chainlit before authentication prerequisites. Root re-exports alone do
not preserve private monkey-patch targets or avoid duplicate mutable state.
Explicit owner APIs and separate compatibility tests are simpler than module
proxy tricks. The wheel installs code/legacy public modules; deployment assets
remain the existing copied bundle, not writable site-packages resources.

**Alternatives considered**: A one-shot move risks mixed imports and deployment
breakage; `PYTHONPATH=src` alone masks missing distribution content; duplicating
root and package code creates multiple singletons. Packaging deployment assets
inside site-packages would conflict with Chainlit's writable configuration.

Evidence: U2-U7, C1. Resource resolution and installed-code validation are
specified in [ui-compatibility.md](contracts/ui-compatibility.md).

## R6. Required checks and policy trust

**Decision**: Unprivileged PR checks with a protected-base policy evaluator,
independent result aggregation, and administrator-controlled required checks
and maintainer review for workflow/policy changes. No repository setting is
modified during planning.

**Rationale**: GitHub branch metadata reported UI/ingestion protected and
orchestrator unprotected, but classic protection endpoints for UI/ingestion
returned 404. Effective rules were therefore read through
`repos/{owner}/{repo}/rules/branches/develop`. None of the three returned a
required-status-check rule. A protected flag does not prove quality enforcement.
This is an adoption prerequisite, not an assumption of already active controls.

Checks must never execute candidate code, install hooks or test configuration
under privileged `pull_request_target` credentials. Policy scripts/configs and
reports are untrusted when supplied by a PR. Base-side CODEOWNERS and enforced
review of the latest push protect changes to that evaluation machinery.

**Alternatives considered**: A YAML job alone is insufficient; an unprotected
baseline writer can bless its own regressions; a new central organization CI
platform is outside scope. Use existing GitHub rules and repository-local jobs.

Sources: [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches),
[CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners),
[secure Actions use](https://docs.github.com/en/actions/reference/security/secure-use).

## Resolution and remaining execution evidence

The choices of tool family, scope model, graph semantics, UI ownership,
compatibility approach, rollout and recovery are resolved for planning.
Initial diagnostic counts, compatible dependency installation, exact final
candidate SHAs, administrator activation and runtime acceptance are measured
deliverables of implementation, not unknown feature requirements. Stop rather
than change the design silently if those measurements contradict a contract.

## Implementation checkpoints

The following implementation evidence refines the Phase 0 tool candidates;
it does not retroactively claim the research phase installed or tested them.

| Component | Delivery surface / immutable checkpoint | Exercised development toolchain |
| --- | --- | --- |
| Orchestrator | [Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346), `ef649eeab6144156b4c90c4422d62f229454dedc` | Python 3.12.9; Ruff 0.16.5; mypy 2.3.1; Import Linter 2.14; Grimp 3.16 |
| Ingestion | [Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296), `bbe52923dbaf2b8ce4f6f371e492ad32ae7ffe45` | Python 3.12.9; Ruff 0.16.5; mypy 2.3.1; Import Linter 2.14; Grimp 3.16 |
| UI | [Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110), `4959ecaf04ea94ce0d35837c73b43ea3884c5be8` | Python 3.12.9; Ruff 0.16.5; mypy 2.3.1; Import Linter 2.14; Grimp 3.16; packaging setuptools 80.9.0 |

The owners could not install the newer Ruff/Import Linter/Grimp research
candidates from the available package index. The exact alternatives above
were installed and exercised with the existing runners and mutation fixtures;
runtime dependency manifests did not change. No checker family or acceptance
criterion was replaced to accommodate availability.

All checkpoints remain draft. They demonstrate local typing/architecture
results, not full quality-gate compliance: inherited broad-handler and lint
findings remain explicit, the exception ledgers are empty, and bootstrap
policy approval has not been established. Handler failure contracts, strict
policy/adversarial coverage, administrative activation and live integration/
recovery remain separately reviewable work.
