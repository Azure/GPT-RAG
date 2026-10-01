# User Story 1 validation

Validated on 2026-08-21 from the user-owned `release/2.6.1` checkout. This
corrective pass remains limited to T010–T020. No Azure deployment, preview,
branch creation or switch, commit, push, release, publication, Terraform source,
or cross-repository proposal was performed.

The active inventory contains 22 grouped capabilities and detailed contracts
for 188 inputs, 61 outputs, and 97 runtime keys (92 literal and 5 pattern).
Input metadata records 38 required/no-default, 125 JSON-literal-default, and 25
compiled-expression-default contracts; 13 inputs have non-empty allowed values.
There are 186 built-in and 2 user-defined input type contracts.

| Command | Exit | Result and proof |
| --- | ---: | --- |
| `npm run test:parity` | 0 | All five parity suites passed. A temporary detached checkout of pinned Bicep commit `64195c01b70974fa7256c2f54a0035fb06804139` compiled without modifying `main.bicep` or retaining ARM output. Tests matched all 188 parameter types, required/default presence, literal values or exact compiled expressions, allowed values, all 61 output types, all 97 runtime contracts, and exactly-once detailed/grouped coverage. |
| `pwsh -NoProfile -File ./scripts/parity/Test-ParityAssets.ps1` | 0 | One active inventory with 22 capabilities passed schema, baseline, reference, scenario, sensitive-value, and evidence-integrity validation. Pinned public subnet defaults are permitted only under detailed source-default metadata; environment evidence remains protected by the private-address check. |
| `pwsh -NoProfile -File ./scripts/parity/Export-ParityMarkdown.ps1 -Check` | 0 | `docs/terraform-parity.md` was byte-identical to deterministic output and exposes input type/default/allowed-value, output type, and runtime literal/pattern metadata. |
| `[IO.File]::ReadAllBytes(...)` plus `SequenceEqual` for the design/runtime inventory schemas | 0 | `specs/001-terraform-foundry-parity/contracts/inventory.schema.json` and `parity/schemas/inventory.schema.json` byte-match at 10,084 bytes. |
| `git diff --check` | 0 | No whitespace errors. |

During direct materialization of the pinned compiled contract, Bicep emitted
existing source warnings for a hard-coded storage host, safe access, one
Managed Environment property type, one unused variable, and unavailable
preview resource types. Compilation succeeded; no warning was suppressed and no
Bicep source was changed.

## Skipped checks

- T021 and later quickstart, evidence, handoff, proposal, and workflow sections
  were not run or changed.
- Copilot asset validation was not run because no agent, skill, instruction, or
  Copilot validation script changed.
- Current-tree Bicep build/lint, deployment preview, and Azure-aware preflight
  were not run because no Bicep, parameter, module, or deployment behavior
  changed. The only compilation was the temporary pinned contract used by the
  deterministic inventory test.
- No Terraform plan/apply or Azure deployment ran. Static source and compiled
  contract inspection are not parity evidence.

## Residual risk

- Every scenario assessment remains `parityDeclared=false`.
  `standalone-standard` remains structurally blocked in Terraform v0.5.1, while
  `standalone-network-isolated` is assessed independently.
- Runtime parity, DNS resolution, endpoint reachability, RBAC effectiveness,
  and scenario deployment behavior still require separately approved
  deployments and reviewed comparisons in the Terraform repository.
- The coverage test requires a local Bicep CLI, or Azure CLI with Bicep, and the
  pinned Git commit to remain available in repository history.
- The previously observed npm audit warning for pinned local validation tooling
  remains unresolved; changing validator dependencies is outside T010–T020.

# User Story 2 handoff validation

Validated on 2026-08-21 from the same user-owned dirty `release/2.6.1`
checkout. This pass implements only T021–T032. It preserves the US1 inventory,
keeps all 44 scenario assessments at `parityDeclared=false`, and leaves T033
unchecked.

