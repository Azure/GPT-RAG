# Implementation Plan: Reproducible private deployments

**Branch**: `placerda-private-deployment-plan` | **Date**: 2026-09-18
**Spec**: [spec.md](spec.md)
**Issues**: [#159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159), [#160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160)
**Status**: Local implementation validated; release requested next. Live Azure
acceptance and coordinated publication/review remain separately tracked gates.

## Summary

Deliver two independently reviewable changes, followed by a combined regression
pass. For #159, add the missing explicit dependency from `acrTaskAgentPool` to
the conditional `virtualNetworkSubnets` module. Preserve the constructed subnet
ID, existing implicit new-VNet dependency, pool flags, and firewall behavior.

For #160, expose three additive, typed solution Storage parameters and forward
them to the existing AVM 0.26.2 call. Defaults remain `AzureServices`, `[]`,
and `true`. The explicit rule list is authoritative; no live ACL merge, Defender
enablement, automatic exception, or post-provision repair is introduced.

The proposed decision, alternatives, risks, and rollback are recorded in
[ADR-0005](../../docs/adr/0005-reproducible-private-deployments.md).

## Technical Context

| Area | Context |
| --- | --- |
| Language/version | Bicep; Azure CLI Bicep 0.42.1 for the existing graph fixture. PowerShell 7 for deterministic tests and hooks. |
| Dependencies | Storage AVM 0.26.2; VNet AVM 0.7.0; local subnet modules; existing ACR agent-pool API `2019-06-01-preview`. No upgrades. |
| Storage | Existing solution `StorageV2` / `Standard_LRS` account, declared by `storageAccount` / `storageAccountSolution`. Auxiliary Foundry Storage is excluded. |
| Platform/project | Reusable resource-group-scoped Azure IaC; Windows/POSIX azd, GitHub Actions, Azure DevOps Bash deployment templates. |
| Testing | Compile-and-inspect PowerShell contracts; existing graph fixture, firewall/component checks and preflight; approved Azure evidence. |
| Performance goals | Remove a deployment race, not promise a duration. Add only the necessary ordering edge; no sleeps or additional resources. |
| Limits | Preserve size-script thresholds: warning 3.5 MB, failure 4.7 MB, hard ceiling 5.0 MB. Preserve private endpoint serialization. |
| Scale/scope | Two product slices; shared orchestrator, tests, CI and docs. No application code, new service, or engineering-agent deployment. |

### Baseline and implementation entry gate

Local source inspected: `21e4e20af04bcbfd8b8c62d708794f71f9d4e942`.
Remote `main` observed: `27133628bce98f70ef7a802b3b1a2335560d5d40`.
Remote `develop`: `dfc8fd377d83175d8b771b6a9427e2e5ea70b17e`, eight commits
behind `main`. The six commits between the local checkout and remote `main`
do not change the affected Bicep/parameter/test bodies; they change CI action
pins, dependency metadata, and issue automation.

The entry gate was completed through user-authorized #161, merged without
bypass after four successful checks. It incorporated the then-latest `main`
commit `e7847ce83d0a13a029eb554e6075d7ccba8c6afa` into `develop` at
`e3d94e519d07bc7d43272c0de1e576520cda3258`.

Subsequent, separately authorized parity recovery changes (#162 and #163)
initialized/used the assessment ledger, corrected merge-subject recognition,
and refreshed ledger snapshots before coverage. Both post-merge workflows
passed on `e58f3f968b5f5955ee3ad458d666323d3be31ee1`, now the feature base.
These changes did not modify Bicep, parameters, constants or modules.
Planning artifacts were preserved during each fast-forward.

Local Azure CLI Bicep is 0.42.1, but standalone `bicep` is 0.37.4. The validation
guide measures the Azure CLI-built file with `-SkipBuild` to avoid that mismatch.
No tool installation or upgrade was performed.

## Constitution Check

Gates were evaluated before research and re-evaluated after Phase 1 against
`.specify/memory/constitution.md` version 1.0.0.

| Gate | Before research | After design / implementation obligation |
| --- | --- | --- |
| I. Orchestrator/modules | Pass: retain ownership. | Pass: no resource wrapper; shared types in focused `constants/storage-types.bicep`. |
| II. Compatibility | Pass: additive requirements. | Pass: typed native JSON inputs, existing defaults, no outputs/runtime keys or AVM upgrade. Test effective equivalence, not byte identity. |
| III. Deployment modes | Pass: standard/BYO/isolated identified. | Pass: matrix covers disabled resources, IP exceptions and the current NSG guard. |
| IV. Identity/networking | Pass: no roles/exposure requested. | Pass: proposed ADR and focused contracts; isolation needs effective PNA/IP/exception and data-plane evidence. |
| V. Evidence/authorization | Pass: read-only research and planning. | Pass for design: product compile/preview/live acceptance remains unexecuted; deployment/release need approval. |
| Release ancestry | No product implementation authorized during planning. | Pass: user-authorized #161 synchronized `main`; #162/#163 recovered post-merge coordination without bypass. |
| Documentation/parity | Pass: surfaces identified. | Include docs and minor-change Portal/Terraform review; no parity approval/publication implied. |

No constitutional exception or unresolved design clarification is proposed.
Environment identity, budget, capacity, approvals and release number remain
execution inputs, not invented defaults.

## Project Structure

### Planning artifacts created

```text
specs/002-private-deployment-reliability/
  spec.md
  plan.md
  research.md
  data-model.md
  quickstart.md
  contracts/
    acr-subnet-ordering.md
    solution-storage-inputs.md
docs/adr/
  0005-reproducible-private-deployments.md
```

The generated [tasks.md](tasks.md) records implementation progress and evidence.
The ignored, machine-local `.specify/feature.json` selects this feature.

### Planned implementation surfaces

| Surface | Intended change |
| --- | --- |
| `main.bicep` | #159 dependency; #160 described parameters and solution Storage forwarding. |
| `constants/storage-types.bicep` | Exported bypass union and sealed resource-access-rule type, imported only where needed. |
| `main.parameters.json` | Native values: string, array, Boolean. No new `${...}` substitution. |
| `tests/contracts/Test-AcrTaskAgentPoolSubnetContract.ps1` | New compiled dependency/gate regression. |
| `tests/contracts/Test-SolutionStorageAccessContract.ps1` | New defaults, type and nested forwarding regression. |
| `tests/contracts/fixtures/hosted-agent-resource-graph.json` | Recognize only the two intentional mutations, protected by focused tests. No wholesale baseline regeneration. |
| `.github/workflows/bicep-validate.yml` | Run both new tests; retain current checks and upstream action pins. |
| `README.md`, `CHANGELOG.md`, `tests/README.md` | Ordering, inputs, compatibility, coverage and factual unreleased entries. |
| `docs/runbook-standalone.md`, `docs/runbook-hub-spoke.md` | Profile/migration guidance and cold-start verification. |
| `Azure/AI-Landing-Zones` `docs/bicep/parameterization.md`, `how-to-deploy.md` | Companion source-doc update on `main`, linked to implementation; no generated-site edits. |

No product changes to subnet modules, `azure.yaml`, `install.ps1`, RBAC,
preflight, or Azure DevOps deployment templates are needed. Azure DevOps
already publishes the parameter file and uses azd. Its environment-variable
passthrough does not map these new inputs; use reviewed native parameter-file
overlays rather than a new parser.

## Phase 0 - Research outcome

[research.md](research.md) resolves dependency semantics, pinned AVM support,
bypass values, rule ownership, Shared Key migration and evidence limitations.
Current Microsoft Learn guidance supplied the fallback after the Azure
best-practices router timed out twice. External research was read-only.

ARM removes explicit dependencies on conditionally skipped resources, so
depending on the subnet module symbol does not require dereferencing its
outputs in existing-subnet paths. ACR firewall bootstrap remains the separate
contract addressed by #124.

AVM already supports all requested Storage fields, but retains secure outputs
using `listKeys()`. Shared Key disabled is a data-authorization policy, not a
promise that deployment performs no key-listing operation.

## Phase 1 - Design and implementation sequence

### Step 0 - Establish the integration baseline

Satisfy the ancestry gate, record the implementation SHA, and load scoped
Bicep, parameters, PowerShell, pipeline and release instructions before editing
those files. Capture the baseline graph using the fixture's compiler version.

### Step 1 - Deliver #159 as a focused bug fix

Add a direct symbolic dependency on `virtualNetworkSubnets` to the pool.
Do not add an output, change the subnet ID, add sleeps, broaden egress, or
change conditions. Preserve parent ACR and implicit new-VNet dependencies.

Create the focused test first and show it fails without the new edge. Cover
[the ordering matrix](contracts/acr-subnet-ordering.md).
Add only `acrTaskAgentPool` to named post-baseline fixture mutations, backed
by the new contract. Add the CI invocation and issue-specific documentation.

### Step 2 - Deliver #160 as an additive feature

Define [the Storage types and inputs](contracts/solution-storage-inputs.md),
add native JSON defaults, and forward values into the existing solution
Storage `networkAcls` object and `allowSharedKeyAccess`.

Keep public access, IP/default-action/VNet rules, private endpoints, Blob
public-access prohibition, HTTPS, encryption, containers and auxiliary Storage
unchanged. Add no App Configuration keys or outputs: this is control-plane
configuration, not a new application runtime interface.

Create the focused test and prove it fails when any field is hardcoded,
dropped or routed to another account. Add only `storageAccount` to named
fixture mutations. Explicitly protect the remaining module fields rather
than merely exempting its whole behavior from review.

### Step 3 - Integrate evidence and migration guidance

The slices are independently deliverable. Prefer #159 first because it unblocks
cold-start infrastructure; #160 has no product dependency on it.
Serialize shared-file edits and run the combined regression set.
[quickstart.md](quickstart.md) defines offline and approved live scenarios.

Do not close either issue based on a retry, compile or What-If. Record pending
live evidence as pending. The cold-start subnet must initially be absent.
Storage evidence compares the complete rule set after two deployments, not
merely the presence of one scanner entry.

### Step 4 - Coordinate documentation and release handoff

#159 alone is a patch; #160 adds a public contract, making a combined release
minor. Do not select a version, edit manifest pins, tag, publish or dispatch
Terraform work in this plan.

Require Portal/Terraform review for the additive contract. Use the existing
parity process for `container-registry-private-build` and
`data-services-contract`. Do not rewrite approved baseline inventory or
generated `docs/terraform-parity.md` to present unshipped behavior as current.
Advance inventory/generated docs only through its reviewed baseline process;
any Terraform proposal needs its separate approvals.

GPT-RAG adopts the compatible ALZ revision through its normal pin/overlay
workflow. Companion public documentation and migration guidance are release
handoff requirements, not completed cross-repository work.

## Acceptance and evidence map

| Requirements | Deterministic evidence | Azure / operational evidence |
| --- | --- | --- |
| FR-159-01,03 | Symbolic dependency; pre-fix-negative test. | Absent subnet initially; completion before pool start; `Succeeded`, S1 / 1, no retry. |
| FR-159-02 | New-VNet/existing-subnet/disabled gates, count 0/1, NSG guard. | Compatibility deployments; unrelated-subnet before/after comparison. |
| FR-160-01..03 | Types/defaults, exact root-to-AVM-to-resource forwarding, explicit false, all bypass values. | Effective properties match profile; distinguish Policy effects. |
| FR-160-04 | Zero/one/multiple rules forwarded unchanged. | Two identical deployments preserve the exact rule set. |
| FR-160-05 | No new Defender resources/roles/plans or inferred rules. | No-Defender baseline gains no ALZ-managed Defender configuration. |
| FR-160-06 | Examples, ownership and migration review. | Entra/SAS consumer checks; existing scanner operation checked separately. |
| FR-X-01 | Graph/firewall/component/preflight tests, lint, size. | Standard/isolated/IP-rule previews and effective-state checks; approvals. |

## Risks, rollback, and completion boundary

Defaults preserve template intent, not arbitrary manual drift. Removing a
rule or opting out of Shared Key can disrupt clients. Inventory integrations,
carry approved rules in the overlay, review What-If and test authentication.

Do not roll an opted-in consumer back to a template that hardcodes
`AzureServices` and removes its scanner rule. Prefer roll-forward or an approved
version retaining the contract. Returning to Shared Key or a broader bypass
requires operator/security approval. Reverting #159 restores the known race.

The original `/speckit-plan` phase ended at design. The subsequent
`/speckit-implement` request authorizes the local implementation recorded in
`tasks.md`; synchronization and parity-recovery merges received separate user
approval. Azure deployments, feature publication and releases remain separately
gated and must not be inferred from local checks.

## Complexity Tracking

No violations or additional infrastructure layers. The only new public
configuration is three inputs; the only ordering change is the missing BYO
subnet dependency.
