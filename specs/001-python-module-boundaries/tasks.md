# Tasks: Enforce Module Boundaries and Modularize the UI

**Input**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [quality contract](contracts/quality-gates.md),
[UI contract](contracts/ui-compatibility.md), [quickstart.md](quickstart.md).

**Prerequisites**: Read the approved plan, spec, constitution 1.0.0 and the owning
repository's instructions. Use Python 3.12 and the existing component test runner.
This task-generation refresh preserves all 46 IDs, repository assignments and
previously recorded completion markers; it does not certify implementation.

**Organization**: Setup, component-local foundations, four user-story phases in
spec priority order, then cross-repository handoff. Start pending work with
`- [ ]`; keep `[X]` only where delivery evidence already exists.

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

| Design record / contract | Creation and enforcement tasks |
| --- | --- |
| RepositoryPolicy and ModuleSurface in `.quality/policy.json` | T002-T004 inventory; T006-T008 parsing; T024-T026 architecture/ownership enforcement |
| TypingScope and TypingBaselineEntry in `.quality/typing-scope.json` and `.quality/typing-baseline.json` | T006-T008 parsing; T009-T014 identity, scope and diagnostic ratchet |
| ExceptionJustification in `.quality/exceptions.json` | T006-T008 parsing; T018-T020 fixtures; T024-T029 exact-site approval and failure behavior |
| CheckRun artifacts and quality contract Q1/Q5 | T009-T017 structured outputs, protected evaluator and fail-closed aggregation |
| UI ownership, imports, resources and matrix U1-U4 | T004 inventory; T023 citation owner; T030-T038 package migration/acceptance |
| DeliveryEvidence and documentation | T039-T043 component/site PRs, exact refs, recovery and outstanding acceptance |

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

- [ ] T006 [P] Add exact compatible development tool pins and schema-validated policy.json, typing-scope.json, typing-baseline.json and exceptions.json records in orchestrator/requirements-quality.txt, orchestrator/.quality/ and orchestrator/.github/scripts/check-quality.py; reject missing/unknown/invalid records per data-model.md.
- [ ] T007 [P] Add equivalent exact pins and validated four-record parsing in ingestion/requirements-quality.txt, ingestion/.quality/ and ingestion/.github/scripts/check-quality.py, preserving flat-module discovery.
- [ ] T008 [P] Add equivalent exact pins and validated four-record parsing in ui/requirements-quality.txt, ui/.quality/ and ui/.github/scripts/check-quality.py, preserving stable identities for legacy/package moves.

**Checkpoint**: No blanket ignores, runtime dependency pollution, dynamic source
imports by checkers, or success-shaped parse-error fallbacks.

## Phase 3: US1 - Catch Quality Regressions Before Merge (P1, MVP)

**Goal**: Lint and incremental typing report actionable regressions without
silently accepting new debt or missing execution.

**Independent test**: In each repository, a clean lint/type change passes;
new findings, count-neutral debt substitutions, lost coverage, and failed/skipped
execution cannot pass. Exercise Q6 through the existing runner and test aggregate
job/artifact integrity. Real merge-eligibility acceptance additionally requires
the complete US2 policy and separately authorized administrative activation.

### Tests

- [ ] T009 [P] [US1] Add Q6 lint/type ratchet, suppression, move identity and tool-error fixtures in orchestrator/tests/test_quality_policy.py; cover missing/skipped/neutral jobs, stale/wrong-SHA artifacts and candidate self-approval attempts before implementing the checker/aggregate.
- [ ] T010 [P] [US1] Add equivalent Q6 lint/type, suppression, move, tool-error and job/artifact/policy-integrity fixtures in ingestion/tests/test_quality_policy.py.
- [ ] T011 [P] [US1] Add equivalent unittest fixtures in ui/tests/test_quality_policy.py, including flat-to-package moves retaining coverage and aggregate/policy tampering rejection.

### Implementation

