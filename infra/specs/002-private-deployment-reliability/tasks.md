---
description: "Dependency-ordered implementation tasks for issues 159 and 160"
---

# Tasks: Reproducible private deployments

**Input**: Design documents in `specs/002-private-deployment-reliability/`.
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md),
[research.md](research.md), [data-model.md](data-model.md),
[ACR contract](contracts/acr-subnet-ordering.md),
[Storage contract](contracts/solution-storage-inputs.md), and
[quickstart.md](quickstart.md).
**Branch**: `placerda-private-deployment-plan`
**Issues**: [#159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159)
and [#160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160).
**Status**: Local implementation and combined validation complete: 32/36
tasks, including all 15 parallel-marked tasks. Azure acceptance and companion
publication remain separately gated. The user requested the release workflow next.

**Tests**: Required by FR-159-03, the Storage verification contract, and the
specification's independent acceptance scenarios. Write focused contracts
before product changes and demonstrate the expected regression failures.

## Format and path conventions

Every task uses a checkbox, sequential ID, optional `[P]`, optional story label,
and an exact target/reference file path. `[P]` means a task can run concurrently
with the identified independent work after its prerequisites are complete;
it never authorizes editing a shared file concurrently.

Paths are repository-relative unless prefixed with `Azure/AI-Landing-Zones:`,
which identifies a separate repository. Resolve absolute paths before file
operations and use Windows path separators in PowerShell commands. Evidence
belongs in the implementation review or session artifacts, with references
recorded against task IDs here; never commit credentials or live tenant or
subscription IDs.

**Execution boundaries:** This list does not grant approval to merge shared
branches, provision Azure resources, create scanners/roles, publish cross-repo
changes, or release. Approval-gated tasks remain unchecked when authorization
or an eligible environment is missing; record their blocker. Local implementation
can proceed while live acceptance is pending, once the foundational gate is
met. Do not mark an issue fully accepted from offline evidence alone.

## Phase 1: Setup

**Purpose:** Load applicable rules and reproduce the planned toolchain without
changing product scope or disturbing existing work.

- [X] T001 Read `AGENTS.md`, `.specify/memory/constitution.md`, and `.github/instructions/bicep.instructions.md`, `parameters-contracts.instructions.md`, `powershell.instructions.md`, `pipelines.instructions.md`, and `release.instructions.md` before editing their matching surfaces; preserve existing planning/user edits and use the engineering-principles, documentation-consistency and iac-validation procedures during implementation.
- [X] T002 Check PowerShell 7 and the compiler version required by `tests/contracts/fixtures/hosted-agent-resource-graph.json`; confirm Azure CLI Bicep 0.42.1 separately from standalone Bicep, and use the Azure CLI-built `main.json` with `scripts/Measure-MainJsonSize.ps1 -SkipBuild`; restore/install tooling only on a demonstrated missing-tool/dependency failure, without upgrading AVM pins.

## Phase 2: Foundational prerequisites

**Purpose:** Establish the release-compatible source baseline and existing
regression evidence before either story changes infrastructure.

- [X] T003 Recheck live `main`/`develop` ancestry and resolve the synchronization entry gate in `specs/002-private-deployment-reliability/plan.md`: if `develop` is still behind, obtain the normal reviewed `main`-to-`develop` synchronization rather than modifying a shared branch without approval; refresh the implementation worktree base while preserving its artifacts and record exact new SHAs and the gate result in `plan.md`; stop product edits if this prerequisite remains blocked.
- [X] T004 On the synchronized baseline, compile/lint `main.bicep`, measure its compiled file with `scripts/Measure-MainJsonSize.ps1 -SkipBuild`, and run `tests/contracts/Test-HostedAgentContract.ps1`, `Test-AcrTaskAgentPoolFirewallContract.ps1`, `Test-ComponentDeploymentFlagsContract.ps1`, and `tests/scripts/Invoke-PreflightChecks.Tests.ps1`; capture warnings, exit codes and baseline graph/module parameters in session evidence, reconcile relevant source drift against both feature contracts, and investigate blocking baseline failures without fixing unrelated defects.

**Checkpoint:** Both stories may start after T001-T004. Retain a baseline
snapshot for red tests and unchanged-field comparisons. Live-environment
approval is not a prerequisite for writing local tests or implementation.

## Phase 3: US1 - Provision a private build pool on the first attempt (P1, MVP)

**Goal:** Fix #159 without changing topology or requiring a retry.

**Independent test:** The compiled pool has the required BYO dependency and
preserves the existing gates. An approved A1 cold start proves subnet completion
before pool start and pool `Succeeded` at S1 / 1, with unrelated subnets unchanged.

### Tests first

- [X] T005 [P] [US1] Create `tests/contracts/Test-AcrTaskAgentPoolSubnetContract.ps1` using the existing compile-to-unique-temp-file/explicit-failure/finally-cleanup pattern; assert the exact symbolic pool-to-`virtualNetworkSubnets` dependency, registry/new-VNet dependencies, gate truth table A1-A9, subnet ID, tier/count 0 and 1, disabled output/handoff, existing NSG rejection and serialized cross-scope child subnet behavior; run against the T004 baseline and confirm failure specifically for the missing edge, not a compiler/tool error.

### Implementation and integration

- [X] T006 [US1] Add the direct symbolic `virtualNetworkSubnets` entry to `acrTaskAgentPool.dependsOn` in `main.bicep`; preserve parent ACR, implicit new-VNet dependency, all conditions, subnet ID and properties, relying on ARM to discard dependencies on skipped modules; do not add module outputs, sleeps, public access or firewall changes; make T005 pass.
- [X] T007 [US1] After the focused contract passes, add only `acrTaskAgentPool` to `allowedPostBaselineMutations` in `tests/contracts/fixtures/hosted-agent-resource-graph.json`; preserve its compiler version, historical hashes and other exceptions, and rerun `tests/contracts/Test-HostedAgentContract.ps1` to detect any unrelated resource changes.
- [X] T008 [US1] Add the PowerShell invocation of `tests/contracts/Test-AcrTaskAgentPoolSubnetContract.ps1` to `.github/workflows/bicep-validate.yml` alongside existing contract checks; retain upstream action pins, the compiler setup and the separate firewall regression rather than replacing them.
- [X] T009 [P] [US1] Update the private ACR build guidance in `README.md` to explain BYO subnet-before-pool ordering, the `deployNsgs` prerequisite, existing-subnet ownership when `deploySubnets=false`, and why a retry is not cold-start evidence; distinguish this correction from #124's firewall work.
- [X] T010 [P] [US1] Add the new script, runnable command and A1-A9 coverage explanation to `tests/README.md`, keeping compiled dependency evidence distinct from live provisioning success.
- [X] T011 [P] [US1] Add a factual issue-linked `Fixed` entry under the appropriate unreleased section of `CHANGELOG.md` for #159, stating the limited ordering correction and preserved deployment modes without claiming unexecuted live results.
- [X] T012 [US1] Run compile/lint for `main.bicep`, the size gate, the new subnet contract, and existing hosted-agent/firewall/component/preflight regressions listed in `specs/002-private-deployment-reliability/quickstart.md`; prove removing the edge makes the new test fail using an isolated temporary copy, not by reverting shared workspace edits, and retain red/green evidence.
- [ ] T013 [US1] With explicit scope/budget approval, execute the `main.bicep` A1 cold-start procedure in `specs/002-private-deployment-reliability/quickstart.md` using a BYO VNet initially lacking the build subnet; capture subnet completion before pool start, S1 / 1 `Succeeded`, and unrelated-subnet configuration equality; validate A2/A3 compatibility, preview disabled A4-A6, retain count-zero and NSG-rejection evidence for A7/A8, and exercise the authorized cross-scope A9 case; record pending cases rather than treating retries or capacity/egress failures as acceptance.

**Checkpoint:** T005-T012 form the locally verified #159 code slice. T013 is
its live acceptance gate; pending approval does not block US2's local work.

## Phase 4: US2 - Declare a durable Storage access profile (P1)

**Goal:** Implement #160's typed solution Storage contract with unchanged defaults.

**Independent test:** S1-S9 prove type/default and root-to-AVM-to-resource
forwarding. Two approved deployments retain the exact explicit ACL/Shared Key
profile; the no-Defender case introduces no scanner, plan, role or rule.

### Tests first

- [X] T014 [P] [US2] Create `tests/contracts/Test-SolutionStorageAccessContract.ps1` with `-MainFile`, unique temporary compilation/typed parameter fixtures and explicit cleanup; cover S1-S9 including native parameter-file types, omitted/defaulted top-level-null selection, all eight bypass spellings, true/false, zero/one/multiple rules, invalid/empty/missing/extra/wrong-type and required nested-null fields, isolation/IP combinations and disabled Storage; assert exact bindings through the solution AVM and its nested resource, handle the known `shallowMerge` shape with bounded fail-closed resolution rather than token-only proof or a general ARM interpreter, protect unaffected module fields/auxiliary Storage and absence of added Defender resources/roles, and confirm expected failures on the T004 baseline.

### Types, inputs and forwarding

- [X] T015 [P] [US2] Add described exported `storageAccountNetworkAclsBypassType` and sealed `storageAccountResourceAccessRuleType` in `constants/storage-types.bicep`; match the eight exact AVM spellings in `specs/002-private-deployment-reliability/contracts/solution-storage-inputs.md` and require nonempty string `resourceId` and `tenantId`, without inventing scanner IDs, GUIDs, tenant allow-lists or Azure resource discovery.
- [X] T016 [US2] Declare described `storageAccountNetworkAclsBypass`, `storageAccountResourceAccessRules`, and `storageAccountAllowSharedKeyAccess` in `main.bicep` using the focused `storageTypes` import and defaults `AzureServices`, `[]`, and native Boolean `true`; reject invalid inputs rather than introducing permissive coercion, new environment aliases or runtime keys/outputs.
- [X] T017 [P] [US2] Add matching native string/array/Boolean values to `main.parameters.json`, preserving omitted-input support in Bicep and consumer overlays; do not use `${...}` mappings, stringified arrays/Booleans, an additional JSON parameter or a post-provision script.
- [X] T018 [US2] Forward the three inputs only through the existing `storageAccount` / `storageAccountSolution` AVM 0.26.2 call in `main.bicep`, using `networkAcls.bypass`, `networkAcls.resourceAccessRules`, and `allowSharedKeyAccess`; preserve PNA, default action, IP/VNet rules, Blob public-access prohibition, HTTPS, encryption, containers, resource names, RBAC/private endpoints and auxiliary Foundry Storage, and make the focused T014 contract pass.
- [X] T019 [US2] Add only `storageAccount` as this slice's named mutation in `tests/contracts/fixtures/hosted-agent-resource-graph.json` after T014 passes; preserve T007 if present and all historical fixture data, and verify focused assertions protect unchanged Storage fields instead of regenerating hashes or broadly exempting infrastructure.
- [X] T020 [US2] Wire `tests/contracts/Test-SolutionStorageAccessContract.ps1` into `.github/workflows/bicep-validate.yml`, preserving the US1 invocation if present, all baseline checks and upstream action/compiler pins; leave Azure DevOps deployment semantics unchanged because its existing artifact carries native parameter values.
- [X] T021 [P] [US2] Add the three-input reference and omitted/default, private/keyless-no-scanner and approved-existing-scanner examples to `README.md`; state authoritative list ownership, no automatic Defender or live ACL merge, native overlay rather than `azd env set`, and the independence of bypass from existing PNA/IP rules and data authorization.
- [X] T022 [P] [US2] Document the new Storage contract command and S1-S9 coverage in `tests/README.md`, explaining typed negative fixtures, nested forwarding, default equivalence versus byte identity, and the need for independent persistence/authentication/scanning evidence.
- [X] T023 [P] [US2] Add an issue-linked `Added` entry to `CHANGELOG.md` for #160 with preserved defaults, solution-only scope and optional operator-supplied rules; preserve #159's entry, classify the public contract as additive, and do not select a release version or change `manifest.json`.
- [X] T024 [US2] Run the new Storage contract plus compile/lint/size, hosted-agent/component contracts and deterministic preflight from `specs/002-private-deployment-reliability/quickstart.md`; demonstrate failures in isolated copies for dropped/hardcoded/misdirected values, verify false remains Boolean and malformed typed parameters fail for the intended reason, and prove unaffected Storage properties/resources match the T004 baseline rather than relying solely on the fixture exemption.
- [ ] T025 [US2] With explicit approval, run the repeated-deployment procedure for `main.bicep` in `specs/002-private-deployment-reliability/quickstart.md`: exercise S3 without Defender and S4 with an already-enabled approved scanner, deploy each profile twice unchanged, compare exact bypass/Shared Key/rule sets and Policy effects, and verify S1/S2/S7 public/isolated/IP compatibility plus S8's disabled account; introduce no scanner/plan/role/exception in the no-Defender case, make no manual ACL repair, and leave S4 pending if an eligible approved scanner environment is unavailable.

**Checkpoint:** T014-T024 form the locally verified #160 code slice.
T025 supplies live persistence evidence; it is independent of US1 acceptance.
Authentication and scanner operation are separately addressed by US3.

## Phase 5: US3 - Migrate existing accounts without hidden exceptions (P2)

**Goal:** Make ownership, consumer migration and evidence boundaries usable
without editing generated consumer infrastructure or silently widening access.

**Independent test:** Follow the documented profiles using a reviewed existing
account; verify intended Entra/Blob user-delegation and rejected key-based access
where applicable, and report actual Defender scanning separately from ACL
retention. Documentation review is possible before live scope is approved.

### Documentation and operational acceptance

- [X] T026 [P] [US3] Update `docs/runbook-standalone.md` with opt-in Storage migration order: inventory key/connection-string/SAS/file clients, preserve only explicitly approved rule IDs/tenants in the native overlay, review preflight/preview, test supported authentication, then select `None`/`false`; explain empty-list removal, Policy effects, PNA/IP caveats, retained AVM `listKeys()` and safe roll-forward instead of blindly reverting to old defaults.
- [X] T027 [P] [US3] Update `docs/runbook-hub-spoke.md` with BYO subnet ownership/ordering and the same solution-only Storage migration constraints, including same-tenant resource-instance eligibility, external ACL-owner coordination, cross-scope dependencies and existing NSG protection; link the canonical contracts/guide instead of introducing new topology or egress instructions.
- [X] T028 [P] [US3] In the separate repository `Azure/AI-Landing-Zones:docs/bicep/parameterization.md` on a work branch based on `main`, add all three exact types/defaults/allowed values and native JSON examples aligned with `main.parameters.json`; explicitly show no environment-variable mapping and no automatic Defender configuration, following that repository's contributor rules.
- [X] T029 [P] [US3] In `Azure/AI-Landing-Zones:docs/bicep/how-to-deploy.md`, document or link cold-start ordering, private/keyless and existing-account migration, and separate scanner verification; distinguish PNA/IP rules and exceptions, preserve standard deployments, and reference the parameterization section without editing generated `gh-pages` content.
- [X] T030 [US3] Walk through `specs/002-private-deployment-reliability/quickstart.md` against the implemented scripts, `main.parameters.json`, both runbooks and companion public-doc drafts; verify commands and JSON examples, complete versus fragment parameter-file boundaries, approval gates, standard/isolated cases, rollback cautions and credential handling, correcting directly related inconsistencies only.
- [ ] T031 [US3] For an explicitly approved existing-account scenario in `specs/002-private-deployment-reliability/quickstart.md`, inventory and test actual consumers before disabling Shared Key, then verify Entra and Blob user-delegation SAS when used, rejection of key-based authorization, relevant Azure Files compatibility and deployment-principal success with retained AVM key-list outputs; for already-enabled Defender under separate approval perform the official scan check and record scanning independently as pass/fail/not run, never derive it from ACL equality or enable Defender as test setup without authorization.
- [ ] T032 [US3] Coordinate the reviewed companion documentation PR for `Azure/AI-Landing-Zones:docs/bicep/parameterization.md` and `docs/bicep/how-to-deploy.md`, and record its reference with the implementation handoff in `specs/002-private-deployment-reliability/tasks.md`; confirm `README.md` and both runbooks explain GPT-RAG's normal compatible pin/overlay adoption rather than generated `infra/` edits; do not claim external publication or consumer adoption until verified.

**Checkpoint:** User-facing changes ship with matching documentation.
US3 drafting can overlap US2; final walkthrough needs the implemented contract.
Outstanding external publication or live evidence remains explicitly visible.

## Phase 6: Polish and cross-cutting concerns

**Purpose:** Validate the combined diff, preserve approval boundaries and prepare
a reproducible handoff without publishing a release.

- [X] T033 Run the combined narrow validation set from `specs/002-private-deployment-reliability/quickstart.md` on one integrated revision: compile/lint `main.bicep`, measure via `scripts/Measure-MainJsonSize.ps1 -SkipBuild`, run both new contracts plus existing hosted-agent/firewall/component/preflight regressions, and inspect `.github/workflows/bicep-validate.yml`; report command/exit/warning evidence and confirm only the two intended new fixture exceptions, unchanged size limits and no out-of-scope modules, parameters, outputs, identity or network changes.
- [X] T034 [P] Record Portal/Terraform compatibility-review outcomes or pending approvals in `docs/adr/0005-reproducible-private-deployments.md` and the handoff, following `docs/terraform-parity-process.md` for `container-registry-private-build` and `data-services-contract`; classify #159 alone as patch and the combined additive change as minor, without fabricating approval, rewriting `parity/inventory.json`, hand-editing generated `docs/terraform-parity.md`, dispatching Terraform work or changing release pins.
- [X] T035 Remove only task-created temporary fixture/compiler files, preserve pre-existing workspace artifacts, and review `git diff --check` plus the scoped diff for `main.bicep`, `constants/storage-types.bicep`, `main.parameters.json`, tests, CI and docs; ensure no generated templates, secrets or unrelated edits enter the proposed change and keep `manifest.json` and deployment scripts unchanged.
- [X] T036 Update execution status and evidence references in `specs/002-private-deployment-reliability/tasks.md` and reconcile `plan.md`, `quickstart.md` and `docs/adr/0005-reproducible-private-deployments.md` with actual decisions/results; provide separate #159/#160 readiness, companion-doc/parity status, rollback/roll-forward guidance and all unexecuted live cases, leaving approval-blocked tasks unchecked and making no unsupported issue-closure, deployment or release claim.

## Dependencies and execution order

### Phase and story graph

```text
T001 -> T002 -> T003 -> T004
                          |
                          +-> US1 local T005-T012 -> T013 approved live acceptance
                          |
                          +-> US2 local T014-T024 -> T025 approved persistence
                                      |
                                      +-> US3 docs T026-T030 -> T032 companion PR
                                      +-> T031 approved consumer/scanner checks

US1 local + US2 local + US3 documentation walkthrough -> T033 + T034
T033 -> T035 -> T036 handoff (T034 review status also required)
Live/external gates feed acceptance status; missing approval is not a code-work dependency.
```

There is no product dependency from US2 to US1 or vice versa. US3 final examples
and operational acceptance need US2's implemented contract; its BYO guidance
also references US1. A single-issue delivery selects only its relevant shared
and documentation tasks and does not claim completion of the other story.

### Task prerequisites

All story tasks inherit T001-T004. Within each branch:

| Task or group | Additional prerequisites |
| --- | --- |
| T005, T014 | None; independent focused red-test development. |
| T006 -> T007 -> T008 | T005, then previous task in this sequence. |
| T009, T010, T011 | T006; separate documentation files. |
| T012 | T005-T011. |
| T013 | T012, reviewed preflight/preview, specific live approval and eligible scope. |
| T015, T017 | T014; independent constants and parameter-file edits. |
| T016 -> T018 | T015, then T016; complete T017 before asserting the whole input surface. |
| T019 -> T020 | T017/T018 and passing focused contract, then T019. |
| T021, T022, T023 | T017/T018; separate documentation files. |
| T024 | T014-T023. |
| T025 | T024, current operator migration procedure, preview and explicit approvals for both deployments/profile scopes. |
| T026, T027, T028, T029 | Stable implemented contract T017/T018; T027/T029 use the finalized T006 ordering behavior when included. |
| T030 | T012/T024 and T026-T029; review actual code/docs, not assumed planned behavior. |
| T031 | T024, T026/T030, consumer inventory and explicit auth/scanner operation approvals; does not infer scan success from T025. |
| T032 | T028-T030; approved publication workflow and verified companion reference. |
| T033, T034 | Both local slices and T030; live results can still be pending. |
| T035 | T033. |
| T036 | T033-T035 and reviewed status of T013/T025/T031/T032; unresolved human-gated tasks remain unchecked. |

### Shared-file scheduling

Do not run these mutation groups simultaneously in the same worktree:

| Shared file | Tasks to serialize |
| --- | --- |
| `main.bicep` | T006, T016, T018 |
| `tests/contracts/fixtures/hosted-agent-resource-graph.json` | T007, T019 |
| `.github/workflows/bicep-validate.yml` | T008, T020 |
| `README.md` | T009, T021 |
| `tests/README.md` | T010, T022 |
| `CHANGELOG.md` | T011, T023 |

Prefer the US1 edit first, then integrate US2 without dropping it. This is an
editing constraint, not a dependency on US1's live deployment. Cross-repository
documentation tasks need an authorized checkout and coordinated PR ownership;
they never imply permission to push directly to `main`.

## Parallel execution examples

### US1

After T006, T009 (`README.md`), T010 (`tests/README.md`) and T011 (`CHANGELOG.md`)
can run concurrently while one owner integrates fixture/CI changes T007-T008.
T005 can also be developed alongside US2's T014 against isolated baseline
snapshots. Do not compile a file while another worker is modifying it.

### US2

After T014, run T015 (`constants/storage-types.bicep`) alongside T017
(`main.parameters.json`). T016/T018 wait for their prerequisites.
After forwarding is stable, T021/T022/T023 may run concurrently on their
separate files, provided US1 is no longer editing those same paths.

### US3

After the interface stabilizes, T026/T027 update separate local runbooks while
T028/T029 update separate files in the companion documentation repository.
T030 waits for all four drafts. Do not parallelize operations against the same
live Storage account, VNet or scanner; each operation requires its own scope
and approval.

## Acceptance coverage

| Specification requirement | Tasks providing evidence |
| --- | --- |
| FR-159-01 / SC-159-01 | T005, T006, T012, T013 |
| FR-159-02 / SC-159-02 | T005, T007, T012, T013 |
| FR-159-03 | T005, T008, T012, T013 |
| FR-160-01 / SC-160-01 | T014-T018, T024 |
| FR-160-02 | T014, T017-T019, T024, T025 |
| FR-160-03 | T014-T018, T024 |
| FR-160-04 / SC-160-02 | T014, T018, T024, T025 |
| FR-160-05 / SC-160-03 | T014, T018, T025, T031 |
| FR-160-06 | T021, T023, T026-T032 |
| FR-X-01 / SC-X-01 | T004, T007-T012, T019-T024, T030, T032-T036 |

## Implementation strategy

### MVP first

Complete T001-T004 and US1 local T005-T012 as the smallest independent fix for
#159. T013 is required to claim its cold-start acceptance, not replaced by a
passing compile or an already-existing subnet. Ship no undocumented behavior.

### Incremental delivery

Add US2 without changing US1 behavior, complete its core docs with the code,
and use US3 for coordinated migration/public documentation. Keep per-issue
evidence and optional scanner verification distinct. Run T033 on the combined
revision. Do not wait idly for live approval if independent local tasks remain.

### Completion accounting

There are **36 tasks**: 2 setup, 2 foundational, **9 US1**, **12 US2**,
**7 US3**, and 4 cross-cutting tasks. Checkboxes above record actual completion. Fifteen tasks have
`[P]` markers identifying eligible parallel work, subject to the prerequisite
and shared-file tables. Approval is a boundary, not a result to manufacture.

## Execution log

### 2026-09-18 - Setup and integration gate

T001: Repository contract, constitution, matching scoped instructions and
design documents loaded. No extension hooks or feature checklists are present.
Existing ignore rules cover the active Bicep/PowerShell/private Node tooling;
no Docker, ESLint, Prettier, Terraform or Helm project surface was found.
The Node package is private, so no publishing ignore file is needed.

T002: PowerShell 7.6.6 and Azure CLI Bicep 0.42.1 verified. Standalone Bicep
is 0.37.4; subsequent size checks will measure the Azure CLI-built artifact.
No tooling installed/upgraded and no baseline build claimed yet.

T003: Rechecked `main` at `27133628bce98f70ef7a802b3b1a2335560d5d40`;
`develop` remains eight commits behind with no open synchronization PR.
The user explicitly approved a reviewed synchronization PR and completion only
after required checks/approvals, without bypass. An isolated release session
owns that operation. Feature edits and all parallel story tasks await this
foundational gate.

### 2026-09-18 - Synchronization, recovery and RED tests completed

T003: #161 merged at `e3d94e519d07bc7d43272c0de1e576520cda3258` after
all four PR checks passed, preserving the latest `main` ancestry. The user
separately approved the recovery merges #162 and #163. The missing ledger
was initialized from the complete nine-record seed; the workflow appended
the real pending assessments. Coverage now recognizes the custom merge
subject and refreshes/revalidates its ledger snapshot before use.
At feature base `e58f3f968b5f5955ee3ad458d666323d3be31ee1`, assessment run
`35381027640` and validation run `35381027340` both passed. No policy bypass,
invented approval, Terraform dispatch or Azure operation occurred.

T004: Baseline Bicep source at `e3d94e5` is unchanged by the parity recovery.
Azure CLI Bicep 0.42.1 build/lint and the existing hosted-agent, firewall,
component and deterministic preflight tests passed (17/7/18/73 checks).
Compiled size was 4,898,600 bytes (4.672 MB), warning above the 3.5 MB working
budget and below the unchanged 4.7 MB failure threshold. Six existing Bicep
diagnostics remain: three BCP037 warnings and three linter warnings.
Evidence is retained in session artifacts
`t004-e3d94e5-7b02931a-baseline-validation.json` and the matching
`baseline-main.json`.

T005 RED: Azure CLI compilation succeeded; 172 checks passed and the one
missing-BYO-dependency assertion failed as expected. Evidence:
`acr-subnet-red.json` in session artifacts.

T014 RED: The real root compiled, then explicitly failed for the three missing
public Storage inputs. Checks beyond that guard await GREEN execution.
Evidence: `t014-solution-storage-contract-red.md` in session artifacts.

### 2026-09-18 - Local documentation and coordination

T009/T021/T026/T027: README and both topology runbooks updated without
unrelated edits. Four JSON blocks parse; three Storage profiles retain native
types and approved placeholders; all eight bypass spellings match constants.
All eight added links/anchors resolve and the owned diff passes whitespace
checks. An unrelated pre-existing standalone consumer-section anchor remains
unchanged.

T010/T011/T022/T023: Test documentation now identifies both focused scripts
and their evidence limits. The changelog records #159 under Fixed and #160
under Added, preserving defaults and separating additive Storage behavior from
parity-automation compatibility notes.

T034: ADR-0005 records Portal/Terraform review as pending, the two affected
capability IDs, patch/minor scope and the separate public-doc draft boundary.
No review approval, inventory advancement, version change or dispatch is claimed.

Implementation refinement for T015/T016: compiling new types in the original
shared constants file also exported unused definitions into the Firewall
module's wildcard import. Rather than exempt that unrelated module from graph
checks, the types now live in `constants/storage-types.bicep`, imported by
the root as `storageTypes`. Public names, defaults and validation are unchanged;
the original shared constants and networking sources remain untouched.

T028/T029: The isolated `Azure/AI-Landing-Zones` worktree now contains only
the two requested local documentation drafts, based on
`76431d6a2ee8fc92ee0f0c8493bc3540e549c9d8`, branch
`placerda-private-profile-documentation`. Three JSON profiles, the exact bypass
union, five added local links/anchors and external references passed scoped
validation. Non-strict MkDocs build passes; strict build retains exactly two
pre-existing portal warnings (filename casing and missing `portal/SUPPORT.md`),
with no new warnings. No commit, PR, push, publication or deployment occurred.
Details and artifact paths are in session `companion-docs-handoff.json`.
T032 remains pending publication authorization and a companion PR.

T005/T006: The focused ACR contract passed after the implementation. Its
isolated missing-edge mutation compiled successfully and failed exactly one
assertion, with the remaining 172 checks passing. The mutation copied all
51 supporting inputs, including `constants/storage-types.bicep`; source hashes
confirm no mixed snapshot. Evidence: `acr-subnet-green-parent.log` and
`acr-subnet-mutation.json` in session artifacts.

T015/T016/T017: Focused type placement compiles. Native parameter values were
parsed as `AzureServices`, an empty array and Boolean `true`. The compiled root
has exactly three additional parameters (188 to 191), no added/removed resource
symbols, and only `acrTaskAgentPool` and `storageAccount` differ from the
preserved baseline. All unrelated compiled resources, including Firewall,
match. Deep Storage GREEN/mutation checks remain pending before its graph
fixture exemption and final combined validation.

T014 validation refinement: the pinned compiler accepts top-level null for
defaulted parameters by design; actual-root fixtures and the pinned Bicep
`SemanticModel` source confirmed that such an assignment is treated as absent.
The original expectation of compiler rejection was corrected to native
optional/default selection. Invalid concrete values and required nested rule
fields remain constrained. No product fallback, compiler upgrade, broader
bypass or change to the three defaults was introduced. The full contract and
mutations must still pass after this test correction.

### 2026-09-18 - Focused Storage GREEN and mutations complete

T014/T018: Full contract command exits 0. All 168 bounded matrix cases, four
positive typed fixtures and seven negative fixtures pass, including 30
individually rejected values. Top-level optional-null selection is tested
separately; nested-null, sealed-field, empty-string, enum and wrong-type checks
remain enforced.

Seven isolated mutations were detected: dropped/hardcoded forwarding for each
input and propagation into auxiliary Storage. Every mutant compiled and then
exited 1 for the intended contract assertion. Shared product fingerprints
remained unchanged and runtime temporary files were removed.
Evidence: `t014-storage-green-and-mutations.md` and
`t014-forwarding-mutations/` in session artifacts.

T019/T020: After focused GREEN, the graph fixture gained only the approved
`storageAccount` exception alongside `acrTaskAgentPool`; historical hashes and
other exceptions remain unchanged. Both focused contracts are wired into
`bicep-validate.yml` without changing its pins, filters or permissions.

### Final local implementation handoff

T007/T012/T024/T033: Every requested build/test command passed using Azure CLI
Bicep 0.42.1. Results: ACR 173 checks; Storage 168 matrix cases, four positive
fixtures and seven negative fixtures / 30 individual rejections; hosted-agent
17; firewall 7; component flags 18; deterministic preflight 73. Both mutation
suites had already passed independently and were not repeated unnecessarily.

Compiled size is 4,901,745 bytes (4.675 MiB), +3,145 bytes versus baseline.
The unchanged 4.7 MB gate passes, with approximately 26 KiB headroom and the
existing working-budget warning. The same six pre-existing Bicep warnings
remain. Exactly two resource symbols differ, with no added/removed symbols,
unchanged root variables/outputs and exactly three new parameters.

YAML and both PowerShell scripts parse. All previous workflow steps, pins,
filters and permissions remain unchanged. An additional validation assertion
incorrectly expected every permission to be read-only; the correct
preservation check passes because both HEAD and working copy contain
`contents: read` and the pre-existing `pull-requests: write`. No permission
was changed or waived.

T030/T035/T036: Documentation examples/links and the final scoped diff were
checked; percent-encoded URLs are decoded before filesystem checks. All
12 untracked implementation/artifact files pass whitespace checks. Only
task-created runtime temporary files were removed; evidence snapshots remain
in session storage. No after-implementation hooks are registered.

Reproducible evidence: session artifacts `final-feature-validation.json`,
`final-feature-parent-acceptance.json`, the matching compiled template/log
directory, and `companion-docs-handoff.json`.

Pending boundaries: T013 (live cold-start and subnet preservation), T025
(live repeated Storage deployment), T031 (consumer/scanner operation) require
explicit Azure scope/budget approval. T032 awaits companion documentation PR
and publication coordination. Portal/Terraform review remains pending; no
runtime parity, feature release or issue closure is claimed by local validation.
The user has requested following the release workflow after this handoff.
