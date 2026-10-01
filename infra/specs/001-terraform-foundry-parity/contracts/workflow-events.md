# Parity workflow event contract

## Commit roles

Three commit roles exist. None is ever inferred from another, and none is substituted for another.

| Role | Fields | Rule |
| --- | --- | --- |
| Comparison baseline | `sourceCommitSha`, `targetCommitSha` | Immutable released commits from `parity/config.json`. They anchor comparison and evidence and may predate the `parity/` tree, so they are never used to locate a parity artifact. |
| Artifact location | `handoffCommitSha`, `inventoryCommitSha` | Commits in the source repository that provably contain the referenced reviewed bytes. `handoffCommitSha` is discovered at publication time from the trusted checkout, because a record cannot store the SHA of the commit that contains it. |
| Current head | none | The target base-branch head is observed by the consumer at execution time. It is never carried in the payload and never compared for equality with a baseline. |

## Assessment event

- Trigger: pull request closed with `merged=true`.
- Accepted base branch: `develop`.
- Idempotency key: source repository + PR number + merge SHA.
- Trusted input: event metadata and files at the trusted merged/base commit.
- Prohibited behavior: executing code from an untrusted PR head in a privileged context.
- Persistence: schema-validate first, then serialize append-only commits to the dedicated
  `terraform-parity-assessments` ledger branch with a workflow concurrency key. Never push directly
  to `develop`.
- Result: exactly one pending assessment record or the existing matching record. Because the ledger
  branch is not `develop`, persisting an assessment cannot recursively create another assessment.

## Approval event

- Trigger: protected GitHub environment approval by a configured parity reviewer.
- Preconditions: exactly one approved provenance form is valid, referenced capabilities exist, and
  no conflicting active handoff exists. Ongoing work requires a final approved assessment; initial
  catch-up work requires `inventoryCommitSha` to contain the exact digest-matching inventory and an
  auditable `inventoryReviewUrl`. The Bicep source commit is never substituted for the inventory
  artifact commit. Handoff authorization separately requires `approvalUrl`, `approvedBy`, and
  `approvedAt`; issue #136 is context, not approval evidence.
- Result: approved handoff eligible for dispatch.

## Dispatch event

- Mechanism: `repository_dispatch` to the configured Terraform repository.
- Event type: `parity-proposal-requested`. It is stable across payload versions so that a version
  mismatch fails visibly inside the receiving workflow instead of silently not routing.
- Payload version: `payloadVersion` is `2.0.0`. The major version is the compatibility boundary.
- Payload: identifiers only — payload version, handoff ID, handoff artifact location, provenance type
  and ID, source PR number when applicable, immutable baseline commits, and capability IDs.

| Field | Required | Meaning |
| --- | --- | --- |
| `payloadVersion` | always | Semantic version of this payload contract |
| `handoffId`, `capabilityIds`, `provenanceType`, `provenanceId` | always | Record and provenance identifiers |
| `handoffPath`, `handoffSchemaPath` | always | Repository-relative paths under `parity/handoffs/` and `parity/schemas/`, with no traversal segments |
| `handoffCommitSha` | always | Artifact-location commit that contains both files |
| `handoffRef` | always | Configured source integration branch (`develop`) that contains that commit, recorded for traceability and re-checked by the consumer |
| `handoffDigest` | always | SHA-256 of the LF-normalized handoff bytes, computed exactly as `inventoryDigest` is |
| `sourceRepository`, `sourceRef`, `sourceCommitSha` | always | Immutable Bicep comparison baseline |
| `targetRepository`, `targetRef`, `targetCommitSha` | always | Immutable Terraform comparison baseline and base branch |
| `sourcePrNumber` | alignment provenance | Merged source pull request number |
| `inventoryDigest`, `inventoryCommitSha`, `inventoryReviewUrl` | baseline provenance | Reviewed inventory bytes, their artifact commit, and the review URL |

- Excluded: raw credentials, Azure identifiers, raw PR title/body, full source diff, and any handoff
  or schema content. The consumer retrieves content from the artifact commit, never from the payload.
- Producer preconditions: the publication job resolves `handoffCommitSha` from its trusted checkout,
  proves that the committed blob at that commit matches the validated handoff bytes, and proves that
  the handoff schema exists at the same commit. Any failure aborts the dispatch. There is no fallback
  to a baseline commit, a branch head, or the working tree.
- Authentication: ephemeral token from a narrowly scoped GitHub App.
- Duplicate behavior: return the existing active proposal; never create a second proposal. The
  idempotency key is the handoff ID. A different `handoffCommitSha` for the same handoff ID is
  reported as artifact drift on the existing proposal, never as a new proposal.
- Pending, rejected, and superseded handoffs are never dispatch-eligible. Pending baseline drafts
  can record gap coverage only. T033 also requires the same approved-state authorization even though
  it uses the target repository's existing contribution path rather than the future US3 dispatch.

## Failure behavior

Schema errors, unknown IDs, branch mismatch, missing approval, stale baseline, permission failure,
or target rejection fail explicitly and leave the gap open. Retrying is safe. Rejected or obsolete
records are superseded rather than deleted.

Contract-version and artifact failures are equally explicit and are never resolved by guessing:

- an absent `payloadVersion`, a major version other than `2`, or a missing required field is rejected
  by name, with no branch, no fetch, and no proposal;
- an artifact commit that does not resolve, does not contain the handoff or schema path, is not
  contained in an allow-listed source branch, or whose bytes do not match `handoffDigest` is rejected
  by name;
- a baseline commit is never used as a fetch location, and a branch head is never substituted for a
  missing artifact commit.
