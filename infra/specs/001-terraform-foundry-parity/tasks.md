---

description: "Implementation tasks for Terraform parity coordination"
---

# Tasks: Terraform Parity for the Foundry AI Landing Zone

**Input**: Design documents from `specs/001-terraform-foundry-parity/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: The specification explicitly requires automated validation, scenario separation,
idempotency, and evidence integrity. Test tasks are therefore included and must be written before
the corresponding implementation.

**Organization**: Tasks are grouped by user story so each increment can be implemented and
validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and has no dependency on an
  incomplete task in the same phase
- **[Story]**: Maps the task to US1, US2, or US3 from `spec.md`
- Every task names the exact repository-relative file or directory it changes

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the repository layout and pinned validation tooling.

- [X] T001 Promote the four design schemas from `specs/001-terraform-foundry-parity/contracts/*.schema.json` into runtime contracts under `parity/schemas/`
- [X] T002 [P] Add a draft 2020-12-compatible JSON Schema validator pinned by exact version in `package.json` and `package-lock.json`
- [X] T003 [P] Create repository, branch, scenario, schema, and generated-view settings with the pinned v2.6.1/v0.5.1 commits in `parity/config.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement shared validation, error handling, and test infrastructure required by all
user stories.

**CRITICAL**: No user story implementation begins until this phase is complete.

- [X] T004 Create strict path resolution, JSON loading, stable sorting, atomic file writing, and explicit error helpers in `scripts/parity/Parity.Common.ps1`
- [X] T005 Implement schema discovery and validation against pinned local schemas in `scripts/parity/Test-ParityJson.ps1`
- [X] T006 [P] Write failing tests for malformed JSON, unknown fields, duplicate IDs, invalid SHAs, unsupported scenarios, and missing approval metadata in `tests/parity/Test-ParityJson.Tests.ps1`
- [X] T007 [P] Add sanitized source-PR, baseline, baseline-approval, capability, handoff, and evidence fixtures in `tests/parity/fixtures/`
- [X] T008 Implement the aggregate deterministic validator, including baseline, cross-record reference, scenario uniqueness, evidence-integrity, and sensitive-value checks, in `scripts/parity/Test-ParityAssets.ps1`
- [X] T009 Add dependency installation and shared parity test execution without Azure credentials to `.github/workflows/terraform-parity-validate.yml`

**Checkpoint**: Runtime contracts and deterministic validation are available for every story.

---

## Phase 3: User Story 1 - Understand the parity gap (Priority: P1) MVP

**Goal**: Publish a complete, version-pinned, machine-readable inventory and deterministic
human-readable parity view.

**Independent Test**: A platform engineer can answer whether Terraform supports a sampled
capability in each supported scenario, understand the consumer and compatibility impact, and
follow source evidence without reading either implementation.

### Tests for User Story 1

- [X] T010 [P] [US1] Write failing coverage tests for one active baseline, unique capability IDs, all consumer surfaces classified, and exactly two scenario assessments in `tests/parity/Test-InventoryCoverage.Tests.ps1`
- [X] T011 [P] [US1] Write failing contract tests for blocked reasons, compatibility migration fields, default differences, proposal references, and parity evidence gates in `tests/parity/Test-InventoryContract.Tests.ps1`
- [X] T012 [P] [US1] Write failing deterministic generation tests for ordering, Markdown escaping, generated timestamps, repeated execution, and drift detection in `tests/parity/Test-ParityMarkdown.Tests.ps1`

### Implementation for User Story 1

- [X] T013 [US1] Implement deterministic inventory-to-Markdown generation and `-Check` drift mode in `scripts/parity/Export-ParityMarkdown.ps1`
- [X] T014 [US1] Catalog every consumer-visible v2.6.1 Bicep input, default, allowed value, output, runtime key, identity/RBAC behavior, and network behavior in `parity/inventory.json`
- [X] T015 [US1] Compare each cataloged capability with Terraform v0.5.1 and complete source evidence, Terraform evidence, per-scenario support status, consumer impact, compatibility expectation, blocked reason, and ownership in `parity/inventory.json`
- [X] T016 [US1] Add validator coverage proving `manifest.json` still identifies the pinned source release while preventing silent baseline advancement in `tests/parity/Test-BaselineContract.Tests.ps1`
- [X] T017 [US1] Add generated inventory interpretation, status meanings, evidence levels, exclusions, and baseline-advancement guidance to `scripts/parity/Export-ParityMarkdown.ps1`
- [X] T018 [US1] Generate the first complete human-readable parity view from the inventory in `docs/terraform-parity.md`
- [X] T019 [US1] Add parity inventory and generated-document paths to pull-request and push validation filters in `.github/workflows/terraform-parity-validate.yml`
- [X] T020 [US1] Run the US1 commands from `specs/001-terraform-foundry-parity/quickstart.md` and create `specs/001-terraform-foundry-parity/validation.md` with each command, exit code, meaningful warnings, skipped checks, proof supplied, and residual risk

**Checkpoint**: User Story 1 is independently usable as the MVP, even before any Terraform proposal
is created.

---

## Phase 4: User Story 2 - Prepare Terraform parity proposals (Priority: P2)

**Goal**: Convert every actionable inventory gap into a human-reviewable Terraform proposal while
preserving compatibility and scenario-specific evidence requirements.

**Independent Test**: Every `partial`, `absent`, or actionable `blocked` inventory entry has an
approved, schema-valid handoff and a corresponding draft pull request or reviewed deferral in the
Terraform repository; no Terraform source exists in this repository.

### Tests for User Story 2

- [X] T021 [P] [US2] Write failing tests that prohibit parity declarations from static validation, Terraform plan, or evidence from the other scenario in `tests/parity/Test-EvidenceIntegrity.Tests.ps1`
- [X] T022 [P] [US2] Write failing handoff contract tests for exactly one provenance form, compatibility, migration, semantic-version, AVM, scenario, identity, RBAC, networking, exclusion, and approval fields in `tests/parity/Test-TerraformHandoff.Tests.ps1`
- [X] T023 [P] [US2] Write failing tests that reject Terraform source, credentials, tenant IDs, subscription IDs, private addresses, and environment resource names in `tests/parity/Test-HandoffSensitiveContent.Tests.ps1`

### Implementation for User Story 2

- [X] T024 [US2] Implement pending baseline-inventory or approved alignment-assessment-to-handoff generation with exact inventory digest and invalid provenance, stale-baseline, unknown-capability, duplicate-active-handoff, and sensitive-content failures in `scripts/parity/New-TerraformHandoff.ps1`
- [X] T025 [P] [US2] Create schema-valid pending draft handoffs for AI Foundry account, project, model, connection, and nested-resource gaps under `parity/handoffs/ai-foundry/`
- [X] T026 [P] [US2] Create schema-valid pending draft handoffs for VNet, subnet, NSG, route, firewall, Bastion, private endpoint, private DNS, ingress, and isolation gaps under `parity/handoffs/networking/`
- [X] T027 [P] [US2] Create schema-valid pending draft handoffs for managed identity, control-plane RBAC, data-plane RBAC, local-auth, and secret-handling gaps under `parity/handoffs/security/`
- [X] T028 [P] [US2] Create schema-valid pending draft handoffs for Container Apps, runtime configuration, App Configuration, registry, and deployment-shaping gaps under `parity/handoffs/application-platform/`
- [X] T029 [P] [US2] Create schema-valid pending draft handoffs for storage, Cosmos DB, Search, Bing grounding, monitoring, and remaining service gaps under `parity/handoffs/data-and-ai-services/`
- [X] T030 [US2] Add a read-only Terraform parity coding-agent profile that consumes only approved handoffs and cannot merge or deploy in `.github/agents/terraform-parity.agent.md`
- [X] T031 [US2] Add the agent workflow, acceptance checklist, target-repository boundary, and exit conditions in `.github/skills/terraform-parity-proposal/SKILL.md`
- [X] T032 [US2] Validate the new agent and skill surfaces through `.github/scripts/Validate-CopilotAssets.ps1` and add focused cases to `tests/scripts/Validate-CopilotAssets.Tests.ps1`
- [X] T033 [US2] After explicit human approval, use the approved initial-baseline handoffs and the target repository's existing contribution path to raise draft proposals covering 100 percent of actionable gaps in `Azure/terraform-azurerm-avm-ptn-aiml-landing-zone`, then record each proposal URL or reviewed deferral in `parity/inventory.json`; do not depend on the ongoing dispatch workflow introduced in US3

**Checkpoint**: User Story 2 satisfies this feature's definition of done for gap proposals. Merging,
deploying, and recording parity evidence remain target-repository follow-up work.

---

## Phase 5: User Story 3 - Keep both implementations aligned over time (Priority: P3)

**Goal**: Assess every PR merged into `develop`, preserve no-impact decisions, and dispatch approved
structured handoffs without restating the change manually.

**Independent Test**: Processing representative merged-PR fixtures creates exactly one traceable
assessment; no-impact changes close with rationale; impacted changes remain blocked until approval
and then produce exactly one target proposal reference.

### Tests for User Story 3

- [X] T034 [P] [US3] Write failing tests for merged-PR assessment creation, supported outcomes, immutable traceability, supersession, duplicate delivery, and serialized append-only ledger writes in `tests/parity/Test-AlignmentAssessment.Tests.ps1`
- [X] T035 [P] [US3] Write failing event contract tests for `develop` branch filtering, merged-only handling, trusted commit checkout, dedicated ledger persistence, prohibited direct `develop` writes, and explicit workflow failures in `tests/parity/Test-WorkflowEventContract.Tests.ps1`
- [X] T036 [P] [US3] Write failing publication tests for protected-environment approval, configured repository and branch allow-lists, stale baseline, missing gaps, duplicate proposal, and target rejection in `tests/parity/Test-ParityPublication.Tests.ps1`
- [X] T037 [P] [US3] Write failing workflow security tests for least-privilege permissions, immutable action pins, prohibited PR-head execution, bounded dispatch payloads, and absent secrets in `tests/parity/Test-WorkflowSecurity.Tests.ps1`

### Implementation for User Story 3

- [X] T038 [US3] Implement idempotent merged-PR assessment creation keyed by repository, PR number, and merge SHA in `scripts/parity/New-AlignmentAssessment.ps1`
- [X] T039 [US3] Implement assessment finalization for no-impact, inventory-update, proposal-required, blocked, deferred, rejected, and superseded outcomes in `scripts/parity/Set-AlignmentAssessment.ps1`
- [X] T040 [US3] Implement provenance-aware bounded repository-dispatch payload creation and duplicate proposal reconciliation in `scripts/parity/Publish-TerraformHandoff.ps1`
- [X] T041 [US3] Add the merged pull-request workflow for `develop`, using trusted metadata, serialized concurrency, and append-only commits to the dedicated `terraform-parity-assessments` ledger branch without direct pushes to `develop` or cross-repository credentials, in `.github/workflows/terraform-parity-assess.yml`
- [X] T042 [US3] Add the protected-environment publication workflow that mints a single-repository GitHub App token only after approval in `.github/workflows/terraform-parity-publish.yml`
- [X] T043 [US3] Extend parity validation to read the dedicated ledger branch and prove every `develop` merge after the adoption marker has exactly one assessment in `.github/workflows/terraform-parity-validate.yml`
- [X] T044 [US3] Document Bicep, Terraform, cross-parity, approval, baseline, rejected-proposal, incident, and cleanup ownership in `docs/terraform-parity-ownership.md`
- [X] T045 [US3] Document the minimum GitHub App permissions, protected environment reviewers, key rotation, audit, revocation, and break-glass prohibition in `docs/terraform-parity-ownership.md`
- [X] T046 [US3] Create the adoption marker and backfill hand-assessed assessments, each with a recorded outcome and rationale and `review.status=pending` until a parity reviewer approves it, for the bounded set of `develop` merges selected before workflow activation under `parity/assessments/` on the dedicated ledger branch
- [X] T047 [US3] Prepare a reviewable Terraform-repository proposal for the receiving `repository_dispatch` workflow and coding-agent instructions under `Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/.github/`
- [X] T048 [US3] Add an end-to-end fixture test proving merged PR to assessment to approval to handoff to proposal-reference traceability in `tests/parity/Invoke-ParityWorkflow.Tests.ps1`

**Checkpoint**: All three user stories are independently functional. Ongoing Bicep changes cannot
be silently skipped after adoption.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Harden and document the complete coordination feature.

- [X] T049 [P] Update contributor-facing parity workflow, inventory, generated-document, and approval guidance in `README.md`
- [X] T050 [P] Add the coordination feature, compatibility impact, follow-up deployment boundary, and rollback guidance to the Unreleased section of `CHANGELOG.md`
- [X] T051 Pin every third-party action used by parity workflows to an immutable commit and verify minimum job-level permissions in `.github/workflows/terraform-parity-*.yml`
- [X] T052 Run sensitive-value and secret scanning across `parity/`, `tests/parity/fixtures/`, and parity workflow logs, and document exclusions in `scripts/parity/Test-ParityAssets.ps1`
- [X] T053 Prove complete inventory validation and Markdown generation finish within 60 seconds and record the timing assertion in `tests/parity/Test-ParityPerformance.Tests.ps1`
- [X] T054 Execute every command in `specs/001-terraform-foundry-parity/quickstart.md`, append commands, exit codes, meaningful warnings, skipped checks, proof supplied, and residual risks to `specs/001-terraform-foundry-parity/validation.md`, and confirm no Azure deployment was performed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup and blocks all stories.
- **US1 (Phase 3)**: Depends on Foundational; produces the inventory that US2 and US3 consume.
- **US2 (Phase 4)**: Depends on US1 because initial catch-up handoffs reference the reviewed,
  immutable inventory baseline; it does not depend on US3 assessments or dispatch.
- **US3 (Phase 5)**: Depends on US1 for the inventory and US2's provenance-aware handoff generator;
  its assessment tests and scripts may begin after Foundational while integration waits for US2.
- **Polish (Phase 6)**: Depends on all selected story phases.

### User Story Completion Order

```text
Setup -> Foundation -> US1 (MVP) -> US2 -> US3 -> Polish
                           \----------------> US3 assessment work
```

### Within Each User Story

- Write the listed tests first and confirm they fail for the intended missing behavior.
- Implement schemas and entities before scripts that consume them.
- Implement deterministic scripts before workflows that invoke them.
- Complete local fixture validation before enabling write permissions or cross-repository dispatch.
- Obtain explicit human approval before T033 or any live publication step.

### Parallel Opportunities

- T002 and T003 can run in parallel.
- T006 and T007 can run in parallel after T004/T005 interfaces are agreed.
- T010, T011, and T012 can run in parallel.
- T025 through T029 can run in parallel after T024 and the inventory are complete.
- T034 through T037 can run in parallel.
- T049 and T050 can run in parallel after the story phases.

---

## Parallel Example: User Story 1

```text
Task: "T010 Write inventory coverage tests in tests/parity/Test-InventoryCoverage.Tests.ps1"
Task: "T011 Write inventory contract tests in tests/parity/Test-InventoryContract.Tests.ps1"
Task: "T012 Write Markdown generation tests in tests/parity/Test-ParityMarkdown.Tests.ps1"
```

## Parallel Example: User Story 2

```text
Task: "T025 Create AI Foundry handoffs under parity/handoffs/ai-foundry/"
Task: "T026 Create networking handoffs under parity/handoffs/networking/"
Task: "T027 Create security handoffs under parity/handoffs/security/"
Task: "T028 Create application-platform handoffs under parity/handoffs/application-platform/"
Task: "T029 Create data and AI service handoffs under parity/handoffs/data-and-ai-services/"
```

## Parallel Example: User Story 3

```text
Task: "T034 Write assessment tests in tests/parity/Test-AlignmentAssessment.Tests.ps1"
Task: "T035 Write event contract tests in tests/parity/Test-WorkflowEventContract.Tests.ps1"
Task: "T036 Write publication tests in tests/parity/Test-ParityPublication.Tests.ps1"
Task: "T037 Write workflow security tests in tests/parity/Test-WorkflowSecurity.Tests.ps1"
```

---

## Implementation Strategy

### MVP First: User Story 1

1. Complete Setup and Foundational phases.
2. Complete US1 tests, inventory, generator, and generated documentation.
3. Stop and validate US1 independently with the quickstart.
4. Publish the inventory as a useful standalone parity decision aid.

### Incremental Delivery

1. **US1**: Make the gaps visible and reproducible.
2. **US2**: Turn every actionable gap into a reviewed Terraform proposal.
3. **US3**: Prevent future divergence with per-merge assessments and approved handoffs.
4. **Follow-up outside this feature**: Merge Terraform proposals, deploy both scenarios in an
   approved test subscription, and record reviewed parity evidence.

### Parallel Team Strategy

After Foundation:

- Inventory owner drives US1.
- Test and contract owner prepares US2 and US3 failing tests against the frozen schemas.
- Documentation owner prepares ownership and contributor guidance.
- Cross-repository publication remains serialized behind the human approval gate.

## Notes

- `[P]` tasks intentionally touch different files or independent handoff directories.
- No task adds Terraform source to this repository.
- No task treats static validation, Bicep What-If, or Terraform plan as parity evidence.
- Live cross-repository publication and Azure deployment always require explicit human approval.
- A rejected proposal leaves its inventory gap open until superseded by a reviewed decision.