Five pending, human-reviewable handoffs use honest draft baseline provenance:
`baselineId` plus SHA-256
`33fa2bae3144b79c632a0e8f142a85600989ecd04de8cca8b1a49de5edff44b4`
over the exact Git-normalized `parity/inventory.json` repository bytes. They claim neither an inventory
commit nor review. Their capability sets cover all 44 actionable `partial`,
`absent`, or `blocked` capability/scenario gaps, but the approved
proposal-eligible count is zero. Pending status prevents agent consumption,
dispatch, and T033 authorization.

| Command | Exit | Result and proof |
| --- | ---: | --- |
| `npm run test:parity` | 0 | All nine parity suites passed. Fitness cases prove pending digest-only schema validity, missing approved metadata rejection, source SHA rejection because its inventory blob is absent, exact committed-byte digest and baseline verification in a temporary unreferenced Git repository, mismatch rejection, pending proposal ineligibility, alignment provenance, and retained explicit generator failures. Inventory coverage remained 22 capabilities, 188 inputs, 61 outputs, and 97 runtime keys. |
| `pwsh -NoProfile -File ./scripts/parity/Test-ParityAssets.ps1` | 0 | Reported one inventory, 22 capabilities, zero assessments, five handoffs, zero approved proposal-eligible handoffs, and zero evidence records. Draft coverage, provenance, duplicate, scenario-evidence, and sensitive-content checks passed. |
| Handoff coverage query over `parity/inventory.json` and `parity/handoffs/**/*.json` | 0 | `handoffs=5; pending=5; actionableGaps=44; covered=44; approvedEligible=0; parityDeclared=0`; all required category directories are present. |
| `pwsh -NoProfile -File ./scripts/parity/Export-ParityMarkdown.ps1 -Check` | 0 | The generated inventory view remained byte-identical. Handoff IDs were not added to inventory, so no generated content changed. |
| `pwsh -NoProfile -File ./.github/scripts/Validate-CopilotAssets.ps1` | 0 | Validated six agents, 17 skills, and scoped instructions, including the read-only parity-agent boundary. |
| `pwsh -NoProfile -File ./tests/scripts/Validate-CopilotAssets.Tests.ps1` | 0 | Valid, duplicate-name, unsupported-tool, parity write-tool, approved-provenance boundary, and missing-boundary cases all passed. |
| Design/runtime byte comparison for the Terraform handoff schema | 0 | Design and runtime schemas byte-match at 7,035 bytes; schema version remains `1.0.0` because the assets are unreleased. |
| `git show 64195c01b70974fa7256c2f54a0035fb06804139:parity/inventory.json` | 128 (expected) | Git reported that the path is absent from the pinned Bicep implementation commit, proving it cannot serve as approved inventory provenance. |
| Terraform-source extension scan (`*.tf`, `*.tfvars`, `*.tf.json`) | 0 | No Terraform source files exist in this repository. |
| `git diff --check` | 0 | No whitespace errors. |

No final validation command emitted a warning. The previously recorded npm
audit warning for the pinned local validator remains unresolved and was not
rechecked because dependencies did not change.

## User Story 2 skipped operations and residual risk

- T033 was not executed: no external pull request, target-repository change,
  credential use, dispatch, publication, branch operation, commit, push,
  release, or deployment occurred.
- No Bicep build/lint, What-If, Azure preflight, Terraform plan/apply, or Azure
  deployment ran because deployed infrastructure did not change.
- Every handoff remains `approval.status=pending`. Before proposal work, a
  reviewed repository commit must contain the exact inventory bytes and handoff
  authorization must separately record its URL, approver, and time. Issue #136
  is context and supplies none of this evidence.
- `standalone-standard` remains structurally blocked in Terraform v0.5.1.
  `standalone-network-isolated` remains independently assessed.
- Static validation does not prove runtime behavior, effective RBAC, DNS,
  endpoint reachability, or isolation. Each scenario still requires its own
  approved target-repository deployment and reviewed comparison.

# User Story 2 proposal publication

