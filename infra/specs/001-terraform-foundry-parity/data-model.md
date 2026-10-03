# Data Model: Terraform Parity Coordination

## Relationships

```text
ParityBaseline 1 ── * Capability
Capability 1 ── 2 ScenarioAssessment
MergedPullRequest 1 ── 1 AlignmentAssessment
AlignmentAssessment * ── * Capability
AlignmentAssessment 1 ── * TerraformHandoff
TerraformHandoff 0..1 ── 1 TerraformProposal
ScenarioAssessment * ── * ParityEvidence
```

## Parity baseline

Identifies immutable released source and target points.

| Field | Rule |
| --- | --- |
| `schemaVersion` | Semantic version of the inventory contract |
| `source.repository` | Must be `Azure/bicep-ptn-aiml-landing-zone` |
| `source.releaseTag` | Must match `manifest.json.tag` when activated |
| `source.commitSha` | Full 40-character immutable commit |
| `terraform.repository` | Must be `Azure/terraform-azurerm-avm-ptn-aiml-landing-zone` |
| `terraform.releaseTag` | Released Terraform baseline |
| `terraform.commitSha` | Full 40-character immutable commit |
| `assessedAt` | UTC timestamp |
| `status` | `active` or `superseded`; exactly one active baseline |

Initial values are Bicep `v2.6.1`/`64195c...139` and Terraform
`v0.5.1`/`abe337...070`.

## Capability

A stable, kebab-case identifier for one consumer-visible behavior.

Required attributes:

- `id`, `category`, `title`, and concise description;
- Bicep evidence paths and symbols at the pinned source commit;
- Terraform evidence paths and symbols at the pinned target commit;
- consumer surfaces: inputs, defaults, allowed values, outputs, runtime keys, and observable resource behavior;
- identity and RBAC assertions;
- network assertions, including public access, endpoints, DNS, routes, delegation, and ordering where applicable;
- exactly one scenario assessment for `standalone-standard`;
- exactly one scenario assessment for `standalone-network-isolated`;
- accountable owner.

Capability IDs are never reused. Removed capabilities remain as superseded records.

## Surface contract

`surfaceContracts` materializes the pinned source interface independently from
the capability grouping:

- every input has `name`, `kind=input`, compiled ARM `type`, explicit
  `required`, `default`, and `allowedValues` fields;
- `type.representation=built-in` stores the compiled ARM type name, while
  `definition` stores the exact `#/definitions/...` reference emitted for a
  user-defined Bicep type;
- `default.representation=literal` stores the JSON-native compiled value;
  `expression` stores the exact compiled ARM expression (including its outer
  `[` and `]`); and `none` is used only when a required input has no default;
- `allowedValues` is always an array and is empty when the input has no
  restriction;
- every output has `name`, `kind=output`, and compiled ARM `type`;
- every runtime key has `name`, `kind=runtime-key`, and a `literal` or
  `pattern` classification. Pattern entries also carry a machine-readable
  regular expression.

Each `kind:name` identity occurs exactly once in `surfaceContracts` and exactly
once in one capability's `consumerSurfaces`.

## Scenario assessment

| Field | Values or rule |
| --- | --- |
| `scenario` | One of the two supported scenario IDs |
| `supportStatus` | `full`, `partial`, `absent`, or `blocked` |
| `evidenceLevel` | `static`, `proposal`, `merged`, `deployed`, or `reviewed` |
| `parityDeclared` | Boolean; true only at `reviewed` |
| `consumerImpact` | Required for non-full status |
| `compatibility.expectation` | `preserve`, `deprecate`, or `break` |
| `compatibility.affectedInputs` | Explicit list, possibly empty |
| `compatibility.affectedOutputs` | Explicit list, possibly empty |
| `compatibility.defaultDifferences` | Explicit list, possibly empty |
| `compatibility.migrationRequired` | Boolean |
| `blockedReason` | Required only when status is `blocked` |
| `proposalIds` | Reviewable Terraform handoff/proposal references |
| `evidenceIds` | Scenario-specific evidence references |

