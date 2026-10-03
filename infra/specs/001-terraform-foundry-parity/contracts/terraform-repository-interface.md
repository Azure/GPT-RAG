# Terraform repository interface

## Producer

`Azure/bicep-ptn-aiml-landing-zone` owns the approved structured handoff and dispatch. Pending drafts
are not consumer input.

## Consumer

`Azure/terraform-azurerm-avm-ptn-aiml-landing-zone` owns coding-agent execution, Terraform source,
branches, draft pull requests, AVM validation, deployment, evidence, merge, and release.

## Request

The dispatch payload contains only identifiers, paths, and digests:

- event type `parity-proposal-requested` and `payloadVersion` `2.0.0`;
- handoff, provenance, and capability IDs;
- the handoff artifact location: `handoffCommitSha`, `handoffRef`, `handoffPath`,
  `handoffSchemaPath`, and `handoffDigest`;
- source PR number when the provenance is an alignment assessment;
- pinned Bicep and Terraform comparison baselines;
- for baseline provenance, the distinct inventory artifact commit, digest, and review URL.

`sourceCommitSha` and `targetCommitSha` are comparison baselines, not fetch locations. The Bicep
baseline predates the `parity/` tree, so retrieving any parity artifact at that commit is always
wrong.

## Consumer retrieval and verification

The consumer retrieves the full reviewed handoff and the handoff schema from the source repository at
`handoffCommitSha` only, and then:

1. rejects the event by name if `payloadVersion` is absent, is not major version `2`, or omits any
   required field — it never infers an artifact location and never falls back to a branch head;
2. rejects `handoffPath` or `handoffSchemaPath` that fall outside `parity/handoffs/` and
   `parity/schemas/` or contain traversal segments;
3. verifies that `handoffCommitSha` is contained in the configured source integration branch
   (`develop`) of the allow-listed source repository, because a coding agent acts on the retrieved
   instructions and they must be reviewed content;
4. verifies the retrieved bytes against `handoffDigest` and validates the record against the schema
   retrieved from the same commit;
5. for baseline provenance, verifies the exact committed inventory bytes at `inventoryCommitSha` and
   never infers that commit from the pinned Bicep implementation commit.

Retrieved content is data, never executable input.

## Target baseline and current head

`targetCommitSha` is the immutable comparison baseline the inventory was assessed against. The
consumer requires only that it resolves in the target repository and is an ancestor of, or equal to,
the current base-branch head. It is never required to equal that head.

The consumer branches from the current base-branch head and records that head in the proposal so
target drift between approval and dispatch is traceable rather than fatal. A baseline that does not
resolve or is not in the base branch's history fails explicitly and requires a reviewed re-baseline
in the source repository.

## Required consumer response

The target draft PR links to the source assessment or reviewed baseline inventory, handoff,
capability IDs, and baselines, and records the handoff ID, the handoff artifact commit, and the target
head it branched from in a machine-readable marker. It states compatibility and migration impact,
covers both affected supported scenarios, lists required AVM checks, and identifies any blocked
provider capability. The response records the PR URL in the handoff through a reviewed
source-repository update.

A repeated dispatch for the same handoff ID returns the existing proposal. A changed handoff artifact
commit for the same handoff ID is reported as drift on that proposal; a second proposal is never
opened.

## Authorization

The source publication job uses a protected environment and ephemeral GitHub App token. The coding
agent cannot merge. Target branch protection and CODEOWNERS approval remain authoritative.

## Evidence boundary

Target CI may report static checks and plans, but only approved test-subscription deployment plus a
reviewed capability comparison can advance a scenario to parity.