Completed on 2026-08-22 after PR
[`#147`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/147)
merged the reviewed inventory and the maintainer recorded separate T033
authorization in
[comment `#issuecomment-5375280499`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/147#issuecomment-5375280499).
Inventory commit `54d18f53273082dd12f0cab0689ec7968e845950`
contains the exact proposal-linked inventory bytes with SHA-256
`5dd04b6ebb7faa4554954ee9fe27cd3589943f724e9d14e5c799dea0a93bdf75`.

| Handoff | Upstream draft proposal | Target commit | Local validation |
| --- | --- | --- | --- |
| Networking | [`#162`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/162) | `2455d2f289baa69787965a82ce1ffcc8c4b07e5c` | `avm test` and `avm pre-commit` passed. |
| Security | [`#163`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/163) | `ecff99f` | `avm pre-commit`, three unit tests, and `terraform validate` passed. |
| Application Platform | [`#164`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/164) | `5a896b6c6d5ef644ea90a616ca566e56b3a414ba` | `terraform validate`, five unit tests, `avm pre-commit`, and `avm test` passed. |
| AI Foundry | [`#166`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/166) | `94965df` | `terraform validate`, three focused tests, and `avm pre-commit` passed. |
| Data and AI Services | [`#167`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/167) | `b742d8b` | `avm pre-commit`, `avm test`, six unit tests, and Terraform validation/tests passed. |

All five proposals are open drafts from the `placerda` fork to upstream
`main`, are mergeable, and passed the upstream basic check, CodeQL analysis,
and CLA check. Their bodies record the implemented safe subset and exact
deferrals. Repository-wide `avm pr-check` lint remains affected by pre-existing
AzureRM-to-AzAPI compliance findings outside these proposal changes.

The 22 capabilities and both scenario assessments now reference exactly one
approved handoff, covering all 44 actionable gaps. Every
`parityDeclared` value remains `false`. No proposal was merged and no Terraform
apply, Azure deployment, release, publication, or runtime parity claim was
performed. Each scenario still requires an independently approved deployment
and reviewed comparison before parity can be declared.

# User Story 3 and polish validation

Validated on 2026-08-22 from the `placerda/terraform-parity-coordination` working
tree, which is `origin/develop` at merge commit
`479000e76deb9241e1d8d2814a0e337be57daaf3` (PR
[`#148`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/148)) plus the
uncommitted coordination assets. This pass implements T034-T046 and T048-T054
and then applies the corrective findings D1-D14 and the testing gap from
independent validation. T047 was implemented separately in the Terraform fork
and published as upstream draft PR
[`#170`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/170).
No dispatch, merge, deployment, release, GitHub App or environment
configuration, reverse write, parity declaration, or Azure operation was
performed.

Delivered behavior: per-merge assessment creation and finalization with immutable
outcome, rationale, and review decisions; a dedicated append-only ledger contract
with adoption marker, a tested ledger guard script, and coverage validation that
fails on unassessable commits; gated bounded cross-repository publication;
ownership, branch-protection, and GitHub App operations documentation; and
workflow, scanning, and performance tests that parse workflow YAML with an
in-repository reader instead of installing a module at runtime. ADR-0004
separates immutable comparison baselines from the commit that contains the
reviewed handoff bytes, so the producer and receiver no longer overload
`sourceCommitSha` or require a pinned Terraform baseline to equal current
`main`.

Corrective changes applied in this pass:

| Finding | Change |
| --- | --- |
| D1 | `Set-AlignmentAssessment.ps1` accepts a rationale only while the outcome is `pending`; a rationale paired with any other mutation on a finalized record fails `ParityImmutableOutcome` and rewrites nothing. |
| D2 | `review.status=rejected` is terminal except `-> superseded`, requires reviewer, absolute `https` decision URL, and review timestamp exactly as approval, requires an already recorded outcome, and is enforced by both script and `parity/schemas/assessment.schema.json`. A superseded review is final. |
| D3 | `docs/terraform-parity-ownership.md` section 3 requires pull requests and forbids direct and force pushes on `develop`; `Test-AssessmentCoverage.ps1` now fails on any post-adoption first-parent commit without a pull request reference, with the named `-AllowUnattributedCommits` opt-out that CI never passes. |
| D4 | The adoption marker note, ownership section 2, and T046 describe a hand-assessed seed with `review.status=pending`; no approval is claimed and the six records stay pending. |
| D5 | The aggregate validation line is recorded as measured: 26 scanned files. |
| D6 | Documentation and quickstart fetch `origin/develop` and validate against it; `-Branch HEAD` is documented only for the currently checked-out merge commit. |
| D7 | The parity path installs no PowerShell module at runtime. `scripts/parity/Parity.WorkflowYaml.ps1` is a strict in-repository reader for the workflow YAML subset, the `Install-Module` step is removed from `terraform-parity-validate.yml`, and `Test-WorkflowSecurity.Tests.ps1` fails any gallery install or non-lockfile package install in a parity workflow. |
| D8 | ADR-0004 and payload version `2.0.0` add `handoffCommitSha`, `handoffRef`, `handoffSchemaPath`, and an LF-normalized `handoffDigest`. The producer proves that the trusted checkout commit contains byte-matching handoff and schema blobs. `sourceCommitSha` and `targetCommitSha` remain immutable comparison baselines, never artifact locations or current-head assertions. |
| D9 | Publication and aggregate validation read ongoing alignment assessments from the `terraform-parity-assessments` checkout. The frozen seed on `develop` remains the adoption source only; tests now place the first continuous assessment exclusively under the ledger path. |
| D10 | Ledger discovery uses `git ls-remote --exit-code`: exit `0` means present, exit `2` means absent, and every transport, authentication, or repository failure aborts validation instead of silently falling back to the frozen seed. |
| D11 | Ledger discovery runs in `Get-AssessmentLedgerAvailability.ps1`, which maps Git exit `0` to present, exit `2` to absent, every other exit to failure, and then exits explicitly. Temporary-Git-repository tests execute the present, absent, and invalid-repository paths, so GitHub's PowerShell wrapper cannot turn a valid pre-activation fallback into a failed step. |
| D12 | `terraform-parity-assess.yml` invokes `New-AlignmentAssessment.ps1` in a child PowerShell process, making `$LASTEXITCODE` deterministic before the guard and allowing a successfully created record to reach schema validation, the append-only check, and commit. |
| D13 | `Test-ParityAssets.ps1` resolves `adoption-marker.json` relative to the selected assessment directory and excludes it by file name before assessment-schema validation. The end-to-end fixture now carries the marker inside the dedicated ledger path. |
| D14 | When ledger discovery reports `exists=true`, validation selects the ledger through that output and fails if its configured assessment directory is absent. It never infers activation from a directory probe or silently falls back after a successful branch checkout. |
| Testing gap | The ledger append-only guard moved from inline YAML into `scripts/parity/Test-LedgerAppendOnly.ps1` with 10 temporary-Git-repository cases; the parallel-delivery case now asserts atomic, non-torn idempotent delivery against a single-run byte baseline; checkout trust is asserted by enumerating every parsed checkout reference against a per-workflow allow-list. |

## Commands and results

| Command | Exit | Result and proof |
| --- | ---: | --- |
| `npm run test:parity` | 0 | All 17 parity suites passed, including the two new `Test-ParityWorkflowYaml` and `Test-LedgerAppendOnly` suites. Each suite was also executed individually and exited 0. |
| `pwsh ./tests/parity/Test-AlignmentAssessment.Tests.ps1` | 0 | 35 cases: idempotent creation keyed by repository, pull request, and merge SHA; merged-only and integration-branch filtering; unknown capability rejection; duplicate delivery returning the byte-identical existing record; a second merge SHA appending a new record; ID conflict rejection; all five final outcomes; rationale enforcement; immutable identity, source pull request, and baseline; supersession as the only post-final outcome transition; a finalized rationale that cannot be rewritten alongside an evidence-link mutation (bytes unchanged); a pending record that still accepts a rationale; rejection blocked before an outcome exists; rejection without reviewer, URL, or timestamp rejected; a rejected record that is schema-valid, cannot become approved (bytes unchanged), can only be superseded, and keeps its decision metadata; a superseded review that is terminal; four parallel identical deliveries producing exactly one record byte-identical to a single-run baseline; four parallel distinct deliveries producing four intact records. |
| `pwsh ./tests/parity/Test-ParityWorkflowYaml.Tests.ps1` | 0 | 21 cases proved the in-repository reader parses nested mappings, sequences of scalars and step mappings, quoted scalars, literal and folded block scalars, trailing comments, and core scalar typing, keeps `on` as a string key, and fails explicitly on flow collections, anchors, aliases, merge keys, tab indentation, multiple documents, duplicate keys, unparsable lines, and unexpected indentation. Each parity workflow parses into a job and step graph whose `uses` and `run` step counts match the file. |
| `pwsh ./tests/parity/Test-LedgerAppendOnly.Tests.ps1` | 0 | 10 cases in temporary Git repositories: a clean ledger checkout, an untracked new record, and a staged new record pass; modification, deletion, rename, a change outside `parity/assessments`, a non-JSON file inside it, a checkout on `develop`, and a detached checkout all fail explicitly and name the offending path or branch. |
| `pwsh ./tests/parity/Test-WorkflowEventContract.Tests.ps1` | 0 | 21 cases parsed `terraform-parity-assess.yml` with the in-repository reader and proved closed-pull-request handling on `develop` only, merged-only execution, both checkout references on the trusted allow-list with no `head` reference, the dedicated ledger checkout, serialized non-cancelling concurrency, no integration-branch push, record creation plus schema validation, the append-only guard script running before any commit step, environment-only event data, and no suppressed failures. Behavioral cases executed ledger discovery for present, absent, and invalid-repository paths; wrote a record to an isolated ledger path while leaving the integration-branch path empty; and proved that an unassessed merge, duplicate assessments, and a direct commit without a pull request reference all fail explicitly, that one assessment per merge passes, and that `-AllowUnattributedCommits` accepts and names the unattributed commit. |
| `pwsh ./tests/parity/Test-ParityPublication.Tests.ps1` | 0 | 17 cases proved payload `2.0.0` with bounded identifiers, independent baseline and artifact commits, LF-normalized handoff digest, exact committed handoff and schema retrieval, explicit rejection of uncommitted bytes or commits missing either artifact, duplicate proposal reconciliation returning [`#163`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/163) without dispatching, approval and allow-list enforcement, assessment-origin dispatch from the dedicated ledger path, closed-gap rejection, target rejection, and protected-environment plus App-token requirements. |
| `pwsh ./tests/parity/Test-WorkflowSecurity.Tests.ps1` | 0 | 43 cases over all three parity workflows: read-only default permissions, per-job minimum permissions (`contents: write` only for the assessment job), bounded job timeouts, 40-character action pins with released-version comments, every checkout reference on an explicit per-workflow allow-list with no `head` reference, tooling installed only from the pinned lockfile, no event, secret, or input interpolation inside shell blocks, no token or key printing, no embedded credential material, only uppercase secret references, the publication ledger checkout and path, fail-closed ledger discovery, live-ledger aggregate validation, credentials persisted only for the ledger checkout, and the append-only guard delegated to its tested script. |
| `pwsh ./tests/parity/Invoke-ParityWorkflow.Tests.ps1` | 0 | 10 cases: merged pull request 970 to a pending assessment stored only in the ledger path, approved `proposal-required` decision, generated pending handoff, publication refusal, approved handoff, recorded handoff reference, bounded payload-v2 dispatch, recorded proposal reference, duplicate reconciliation, aggregate validation, and the complete cross-record reference chain. |
| Deliberate workflow mutations, each reverted immediately | 1 (expected) | Replacing the trusted merge-commit checkout with `pull_request.head.sha` failed both `Test-WorkflowSecurity.Tests.ps1` and `Test-WorkflowEventContract.Tests.ps1`; adding an `Install-Module` step failed `Test-WorkflowSecurity.Tests.ps1`; removing the append-only guard step failed both suites. The workflow file was restored byte-identically after each mutation. |
| `pwsh ./scripts/parity/Test-ParityAssets.ps1` | 0 | `1 inventory, 22 capabilities, 6 assessments, 5 handoffs, 5 approved proposal-eligible, 0 evidence records, 26 scanned files`. Includes adoption-marker schema and branch validation plus the raw-file sensitive scan over `parity/` and `tests/parity/fixtures/`. |
| `git fetch --no-tags origin '+refs/heads/develop:refs/remotes/origin/develop'` then `pwsh ./scripts/parity/Test-AssessmentCoverage.ps1 -Branch origin/develop` | 0 | `6 merged pull requests after adoption commit 5a30a4f on origin/develop, 6 ledger records, 0 unattributed commits`. The fetched `origin/develop` is `479000e`. |
| `pwsh ./scripts/parity/Test-AssessmentCoverage.ps1 -Branch HEAD` | 0 | `6 merged pull requests after adoption commit 5a30a4f on HEAD, 6 ledger records, 0 unattributed commits`, matching the fetched integration branch. |
| `pwsh ./scripts/parity/Export-ParityMarkdown.ps1 -Check` | 0 | `docs/terraform-parity.md` remained byte-identical; the inventory was not modified by this pass. |
| `pwsh ./scripts/parity/Test-ParityJson.ps1 -Path parity/assessments/adoption-marker.json` | 0 | The adoption marker validates against the pinned `adoptionMarker` schema through automatic schema discovery. |
| `pwsh ./tests/parity/Test-ParityPerformance.Tests.ps1` | 0 | Final rerun: `Validation: 5.05s; generation: 0.67s; total: 5.72s (budget 60s)`. |
| `pwsh ./.github/scripts/Validate-CopilotAssets.ps1` | 0 | `Validated 6 agents, 17 skills, and scoped instructions.` |
| `pwsh ./tests/scripts/Validate-CopilotAssets.Tests.ps1` | 0 | All agent, skill, and parity-boundary cases passed; no Copilot asset changed in this pass. |
| Design/runtime byte comparison for the assessment and adoption-marker schemas | 0 | `specs/001-terraform-foundry-parity/contracts/assessment.schema.json` and `parity/schemas/assessment.schema.json` byte-match at 2,634 bytes; the adoption-marker pair byte-matches at 980 bytes. The inventory (10,084 bytes) and handoff (7,035 bytes) pairs are unchanged and still match. |
| One-off equivalence check of the in-repository YAML reader against powershell-yaml 0.4.12 | 0 | For all three parity workflows and `bicep-validate.yml`, `ConvertFrom-ParityWorkflowYaml` produced structures with identical keys, sequence lengths, and scalar values. The throwaway comparison script was deleted; the retained deterministic proof is `tests/parity/Test-ParityWorkflowYaml.Tests.ps1`, which needs no module. |
| Final read-only review of the complete source diff | 0 | No high-confidence correctness, security, workflow-activation, ledger, PowerShell exit-semantics, payload-v2, or idempotency defect was found. First activation still requires the documented creation and seeding of `terraform-parity-assessments`; this is an operational prerequisite, not an implicit workflow fallback. |
| `git diff --check` | 0 | No whitespace errors. Git reported only its usual LF-to-CRLF working-copy notice for `.gitignore` and `specs/001-terraform-foundry-parity/validation.md`. |

## Backfilled ledger seed

`parity/assessments/adoption-marker.json` pins adoption commit
`5a30a4fbb8338b6d1623fdaa7b8e79425b1f4d3b` (the PR #140 merge). Every pull
request merged into `develop` after it has one hand-assessed record. The nine
records are a hand-assessed seed with `review.status=pending`: the outcome and
rationale were written by hand before workflow activation, and no approver,
approval URL, or approval time is recorded.

| Pull request | Merge commit | Outcome | Review | Basis |
| --- | --- | --- | --- | --- |
| #126 | `d8e3eeb` | `inventory-update` | pending | Foundry local-authentication toggle and component deployment flags surfaced through azd substitution; already cataloged by the pinned v2.6.1 baseline and covered by approved baseline handoffs. |
| #142 | `871db53` | `no-terraform-impact` | pending | v2.6.0 release metadata synchronization: changelog and release manifest only. |
| #144 | `1c1767a` | `inventory-update` | pending | v2.6.1 deployment-name and Cosmos DB nesting fix; consumer inputs, outputs, defaults, and configured Azure resource names preserved. |
| #146 | `d2ba2be` | `no-terraform-impact` | pending | v2.6.1 release metadata synchronization: changelog and release manifest only. |
| #147 | `66a0d76` | `no-terraform-impact` | pending | Parity coordination assets only. |
| #148 | `479000e` | `no-terraform-impact` | pending | Reviewed proposal references and approved handoff provenance only. |
| #149 | `ebfeb29` | `no-terraform-impact` | pending | Continuous parity coordination automation and documentation only; no Bicep deployment contract changed. This transition record was added because `pull_request_target` could not load the newly added workflow until it reaches the default branch. |
| #150 | `cb5abfd` | `no-terraform-impact` | pending | Plain-language parity process documentation and the PR #149 transition record only; no Bicep deployment contract changed. This transition record was added because `pull_request_target` still could not load the workflow before its promotion to the default branch. |
| #152 | `dfc8fd3` | `no-terraform-impact` | pending | PR #150 transition assessment and seed documentation only; no Bicep deployment contract changed. This final transition record is carried by the promotion branch because another corrective merge into `develop` would itself require another pre-activation assessment. |

The nine-record seed is completed on the default-branch promotion so the dedicated
`terraform-parity-assessments` ledger branch can be created from the reviewed
commit that contains it. After that branch exists and the assessment workflow
is available on the default branch, the workflow appends every later record
only there and never to `develop`.

## Terraform receiver proposal

T047 is published as upstream draft PR
[`#170`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/pull/170)
from fork branch `placerda-parity-proposal-workflow` at commit
`b11e31bc9a96157e938e747d3ed37aa359d97ca0`. The proposal adds the bounded
`parity-proposal-requested` receiver, immutable handoff and schema retrieval,
approved-state and baseline exact-byte digest checks, existing-proposal
reconciliation, draft-only coding-agent instructions, deterministic security
and idempotency tests, and target-repository documentation. It consumes ADR-0004
payload `2.0.0`, fetches the handoff and schema at `handoffCommitSha`, verifies
the LF-normalized `handoffDigest`, and treats `targetCommitSha` as an immutable
ancestor baseline rather than current `main`.

Target validation reported 29 Python contract, security, and idempotency tests
passing; Python compilation and workflow YAML parsing passing; the approved
Bicep `foundry-baseline.json` validating against the authoritative source schema
on `develop`; and `avm test` plus all five `avm pre-commit` stages passing.
`abe337894f93de3ddda525ea44898b33e1484070` was confirmed as an ancestor of
current Terraform `main` `5082af10f88fde13a4325ac6bab0ff2bcf5f6554`.
The local `avm pr-check` passed sync, format, transform, policy, convention,
validate, and docs, and failed only lint on unchanged pre-existing
AzureRM/AzAPI findings documented in the PR. The upstream PR remains open and
draft. The proposal remains inactive until maintainers merge it and
administrators separately configure the protected environment and
single-repository GitHub App. It performs no automatic reverse write and makes
no deployment, release, or parity claim.

## Skipped operations and configuration dependencies

- `npm ci --ignore-scripts` was not run: `npm ping` failed with
  `ERR_SSL_SSLV3_ALERT_HANDSHAKE_FAILURE`, so there is no registry access from
  this environment. The pinned validator was verified in place (`ajv 8.20.0`,
  `ajv-formats 3.0.1`), which matches `package-lock.json`. No dependency was
  added, so no lockfile change was needed.
- No workflow was executed on GitHub. `terraform-parity-assess.yml`,
  `terraform-parity-publish.yml`, and the ledger steps in
  `terraform-parity-validate.yml` were validated by parsing them and by running
  the same scripts they invoke, including the ledger guard against temporary Git
  repositories.
- Remote configuration is still required before activation and cannot be created
  from this session: `develop` branch protection (pull requests required, direct
  and force pushes forbidden), the `terraform-parity-assessments` branch and its
  protection, the protected `terraform-parity-publication` environment and
  reviewers, the single-repository GitHub App, and the `PARITY_DISPATCH_APP_ID`
  and `PARITY_DISPATCH_APP_PRIVATE_KEY` environment secrets. Sections 3 to 7 of
  `docs/terraform-parity-ownership.md` record the required values.
- The nine backfilled assessments carry `review.status=pending`. Recording an
  approver, approval URL, and approval time is a human act; this pass did not
  fabricate one. A reviewer records it with
  `pwsh ./scripts/parity/Set-AlignmentAssessment.ps1 -Path <record> -ReviewStatus approved -Reviewer <handle> -ApprovalUrl <review-url> -ReviewedAt <utc>`.
- No Bicep build, lint, size gate, What-If, preflight, azd command, Terraform
  plan or apply, or Azure deployment ran, because no Bicep, parameter, module,
  manifest, or deployment behavior changed.
- Workflow log scanning cannot run offline. The parity workflows print no record
  content, token, or payload body, and `Test-WorkflowSecurity.Tests.ps1` enforces
  that contract; the exclusion is documented in `scripts/parity/Test-ParityAssets.ps1`.

## Residual risk

- Nothing in this pass proves runtime parity. All 44 scenario assessments remain
  `parityDeclared=false`, and each scenario still needs its own approved
  test-subscription deployment and reviewed comparison in the Terraform
  repository.
- Coverage strength depends on `develop` branch protection. The coverage script
  now fails on a post-adoption first-parent commit without a pull request
  reference, but a repository that enables `-AllowUnattributedCommits` or leaves
  `develop` unprotected downgrades the guarantee to "every merged pull request is
  assessed". CI never passes that switch.
- Ledger coverage is also only as strong as its remote configuration. Until the
  ledger branch exists and is protected, validation uses the in-tree seed and the
  assessment and publication workflows fail their mandatory ledger checkout by
  design. Once present, transport or authentication failures abort discovery
  rather than falling back.
- `scripts/parity/Parity.WorkflowYaml.ps1` reads a deliberate subset of YAML. It
  throws on anything it does not fully understand, so an unsupported construct
  fails the suites loudly rather than being asserted against a partial document,
  but a future workflow that needs flow collections or anchors must extend the
  reader and its tests first. Equivalence with powershell-yaml 0.4.12 was checked
  once locally for the current workflows and is not a standing CI check.
- `pull_request_target` runs privileged. The workflow checks out only the merge
  commit already on `develop`, uses no pull-request head content, and passes event
  metadata as environment data, but any future edit to that workflow must keep
  those properties; the security suite with its checkout allow-list is the guard.
- The publication job depends on `actions/create-github-app-token` pinned to
  `bcd2ba49218906704ab6c1aa796996da409d3eb1` (v3.2.0). Pin advancement is a
  reviewed change.
- The adoption marker was chosen deliberately at PR #140. Merges before it are
  intentionally out of scope and are not silently assessed.
- `parity/schemas/assessment.schema.json` now requires reviewer, decision URL, and
  timestamp for a rejected review. No existing record uses `rejected`, so the
  stricter contract breaks nothing today, and the schema version stays `1.0.0`
  because the assets are unreleased.