`parityDeclared=true` requires successful `scenario-deployment` evidence and an approved
`reviewed-capability-comparison` for that same scenario and target commit.

## Alignment assessment

Append-only record for one merged source PR.

| Field | Rule |
| --- | --- |
| `id` | Stable `assessment-<pr>-<merge-sha-prefix>` |
| `sourcePr` | Number, URL, merge SHA, base branch, and merged timestamp |
| `baseline` | Active baseline ID at assessment time |
| `changedCapabilities` | Stable capability IDs |
| `outcome` | `pending`, `no-terraform-impact`, `inventory-update`, `proposal-required`, `blocked`, or `deferred` |
| `rationale` | Required except while pending |
| `handoffIds` | Empty unless a proposal is required |
| `review` | `pending`, `approved`, `rejected`, or `superseded`, plus auditable approval URL |

Uniqueness is source repository + PR number + merge SHA. Re-delivery returns the existing record.
Rejected or replaced records are marked superseded, never deleted.

## Terraform handoff

Structured context for a coding agent; it contains no Terraform source.

Required content:

- exactly one provenance source: an alignment-assessment ID, or initial-baseline provenance;
- pending initial-baseline provenance contains only `baselineId` and the SHA-256 digest of the exact
  inventory bytes;
- approved initial-baseline provenance additionally contains `inventoryCommitSha`, identifying a
  commit with that exact `parity/inventory.json`, and `inventoryReviewUrl`;
- capability IDs;
- pinned Bicep and Terraform commits;
- target repository and base branch;
- required consumer behavior and compatibility constraints;
- acceptance criteria for each affected supported scenario;
- identity, RBAC, local-auth, public-access, endpoint, DNS, route, and subnet invariants;
- AVM validation expectations;
- semantic-version and migration expectation;
- explicit exclusions;
- separate handoff `approvalUrl`, approver, approval time, and resulting Terraform PR URL when
  available.

An approved ongoing handoff requires an approved `proposal-required` assessment covering all cited
capabilities. An approved initial catch-up handoff requires the committed inventory blob and review
above. Pending, rejected, and superseded handoffs may document draft gap coverage but cannot satisfy
proposal eligibility, dispatch, or authorize T033. The pinned Bicep source commit, Terraform target
commit, inventory artifact commit, and handoff artifact commit are independent identifiers. Issue
#136 is context only. One active handoff is allowed per provenance source and capability set.

The handoff artifact commit is the commit in this repository that contains the reviewed handoff
record and the handoff schema. It is not stored in the record, because a record cannot contain the
SHA of the commit that contains it. It is resolved at publication time from the trusted checkout and
travels only in the dispatch payload as `handoffCommitSha`. See
[ADR-0004](../../docs/adr/0004-parity-dispatch-artifact-commit-contract.md) and
[the workflow event contract](./contracts/workflow-events.md).

## Parity evidence

| Type | Meaning | Can support parity? |
| --- | --- | --- |
| `static-validation` | Syntax, lint, schema, or contract checks | No |
| `terraform-plan` | Proposed resource change | No |
| `proposal` | Reviewable change exists | No |
| `merged-change` | Target change merged | No |
| `scenario-deployment` | Exact scenario deployed successfully | Yes, with reviewed comparison |
| `reviewed-capability-comparison` | Human-reviewed match to inventory | Yes, with deployment |

Evidence stores scenario, target commit, sanitized workflow URL, UTC timestamp, result, and reviewer.
It must not store tenant IDs, subscription IDs, credentials, private endpoint addresses, or
environment-specific resource names.

## State transitions

```text
AlignmentAssessment:
pending -> no-terraform-impact | inventory-update | proposal-required | blocked | deferred
any final state -> superseded

TerraformHandoff:
pending -> approved -> dispatched -> proposal-opened -> closed
pending | approved | dispatched -> rejected | superseded

ScenarioAssessment evidenceLevel:
static -> proposal -> merged -> deployed -> reviewed
```

Transitions may move backward only by creating a superseding reviewed record; history is retained.
