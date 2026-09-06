# Tasks: Python Module Boundaries and Compatible UI Packaging

**Input**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [quality contract](contracts/quality-gates.md),
[UI contract](contracts/ui-compatibility.md).

**Authorization**: Maintainer approved implementation through PRs on 2026-09-06.
Do not merge PRs, publish releases/images, deploy, or change GitHub settings
directly. Administration/live environment acceptance is recorded as pending
when it cannot be completed through this authorized PR-only workflow.

**Tests**: Required by FR-002/005/007/008/011/012 and SC-001 through SC-006.
Use existing pytest in backends and unittest in UI; mutation fixtures precede
checker implementation. Record pre-existing failures separately.

**Path conventions**: `orchestrator/`, `ingestion/`, `ui/` prefix paths in their
own repositories, not new umbrella directories. `site/` means the `docs` branch
of Azure/GPT-RAG. Unprefixed paths belong to this umbrella branch.

## Phase 1: Setup

**Purpose**: Persist authorization and reconcile source assumptions.

- [X] T001 Record maintainer approval and PR-only authorization in docs/adr/ADR-0005-python-quality-gates-and-ui-package.md and specs/001-python-module-boundaries/plan.md.
- [ ] T002 [P] Reconcile orchestrator/develop against research refs and inventory source roots, typed/public surfaces and existing workflows in orchestrator/.quality/policy.json.
- [ ] T003 [P] Reconcile ingestion/develop against research refs and inventory flat roots, typed/public surfaces and scheduler ownership in ingestion/.quality/policy.json.
- [ ] T004 [P] Freeze UI public imports, launch paths, settings, module ownership and resources against current source in ui/.quality/policy.json and ui/tests/test_module_compatibility.py.
- [X] T005 [P] Inspect site/docs/contributing.md, site/docs/deploy.md and related auth/continuity pages; record affected examples and keep unshipped guidance gated in the documentation PR.

## Phase 2: Foundational Policy Records

**Purpose**: Establish each repository's own tested tooling/records. Foundation
completion gates that repository's stories, not independent work in peers.

- [ ] T006 [P] Add exact compatible development tool pins and validated policy/scope/debt/exception record parsing in orchestrator/requirements-quality.txt, orchestrator/.quality/ and orchestrator/.github/scripts/check-quality.py.
- [ ] T007 [P] Add exact compatible development tool pins and validated policy/scope/debt/exception record parsing in ingestion/requirements-quality.txt, ingestion/.quality/ and ingestion/.github/scripts/check-quality.py.
- [ ] T008 [P] Add exact compatible development tool pins and validated policy/scope/debt/exception record parsing in ui/requirements-quality.txt, ui/.quality/ and ui/.github/scripts/check-quality.py.

**Checkpoint**: No blanket ignores, runtime dependency pollution, dynamic source
imports by checkers, or success-shaped parse-error fallbacks.

## Phase 3: US1 - Catch Quality Regressions Before Merge (P1, MVP)

**Goal**: Lint and incremental typing report actionable regressions without
silently accepting new debt or missing execution.

**Independent test**: Clean change passes; new lint/type findings, count-neutral
debt substitutions, lost coverage and failed/skipped tools cannot pass.

### Tests

- [ ] T009 [P] [US1] Add lint/type ratchet, suppression, move identity and failed-execution fixtures in orchestrator/tests/test_quality_policy.py.
- [ ] T010 [P] [US1] Add lint/type ratchet, suppression, move identity and failed-execution fixtures in ingestion/tests/test_quality_policy.py.
- [ ] T011 [P] [US1] Add equivalent unittest fixtures in ui/tests/test_quality_policy.py, including flat-to-package moves retaining coverage.

### Implementation

- [ ] T012 [P] [US1] Implement explicit Ruff/mypy settings, protected minimum typing scope, individual-finding baseline and structured reports in orchestrator/pyproject.toml, orchestrator/.quality/ and orchestrator/.github/scripts/check-quality.py.
- [ ] T013 [P] [US1] Implement equivalent flat-layout lint/type enforcement in ingestion/pyproject.toml, ingestion/.quality/ and ingestion/.github/scripts/check-quality.py.
- [ ] T014 [P] [US1] Implement equivalent UI lint/type enforcement and migration-safe scope in ui/pyproject.toml, ui/.quality/ and ui/.github/scripts/check-quality.py.
- [ ] T015 [P] [US1] Wire actual quality/test dependencies and always-evaluated quality-gate into orchestrator/.github/workflows/pr_pipeline.yaml; document separate rules activation without privileged PR execution.
- [ ] T016 [P] [US1] Wire equivalent quality-gate into ingestion/.github/workflows/tests.yml, preserving existing tests and any required frontend checks.
- [ ] T017 [P] [US1] Wire equivalent quality-gate into ui/.github/workflows/tests.yml, retaining unittest and reporting incomplete execution as failure.