- [ ] T012 [P] [US1] Implement explicit Ruff/mypy settings, protected minimum typing scope, individual-finding baseline and structured reports in orchestrator/pyproject.toml, orchestrator/.quality/ and orchestrator/.github/scripts/check-quality.py.
- [ ] T013 [P] [US1] Implement equivalent flat-layout lint/type enforcement in ingestion/pyproject.toml, ingestion/.quality/ and ingestion/.github/scripts/check-quality.py.
- [ ] T014 [P] [US1] Implement equivalent UI lint/type enforcement and migration-safe scope in ui/pyproject.toml, ui/.quality/ and ui/.github/scripts/check-quality.py.
- [ ] T015 [P] [US1] Wire the protected-base evaluator, actual same-workflow dependencies and always-evaluated quality-gate into orchestrator/.github/workflows/pr_pipeline.yaml; pin action SHAs, preserve frontend/tests, protect policy/workflow/tool files in orchestrator/.github/CODEOWNERS using verified maintainers, and document separate latest-head review/rules activation without privileged PR execution.
- [ ] T016 [P] [US1] Wire equivalent protected-base quality-gate and policy ownership in ingestion/.github/workflows/tests.yml and ingestion/.github/CODEOWNERS, preserving existing tests/frontend checks and rejecting incomplete job/artifact evidence.
- [ ] T017 [P] [US1] Wire equivalent protected-base quality-gate and policy ownership in ui/.github/workflows/tests.yml and ui/.github/CODEOWNERS, retaining unittest and reporting incomplete execution as failure.

**Checkpoint**: Workflow evidence is distinct from administrator-required merge
checks. Gate activation is not claimed merely because YAML exists.

## Phase 4: US2 - Enforce Dependency and Error Rules (P1)

**Goal**: Detect full static cycles, forbidden/private imports and unjustified
broad handlers; retain explicitly contracted failure outcomes.

**Independent test**: Positive public-facade imports pass; all Q6 graph/handler
mutations fail, including delayed/type-only imports and Ruff-exempt broad
handlers. Dependency failures preserve public errors and safe diagnostics.

### Tests

- [ ] T018 [P] [US2] Add Q6 full-graph, cross-root/late/type-only cycle, private-member, legitimate facade/sibling, dynamic-import and broad-handler fixtures in orchestrator/tests/test_quality_policy.py; include aliases, tuples, exception groups, logged/re-raised handlers and stale or unexecuted exception evidence.
- [ ] T019 [P] [US2] Add equivalent flat-root and cross-root fixtures in ingestion/tests/test_quality_policy.py.
- [ ] T020 [P] [US2] Add equivalent flat/package/adapter and registration fixtures in ui/tests/test_quality_policy.py.

### Implementation

- [X] T021 [P] [US2] Break Search/Foundry IQ OBO cycle through a focused same-repository helper in orchestrator/src/connectors/, retaining existing callable behavior and compatibility exports.
- [X] T022 [P] [US2] Break api-to-main scheduler cycles through explicit jobs-owned state in ingestion/jobs/, ingestion/api/admin.py, ingestion/api/panel.py and ingestion/main.py without duplicating locks/registries.
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
non-editable wheel installation outside a checkout, both import orders,
single-owner state/callback registration, staged resources and Linux container
parity. No result may rely on editable installation or source-path leakage.

### Tests

- [ ] T030 [US3] Add non-editable distribution, asset-root, startup-order, canonical-state and old/new import-order acceptance tests in ui/tests/test_installed_package.py and ui/tests/test_module_compatibility.py.

### Implementation

- [ ] T031 [US3] Add setuptools src discovery and explicit legacy-module distribution in ui/pyproject.toml with inert ui/src/gpt_rag_ui/__init__.py; preserve requirements.txt as initial runtime dependency source.
- [ ] T032 [US3] Move configuration/cache/settings and pure helpers into ui/src/gpt_rag_ui/config/ and ui/src/gpt_rag_ui/util/, retaining one state owner and equivalent precedence/defaults.
- [ ] T033 [US3] Move identity primitives and backend/storage transports into ui/src/gpt_rag_ui/auth/ and ui/src/gpt_rag_ui/clients/, keeping identity and error behavior unchanged.
- [ ] T034 [US3] Move history, chat, continuity, feedback, ownership, cursor and download decisions into ui/src/gpt_rag_ui/services/ without business logic in adapters.
- [ ] T035 [US3] Move framework routes/callbacks and telemetry into ui/src/gpt_rag_ui/api/ and ui/src/gpt_rag_ui/telemetry/ with ordered single registration.
- [ ] T036 [US3] Implement ui/src/gpt_rag_ui/bootstrap.py and thin ui/main.py, ui/app.py and inventoried legacy adapters; preserve conditional hosted/panel initialization and staged asset roots.
- [ ] T037 [US3] Wire non-editable package installation into ui/Dockerfile and contributor startup; exercise existing Linux-image startup/resource cases without changing uvicorn main:app, deployment flags or Windows/Linux lifecycle behavior, and record unavailable container execution as pending evidence.
- [ ] T038 [US3] Move private test seams to canonical owners and prove the entire U4 matrix through ui/tests/ while retaining dedicated legacy compatibility assertions.

