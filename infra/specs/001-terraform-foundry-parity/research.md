# Research: Terraform Parity Coordination

## Structured source of truth

**Decision**: Use JSON records validated with JSON Schema draft 2020-12. Generate the human-readable
Markdown view deterministically from the inventory.

**Rationale**: PowerShell reads JSON natively, coding agents can consume it without parsing prose,
and schema validation makes coverage and status counts testable.

**Alternatives considered**: Markdown as source of truth was rejected as non-deterministic for
automation. YAML was rejected because it adds parsing dependencies and ambiguous scalar behavior.
GitHub Projects was rejected because it cannot pin and validate the full inventory contract.

## Repository boundary

**Decision**: Keep inventory, assessments, handoffs, ownership, and workflow definitions here.
Send only a structured handoff to the Terraform repository; never store Terraform source or patches
here.

**Rationale**: This preserves repository ownership and lets the Terraform repository enforce its
own AVM checks, branch policies, tests, and release process.

**Alternatives considered**: Directly generating Terraform here was rejected as a boundary
violation. A third repository or hosted coordination service was rejected as unnecessary cost and
operational ownership.

## Immutable comparison baselines

**Decision**: Start with Bicep `v2.6.1` at
`64195c01b70974fa7256c2f54a0035fb06804139` and Terraform `v0.5.1` at
`abe337894f93de3ddda525ea44898b33e1484070`. Store both tags and commits.

**Rationale**: Tags communicate released versions; commits prevent tag movement from silently
changing the comparison. Baseline advancement is a deliberate reviewed PR.

**Alternatives considered**: `main` or `develop` HEAD was rejected as a moving target. Automatically
following `manifest.json` was rejected because it would silently invalidate prior assessments.

## Per-merge assessment

**Decision**: Each PR merged into `develop` creates an idempotent pending assessment keyed by source
repository, PR number, and merge SHA. The workflow serializes append-only commits to a dedicated
`terraform-parity-assessments` ledger branch, never pushes directly to `develop`, and never executes
untrusted PR-head code. Final outcomes and publication approvals remain auditable records.

**Rationale**: The change context is complete at merge time, and append-only records preserve
no-impact decisions as well as actionable gaps. A dedicated branch avoids branch-protection bypass,
assessment-only merge loops, and concurrent writes to the integration branch.

**Alternatives considered**: Release batching loses individual context. One mutable log causes
merge contention. Issues and PR descriptions are not strong machine-readable contracts. One
assessment pull request per source merge creates a recursive assessment loop when that pull request
is itself merged into `develop`.

## Initial catch-up provenance

**Decision**: Initial handoffs may originate from a reviewed, immutable inventory baseline rather
than a merged-PR assessment. Ongoing handoffs originate from approved alignment assessments. The
handoff schema requires exactly one of these provenance forms.

Baseline handoffs use two stages. A pending draft records `baselineId` and the SHA-256 digest of the
exact repository bytes only. An approved handoff additionally records the commit that contains that
exact `parity/inventory.json` blob and an auditable inventory review URL. Handoff authorization
remains separate in `approval`. The Bicep and Terraform implementation commits describe the compared
sources; neither is an inventory artifact commit. Issue #136 provides context only.

**Rationale**: The initial inventory describes historical gaps rather than one newly merged pull
request. Requiring a merged-PR assessment would make initial proposal creation depend circularly on
the ongoing alignment workflow. Separating digest, artifact location, artifact review, and handoff
authorization prevents an implementation SHA from falsely attesting to an inventory it does not
contain.

## Evidence model

**Decision**: Separate support status (`full`, `partial`, `absent`, `blocked`) from evidence level
(`static`, `proposal`, `merged`, `deployed`, `reviewed`). A parity declaration requires successful
deployment evidence and a reviewed capability comparison for the same scenario.

**Rationale**: Static validation and a clean plan cannot prove runtime behavior, especially private
DNS, endpoints, routes, NSGs, or public-access restrictions.

**Alternatives considered**: Plan plus sign-off was rejected by FR-018 and the constitution.
Evidence from the standard scenario cannot cover the network-isolated scenario.

## Secure cross-repository handoff

**Decision**: After protected-environment approval, mint an ephemeral token from a GitHub App
installed only on the Terraform repository and send a bounded `repository_dispatch` payload that
contains IDs and immutable references, not raw diffs or credentials.

**Rationale**: `GITHUB_TOKEN` is repository-scoped and cannot write to another repository. A GitHub
App is narrower and shorter-lived than a personal access token. The coding agent needs structured
context but no secret or Azure permission.

**Alternatives considered**: PATs are long-lived and broad. Azure OIDC authenticates to Azure, not
the GitHub API. A self-hosted runner adds infrastructure and attack surface.

## Human approval boundaries

**Decision**: Require review before dispatch, normal target-repository review before merge, and a
reviewed inventory update before accepting parity evidence.

**Rationale**: Machine-generated changes remain proposals. GitHub environment approval and branch
protection provide auditable platform enforcement.

**Alternatives considered**: Comment-based approval is easier to bypass. Automatic merge violates
FR-011. External change management adds no necessary capability.

## Workflow security

**Decision**: Default to `contents: read`; grant write permissions only to the publishing job. Pin
actions to immutable SHAs. Never execute untrusted PR code in privileged events. Serialize
user-controlled values as data and reject repository, branch, and gap IDs outside configuration.

**Rationale**: This limits token exposure and protects privileged post-merge processing from script
injection and confused-deputy behavior.

**Alternatives considered**: Workflow-wide write permissions and floating action tags increase
blast radius and supply-chain risk.

## Operations and cost

**Decision**: Coordination introduces only GitHub Actions and reviewer cost. Actual test deployments
run in an approved Terraform-repository environment using Azure workload identity federation,
budgets, and explicit cleanup ownership.

**Rationale**: No Azure runtime is needed for the ledger. Isolated test deployments can incur
Firewall, Bastion, private endpoint, and service costs and must remain separately authorized.

**Alternatives considered**: A persistent Azure coordination service is disproportionate. Skipping
live evidence produces an invalid parity claim.

## Sources

- [GitHub token security](https://docs.github.com/en/actions/concepts/security/github_token)
- [GitHub Actions events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)
- [GitHub App installation tokens](https://github.com/actions/create-github-app-token)
- [GitHub environments and approvals](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub OIDC for Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [Microsoft Terraform OIDC sample](https://learn.microsoft.com/en-us/samples/azure-samples/github-terraform-oidc-ci-cd/github-terraform-oidc-ci-cd/)
- [Bicep What-If](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [JSON Schema 2020-12](https://json-schema.org/draft/2020-12)