**Checkpoint**: Workflow evidence is distinct from administrator-required merge
checks. Gate activation is not claimed merely because YAML exists.

## Phase 4: US2 - Enforce Dependency and Error Rules (P1)

**Goal**: Detect full static cycles, forbidden/private imports and unjustified
broad handlers; retain explicitly contracted failure outcomes.

**Independent test**: Positive public-facade imports pass; all Q6 graph/handler
mutations fail; dependency failures preserve public errors and safe diagnostics.

### Tests

- [ ] T018 [P] [US2] Add graph completeness, private-member, facade, dynamic-import and broad-handler fixtures in orchestrator/tests/test_quality_policy.py.
- [ ] T019 [P] [US2] Add equivalent flat-root and cross-root fixtures in ingestion/tests/test_quality_policy.py.
- [ ] T020 [P] [US2] Add equivalent flat/package/adapter and registration fixtures in ui/tests/test_quality_policy.py.

### Implementation

- [ ] T021 [P] [US2] Break Search/Foundry IQ OBO cycle through a focused same-repository helper in orchestrator/src/connectors/, retaining existing callable behavior and compatibility exports.
- [ ] T022 [P] [US2] Break api-to-main scheduler cycles through explicit jobs-owned state in ingestion/jobs/, ingestion/api/admin.py, ingestion/api/panel.py and ingestion/main.py without duplicating locks/registries.
- [ ] T023 [P] [US2] Extract citation/reference rendering from ui/app.py into ui/src/gpt_rag_ui/services/ and make ui/datalayer.py consume that owner without changing grants or source links.
- [ ] T024 [P] [US2] Implement full-graph/private-surface/exception-ledger enforcement in orchestrator/.github/scripts/check-quality.py and orchestrator/.quality/, narrowing or explicitly justifying existing handlers.
- [ ] T025 [P] [US2] Implement equivalent graph/exception enforcement in ingestion/.github/scripts/check-quality.py and ingestion/.quality/, preserving the narrowly best-effort audit contract.
- [ ] T026 [P] [US2] Implement equivalent graph/exception enforcement in ui/.github/scripts/check-quality.py and ui/.quality/, keeping disabled/not-ready and optional notification contracts explicit.
- [ ] T027 [P] [US2] Prove unchanged OBO/MCP/retrieval and orchestration failure outcomes in orchestrator/tests/test_foundry_iq_mcp.py, orchestrator/tests/test_orchestration_turn.py and existing audit tests.
- [ ] T028 [P] [US2] Prove scheduler, indexing/deletion/retrieval, config and strict-auth failure outcomes in ingestion/tests/test_admin_jobs_queue.py, ingestion/tests/test_admin_run_now.py and related existing public-boundary tests.
- [ ] T029 [P] [US2] Prove backend, auth/ownership, download, panel/store and configuration failure outcomes in ui/tests/test_download_security.py, ui/tests/test_panel_routes.py and related existing suites.

## Phase 5: US3 - Navigate a Modular Compatible UI (P2)

**Goal**: All runtime responsibilities belong to the package; roots are only
startup/public-import adapters; installed and deployed use remains compatible.

**Independent test**: Entire reviewed U4 matrix passes before/after, including
non-editable wheel installation outside a checkout and both import orders.

### Tests

- [ ] T030 [US3] Add non-editable distribution, asset-root, startup-order, canonical-state and old/new import-order acceptance tests in ui/tests/test_installed_package.py and ui/tests/test_module_compatibility.py.

### Implementation

- [ ] T031 [US3] Add setuptools src discovery and explicit legacy-module distribution in ui/pyproject.toml with inert ui/src/gpt_rag_ui/__init__.py; preserve requirements.txt as initial runtime dependency source.
- [ ] T032 [US3] Move configuration/cache/settings and pure helpers into ui/src/gpt_rag_ui/config/ and ui/src/gpt_rag_ui/util/, retaining one state owner and equivalent precedence/defaults.
- [ ] T033 [US3] Move identity primitives and backend/storage transports into ui/src/gpt_rag_ui/auth/ and ui/src/gpt_rag_ui/clients/, keeping identity and error behavior unchanged.
- [ ] T034 [US3] Move history, chat, continuity, feedback, ownership, cursor and download decisions into ui/src/gpt_rag_ui/services/ without business logic in adapters.
- [ ] T035 [US3] Move framework routes/callbacks and telemetry into ui/src/gpt_rag_ui/api/ and ui/src/gpt_rag_ui/telemetry/ with ordered single registration.
- [ ] T036 [US3] Implement ui/src/gpt_rag_ui/bootstrap.py and thin ui/main.py, ui/app.py and inventoried legacy adapters; preserve conditional hosted/panel initialization and staged asset roots.
- [ ] T037 [US3] Wire non-editable package installation into ui/Dockerfile and contributor startup without changing uvicorn main:app, existing deployment flags or Windows/Linux lifecycle behavior.
- [ ] T038 [US3] Move private test seams to canonical owners and prove the entire U4 matrix through ui/tests/ while retaining dedicated legacy compatibility assertions.