## Phase 6: US4 - Adopt and Recover Incrementally (P2)

**Goal**: Reviewed, independently usable changes in each repository, with exact
ref evidence and documentation/recovery instructions; no automatic merge.

**Independent test**: Each PR can run with unchanged shipped peers; its previous
artifact and recovery order are identified, with unavailable live evidence
clearly distinguished from successful local evidence.

### Implementation and delivery evidence

- [X] T039 [P] [US4] Update orchestrator/AGENTS.md and its PR with scope/exception commands, current SHA, peer compatibility, targeted evidence and recovery.
- [X] T040 [P] [US4] Update ingestion/AGENTS.md and its PR with flat-layout ownership, gate commands, scheduler evidence and recovery.
- [X] T041 [P] [US4] Update ui/AGENTS.md and its PR with ownership/import/resource inventory, packaging commands and rollback.
- [X] T042 [US4] Update site/docs/contributing.md and affected operator examples in a PR targeting docs; do not publish proposed controls as already active.
- [ ] T043 [US4] Record all component/docs PRs, exact candidate and preceding compatible SHAs, integration/rollback order, before/after scenario evidence and task status in specs/001-python-module-boundaries/tasks.md and the umbrella PR; explicitly track blocked live integration/recovery and administrative clean/failing-PR merge-eligibility evidence without changing settings or deploying.

## Phase 7: Polish and PR Handoff

**Purpose**: Reconcile artifacts with demonstrated outcomes and preserve a
reviewable PR record. Recording blocked acceptance does not satisfy that
acceptance criterion.

- [ ] T044 Review specs/001-python-module-boundaries/plan.md and contracts/ against actual implementation; document justified refinements without silently reducing acceptance.
- [ ] T045 Validate links/task syntax and run the final existing full component suites, applicable frontend checks, UI package/container cases and existing asset/docs checks from specs/001-python-module-boundaries/quickstart.md in the owning tests/ and workflows; record commands, SHAs, outcomes and unavailable evidence separately.
- [X] T046 Commit only scoped files and create/update the umbrella feature PR targeting develop, including docs/adr/ADR-0005-python-quality-gates-and-ui-package.md and specs/001-python-module-boundaries/.

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
T042 depends on verified component behavior. T043/T044/T045 finalize the
coordinated handoff, with no dependency on unmerged companion runtime changes.
T046 opened the initial draft coordination PR early; its checked state means
only that PR exists. T043 owns updating the same PR with final delivery evidence.

### Dependency graph

Arrows denote implementation prerequisites, not new task IDs or permission to
merge. US1's local code/fixture milestone unblocks US2; do not wait for
administrative merge-eligibility acceptance before implementing US2.

```text
T001
  -> T002 -> T006 -> US1 orchestrator -> US2 orchestrator -> T039
  -> T003 -> T007 -> US1 ingestion    -> US2 ingestion    -> T040
  -> T004 -> T008 -> US1 UI          -> US2 UI -> US3 UI  -> T041
  -> T005 ------------------------------------------------> T042

UI preparation: T004 + T008 -> T030 -> T031 -> T023
T039 + T040 + T041 + verified component outcomes -> T042
T039 + T040 + T041 + T042 -> T043 -> T044 -> T045
T046: draft PR already opened; T043 updates its final evidence
```

The early US3 preparation tasks T030/T031 unblock US2's citation extraction;
the rest of US3 follows the established UI graph contract. This is not a cycle
between entire stories. Within each repository, keep its checker/test edits
serial: US1 fixtures precede lint/type implementation, which precedes workflow
wiring; US2 fixtures precede cycle repair/enforcement and public-boundary
regressions. US3 moves follow T032 -> T033 -> T034 -> T035 -> T036 -> T037 -> T038.

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
activation and the complete US2 policy. US2 makes architecture/error enforcement
green before claiming all quality jobs active. UI source moves follow in validated dependency
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

## Acceptance Coverage

| Story | Requirements / outcomes | Executable evidence |
| --- | --- | --- |
| US1 | FR-001-FR-004; SC-001 | T009-T017 and Q6 ratchet/execution/tampering fixtures; T043 records real rule activation and PR eligibility separately |
| US2 | FR-005-FR-008, FR-012, FR-014; SC-002/SC-003 | T018-T029 and Q3/Q4/Q6; complete graph, exact handler justification and existing public-failure outcomes |
| US3 | FR-009-FR-012, FR-015; SC-004/SC-005/SC-007 | T004, T023, T030-T038, T041; every U4 row, adapter/source inventory, installed bundle, container and ownership review |
| US4 | FR-013-FR-015; SC-006 | T039-T043; exact-ref peer compatibility, recovery result or explicit blocked prerequisite, docs impact and PR-only handoff |