## Phase 6: US4 - Adopt and Recover Incrementally (P2)

**Goal**: Reviewed, independently usable changes in each repository, with exact
ref evidence and documentation/recovery instructions; no automatic merge.

**Independent test**: Each PR can run with unchanged shipped peers; its previous
artifact and recovery order are identified, with unavailable live evidence
clearly distinguished from successful local evidence.

- [ ] T039 [P] [US4] Update orchestrator/AGENTS.md and its PR with scope/exception commands, current SHA, peer compatibility, targeted evidence and recovery.
- [ ] T040 [P] [US4] Update ingestion/AGENTS.md and its PR with flat-layout ownership, gate commands, scheduler evidence and recovery.
- [ ] T041 [P] [US4] Update ui/AGENTS.md and its PR with ownership/import/resource inventory, packaging commands and rollback.
- [ ] T042 [US4] Update site/docs/contributing.md and affected operator examples in a PR targeting docs; do not publish proposed controls as already active.
- [ ] T043 [US4] Record all component/docs PR links, exact candidate SHAs, implemented task status, unavailable Azure evidence and the separate required-check administrative action in specs/001-python-module-boundaries/tasks.md and the umbrella PR.

## Phase 7: Polish and PR Handoff

- [ ] T044 Review specs/001-python-module-boundaries/plan.md and contracts/ against actual implementation; document justified refinements without silently reducing acceptance.
- [ ] T045 Validate all local links, strict task syntax, modified component suites and applicable existing asset/docs checks in specs/001-python-module-boundaries/quickstart.md and owning tests/.
- [ ] T046 Commit only scoped files and create/update the umbrella feature PR targeting develop, including docs/adr/ADR-0005-python-quality-gates-and-ui-package.md and specs/001-python-module-boundaries/.

## Dependencies and Execution Order

T001 authorizes the coordinated direction. T002/T003/T004/T005 are independent.
Each component's foundation depends on its inventory, not another component's
new code. US1 and US2 share that component's checker/test files: execute their
edits sequentially under one repository owner to avoid conflicting policies.

T023 uses the package skeleton from T031 and precedes the rest of the UI
composition migration. This is the explicit cross-story prerequisite; do not
introduce temporary duplicated citation business logic just to follow story
number order. T030/T031 can run once the UI inventory is frozen.

US3 proceeds in dependency order after the UI foundation and its graph contract.
T039/T040/T041 accompany their owning changes, not a later documentation cleanup.
T042 depends on verified component behavior. T043/T044/T045/T046 finalize the
coordinated handoff, with no dependency on unmerged companion runtime changes.

## Parallel Examples

| Story | Safe independent work |
| --- | --- |
| US1 | Orchestrator T009/T012/T015, ingestion T010/T013/T016 and UI T011/T014/T017 proceed under separate owners |
| US2 | Orchestrator OBO fix T021 and ingestion scheduler fix T022; each has independent regression tests |
| US3 | Remain sequential for source moves; resource/packaging tests can be reviewed separately after inventory without concurrent edits to the same modules |
| US4 | Component guidance/evidence T039/T040/T041 proceed independently; site update follows actual outcomes |

`[P]` means independent of peer-repository tasks once its own prerequisites are
complete, not permission to edit one component's checker concurrently.

## Implementation Strategy

The MVP is US1's runnable lint/type regression feedback plus protected-policy
design; full "required before merge" acceptance also needs administrator
activation. US2 makes complete architecture/error enforcement green before
claiming all quality jobs active. UI source moves follow in validated dependency
slices. Preserve deployability at each commit; publish independent component
PRs against develop rather than branches requiring an unmerged peer PR.

Keep related UI slices in one reviewable PR if separating them would require
unapproved merges to satisfy the no-unmerged-dependency rule. Record incremental
commits and recovery points. Do not create a stack that only works when several
unmerged branches are deployed together.

No task checkbox denotes release or production rollout. GitHub required-check
activation, live Azure integration and recovery rehearsal remain explicit
acceptance evidence outside this PR-only authorization if not otherwise
available. Never mark those outcomes passed based solely on local unit tests.

## Delivery Record

Maintainer direction was approved on 2026-09-06. The docs inventory at
`dfa448127a162b86c0836d374b9f2689c61d4ea7` identifies `docs/contributing.md`
as affected. No existing operator examples use the UI root Python imports or
installed-package commands; deployment/auth/continuity pages need no edits if
their contracted operator behavior remains unchanged. Component implementation
and PR evidence will be recorded here as each repository completes.

The umbrella feature inherits the Spec Kit/constitution installation commit
`507abf887eb42ef35b06647171ba1b6781dad4c6`, previously published on `main` but
not yet on `develop` when work began. The coordination PR includes that
prerequisite alongside the design/task artifacts; it does not republish a
release or change component pins.