## Delivery Record

Maintainer direction was approved on 2026-09-06. The docs inventory at
`dfa448127a162b86c0836d374b9f2689c61d4ea7` identifies `docs/contributing.md`
as affected. No existing operator examples use the UI root Python imports or
installed-package commands; deployment/auth/continuity pages need no edits if
their contracted operator behavior remains unchanged. The following records
are implementation checkpoints, not final component acceptance.

The umbrella feature inherits the Spec Kit/constitution installation commit
`507abf887eb42ef35b06647171ba1b6781dad4c6`, previously published on `main` but
not yet on `develop` when work began. The coordination PR includes that
prerequisite alongside the design/task artifacts; it does not republish a
release or change component pins.

| Review surface | PR / status | Checkpoint |
| --- | --- | --- |
| Umbrella coordination | [#689](https://github.com/Azure/GPT-RAG/pull/689), draft, target `develop` | Specification, decisions and delivery evidence; no runtime or manifest changes |
| Contributor site | [#688](https://github.com/Azure/GPT-RAG/pull/688), draft, target `docs`; all three checkpoint interfaces and UI ownership/setup recorded, publication gated | `10ecf1a9a1ea61a5b9e7f733785fd93294bcbbea` |
| Orchestrator | [Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346), draft, target `develop` | `ef649eeab6144156b4c90c4422d62f229454dedc`, base `c6d0ccb01a40071f82f30bd17c9fe566b3d0ad18` |
| Ingestion | [Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296), draft, target `develop` | `bbe52923dbaf2b8ce4f6f371e492ad32ae7ffe45`, base `38a395586ee1d440a8e1ca8233413f8c25b3fdc2` |
| UI | [Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110), draft, target `develop` | `4959ecaf04ea94ce0d35837c73b43ea3884c5be8`, base `c635bc6696714b543feec24b4a062a8a8f3ff6d0` |

At those component revisions, the owners report:

| Surface | Existing runner / selected results | Explicitly incomplete acceptance |
| --- | --- | --- |
| Orchestrator | 840 pytest cases passed, including 83 quality fixtures; 5/78 modules in blocking typing, zero baseline entries; graph 78 modules / 196 edges | 100 BLE001 findings, 154 unapproved broad handlers, empty exception ledger and bootstrap policy failure |
| Ingestion | 295 pytest cases passed; three modules in blocking typing, zero baseline entries, 354 imported diagnostics visible; graph 53 nodes / 145 edges | 131 Ruff findings, 218 unapproved broad handlers, empty exception ledger and nine bootstrap/protected-policy findings |
| UI | 436 unittest cases passed, including 17 policy, three compatibility and six installed-package cases; typing/architecture passed, 119 imported diagnostics visible | 20 BLE001 findings, 62 unapproved broad/unsupported handlers, empty exception ledger and bootstrap failure; clean dependencies, expanded installed matrix and Linux container parity pending |

The UI full suite ran at `34273fffb1da549252e82ed0337e3cdd22636042`;
`4959eca` only restores README line endings and removes two extra EOF blanks.
The [remote UI workflow](https://github.com/Azure/gpt-rag-ui/actions/runs/34040530051)
also passed unit tests, typing and architecture at `4959eca`, while lint,
exceptions, policy and the aggregate failed. The installed environments at that
checkpoint reuse system-site third-party packages; they do not prove clean
dependency resolution.

Parent source review of the backend cycle-removal diffs and their regression
fixtures supports T021/T022: Search retains its public OBO wrappers and scope
cache behavior; main and API share the jobs-owned scheduler, registry and lock.
The published contributor/PR handoffs support T039-T042 for these exact
checkpoints only. They do not close the independent checker, failure, installed
matrix or activation tasks. T043/T044 must reconcile subsequent fix commits and
refresh documentation again when their interfaces or outcomes change.

Exact reproduction interfaces and the tested tool-version refinement are in
[quickstart.md](quickstart.md#backend-checkpoint-reproduction) and
[research.md](research.md#implementation-checkpoints). Backend checker/workflow
review and representative public-failure-contract assessment are still pending;
passing local suites does not certify all Q6 cases. A scoped exception proposal
is not actual maintainer approval. The site preview must not be published as
shipped enforcement while these conditions remain unresolved.

Unchecked tasks are intentionally not represented as completed by the existence
of the coordination PR. Required rules activation, live integration and live
recovery have not been performed.
