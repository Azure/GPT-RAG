# Terraform parity ownership and operations

This document names the accountable owners for parity decisions and describes the
GitHub App, protected environment, and ledger operations that the parity workflows
depend on. It does not claim runtime parity: only an approved test-subscription
deployment plus a reviewed capability comparison can advance a scenario, and both
are owned by the Terraform repository.

Related assets:

- Inventory: [`parity/inventory.json`](../parity/inventory.json), generated view
  [`docs/terraform-parity.md`](./terraform-parity.md)
- Process guide:
  [`docs/terraform-parity-process.md`](./terraform-parity-process.md)
- Records: `parity/handoffs/`, `parity/assessments/`, `parity/schemas/`
- Automation: `scripts/parity/`, `tests/parity/`,
  `.github/workflows/terraform-parity-*.yml`
- Decision record:
  [ADR-0003](./adr/0003-repository-native-terraform-parity-coordination.md)

## 1. Ownership

| Area | Accountable owner | Decides |
| --- | --- | --- |
| Bicep reference implementation | AI Landing Zone maintainers | Consumer contracts, defaults, topology, identity, and release content in this repository |
| Terraform implementation | Terraform AI Landing Zone (AVM pattern-module) maintainers | Terraform source, branches, AVM checks, merge, deployment, and release |
| Cross-implementation parity | AI Landing Zone maintainers with a Terraform maintainer reviewer | Capability classification, consumer impact, compatibility expectation, and scenario acceptance |
| Assessment approval | Parity reviewers listed on the `terraform-parity-publication` environment | Assessment outcome approval and publication authorization |
| Release metadata | AI Landing Zone maintainers | Matching manifest/changelog versions and explicit release approval; independent from historical comparison pins under proposed ADR-0006 |
| Baseline advancement | AI Landing Zone maintainers | A separate reviewed comparison change to `parity/config.json` and `parity/inventory.json`, including evidence and historical-record compatibility; never an automatic release-bump side effect |
| Rejected or closed proposals | Parity reviewers | Whether the gap is superseded, deferred, or stays open |
| Incidents and revocation | Repository administrators | Disabling workflows, revoking the GitHub App, rotating keys |
| Cleanup | Terraform maintainers for test subscriptions, AI Landing Zone maintainers for records | Deleting test deployments; superseding, never deleting, records |

Capability-level owners are recorded per capability in `parity/inventory.json` and
are reproduced in the generated view, so any parity question resolves to a named
owner from documentation alone.

This guard separation is [proposed, not approved](./adr/0006-release-metadata-and-comparison-baselines.md).
The candidate retains the existing Bicep `v2.6.1` and Terraform `v0.5.1`
comparison. No existing inventory, assessment, review, handoff or digest is
rewritten by the release bump. A future comparison advance must explicitly
address historical references; this proposal does not introduce that migration.

## 2. Assessment ownership rules

- Every pull request merged into `develop` after the adoption marker
  (`parity/assessments/adoption-marker.json`) needs exactly one assessment.
  `scripts/parity/Test-AssessmentCoverage.ps1` proves this in CI.
- Coverage recognizes standard `Merge pull request #123 from ...` subjects,
  custom `Merge pull request #123: ...` subjects, and squash subjects ending
  in `(#123)`. Each still requires exactly one record matching both the full
  merge commit SHA and pull request number. An unrecognized subject is not
  permission to bypass coverage or rewrite integration history.
- The assessment workflow creates the record with outcome `pending`. A parity
  reviewer records the final outcome and rationale with
  `scripts/parity/Set-AlignmentAssessment.ps1`.
- Supported outcomes are `no-terraform-impact`, `inventory-update`,
  `proposal-required`, `blocked`, `deferred`, and `superseded`. Outcome and
  rationale are writable only while the outcome is `pending`. A finalized record
  never changes outcome or rationale; it is superseded by a new reviewed record.
- Review status moves from `pending` to `approved`, `rejected`, or `superseded`.
  Approval and rejection are equally terminal: both require a reviewer, an
  absolute `https` review decision URL, and a review timestamp, both require an
  already recorded outcome, and neither can later change to anything except
  `superseded`. A superseded review is final.
- The nine backfilled records under `parity/assessments/` are a hand-assessed
  seed with `review.status=pending`. Their outcomes and rationales were written
  by hand before workflow activation. The final three records cover PRs #149,
  #150, and #152, whose assessment events could not run because the workflow
  was not yet present on the default branch. No approver, approval URL, or
  approval time is recorded, and no automation may treat these records as
  approved.
- Only `proposal-required` assessments may reference handoffs, and only an approved
  `proposal-required` assessment can authorize an alignment-provenance handoff.
- A rejected or closed Terraform proposal leaves its inventory gap open until a
  reviewed record supersedes it.

## 3. Branch protection prerequisites

Coverage is only provable when every change to the integration branch arrives
through a merged pull request. Configure both branches before activating the
workflows:

- `develop` (integration branch): require a pull request before merging, require
  at least one approving review, forbid direct pushes for every actor including
  administrators and apps, forbid force pushes, and forbid deletion. Without this
  protection a direct push produces a first-parent commit that no merged
  pull-request event can assess. `scripts/parity/Test-AssessmentCoverage.ps1`
  fails on such a commit and names it. The `-AllowUnattributedCommits` opt-out
  exists only for a repository that has not yet enabled this protection; using it
  weakens the guarantee to "every merged pull request is assessed" and must be a
  deliberate, reviewed choice. CI never passes that switch.
- `terraform-parity-assessments` (ledger branch): allow pushes only from the
  assessment workflow identity, require linear history, and forbid force pushes
  and deletions.

## 4. Ledger branch operations

- The ledger branch is `terraform-parity-assessments`. It is created once from the
  `develop` commit that contains the reviewed adoption marker and the
  hand-assessed seed, so the seed and the ledger agree:

  ```bash
  git switch --detach <develop-commit-with-adoption-marker>
  git switch -c terraform-parity-assessments
  git push origin terraform-parity-assessments
  ```

- The assessment workflow appends records only under `parity/assessments/` on that
  branch. It never writes to `develop` and never rewrites an existing record.
  `scripts/parity/Test-LedgerAppendOnly.ps1` enforces that contract in the
  workflow before anything is committed: the checkout must be on the ledger
  branch, and the only accepted change is a new `parity/assessments/*.json` file.
  Modifications, deletions, renames, and any path outside that directory fail the
  job.
- Retain the branch. Superseded records stay; history is never rewritten.
- Verify that the ledger branch exists before the first assessed merge.
  Initialize it from a reviewed `develop` commit containing the adoption marker
  and all current backfilled records, not an older incomplete seed. If checkout
  fails because the branch is absent, perform this one-time initialization and
  rerun the failed assessment job. Confirm its new pending record was appended
  before rerunning coverage validation; do not fabricate an approved outcome or
  use `-AllowUnattributedCommits` to hide the failure.
- The validation workflow refreshes its read-only ledger checkout after running
  tests, then validates the refreshed records before checking coverage. The
  assessment workflow can append a new record while those tests run; the initial
  checkout must not be treated as the current ledger. Fetch failures and missing
  assessments still fail explicitly. If the writer has not finished, wait for
  its successful completion before rerunning coverage; no record is inferred.
- To pause coordination, disable the workflows. Records and the branch remain
  readable, and no Azure resource or consumer contract is affected.

## 5. Protected environment and reviewers

- Environment name: `terraform-parity-publication`, used only by
  `.github/workflows/terraform-parity-publish.yml`.
- Configure required reviewers: at least one AI Landing Zone maintainer and one
  Terraform maintainer. Self-review by the change author is not accepted for a
  publication that originates from that author's assessment.
- Restrict the environment to the `develop` and `main` branches.
- Store `PARITY_DISPATCH_APP_ID` and `PARITY_DISPATCH_APP_PRIVATE_KEY` as
  environment secrets on that environment, never as repository-wide secrets.
- Publication is manual (`workflow_dispatch`) and takes only the approved handoff
  path. The workflow validates parity assets before minting any token.

## 6. GitHub App minimum permissions

| Setting | Required value | Reason |
| --- | --- | --- |
| Installation scope | `Azure/terraform-azurerm-avm-ptn-aiml-landing-zone` only | The App must not reach this repository or any other repository |
| Repository permission: Contents | Read and write | `repository_dispatch` requires the contents write permission on the target |
| Repository permission: Metadata | Read | Mandatory baseline permission |
| All other repository permissions | No access | Nothing else is needed to send a bounded dispatch |
| Organization permissions | No access | No organization data is used |
| Account permissions | No access | No user data is used |
| Webhooks | Disabled on the App | The App only sends dispatch events |
| Token lifetime | Ephemeral, minted per job by `actions/create-github-app-token` and revoked in the post step | No long-lived credential exists |

The App never receives Azure credentials, never writes to this repository, and
never has permission to merge or deploy anything.

## 7. Key rotation, audit, and revocation

- Rotate the App private key at least every 90 days and immediately after any
  suspected exposure or maintainer offboarding. Generate the new key first, update
  the environment secret, then delete the old key in the App settings.
- Audit quarterly: App installation scope and permissions, environment reviewers,
  `develop` and ledger branch protection, and the pinned action commits in
  `.github/workflows/terraform-parity-*.yml`.
- Audit trail sources: the protected-environment approval record, the publication
  workflow run, the dispatch event in the target repository, the handoff
  `approval` block, and the assessment `review` block.
- Revoke by deleting the App installation on the target repository or by removing
  the environment secrets. Revocation stops publication immediately and changes no
  Azure resource, no Bicep contract, and no existing record.
- Break-glass publication is prohibited. There is no bypass path for the protected
  environment, no personal access token, and no direct write from a maintainer
  workstation to the target repository on behalf of this automation. If publication
  is blocked, the gap stays open and the reason is recorded in the assessment.

## 8. Incident response

1. Disable `terraform-parity-assess.yml` and `terraform-parity-publish.yml`.
2. Revoke the App installation or its private key.
3. Record the incident as a superseding assessment or a reviewed inventory update;
   never delete or rewrite records.
4. Verify with `pwsh ./scripts/parity/Test-ParityAssets.ps1` and
   `npm run test:parity` that records still validate.
5. Re-enable only after the permissions, reviewers, and pinned actions pass the
   audit in section 7.

## 9. Operator commands

```powershell
pwsh ./scripts/parity/Test-ParityAssets.ps1
pwsh ./scripts/parity/Export-ParityMarkdown.ps1 -Check
git fetch --no-tags origin '+refs/heads/develop:refs/remotes/origin/develop'
pwsh ./scripts/parity/Test-AssessmentCoverage.ps1 -Branch origin/develop
pwsh ./scripts/parity/Test-LedgerAppendOnly.ps1 -GitRepositoryPath <ledger-checkout>
pwsh ./scripts/parity/New-AlignmentAssessment.ps1 -PullRequestNumber <n> -MergeCommitSha <sha> -BaseBranch develop -MergedAt <utc> -Merged true
pwsh ./scripts/parity/Set-AlignmentAssessment.ps1 -Path parity/assessments/<id>.json -Outcome <outcome> -Rationale '<why>'
pwsh ./scripts/parity/Set-AlignmentAssessment.ps1 -Path parity/assessments/<id>.json -ReviewStatus approved -Reviewer <handle> -ApprovalUrl <url> -ReviewedAt <utc>
pwsh ./scripts/parity/Set-AlignmentAssessment.ps1 -Path parity/assessments/<id>.json -ReviewStatus rejected -Reviewer <handle> -ApprovalUrl <url> -ReviewedAt <utc>
pwsh ./scripts/parity/New-TerraformHandoff.ps1 -Id handoff-<name> -ProvenanceType alignment-assessment -AssessmentPath parity/assessments/<id>.json -CapabilityIds <ids> -OutputPath parity/handoffs/<area>/<name>.json
git worktree add --detach .parity-ledger origin/terraform-parity-assessments
$handoffCommitSha = git rev-parse HEAD
pwsh ./scripts/parity/Test-ParityAssets.ps1 -AssessmentsPath .parity-ledger/parity/assessments
pwsh ./scripts/parity/Publish-TerraformHandoff.ps1 -HandoffPath parity/handoffs/<area>/<name>.json -HandoffCommitSha $handoffCommitSha -HandoffRef develop -AssessmentsPath .parity-ledger/parity/assessments -PayloadPath .parity-dispatch/payload.json
```

Always fetch before proving coverage and validate against `origin/develop`. A
local `develop` ref is a stale snapshot, so `-Branch develop` can pass or fail
for reasons that have nothing to do with the ledger. CI performs the same fetch.

Publication in CI adds `-DispatchCommand` so that only the protected job sends the
payload. Locally, omit it: the script then writes the bounded payload and performs
no network call. The handoff and schema must be committed at `HandoffCommitSha`,
that SHA must be the checked-out `HEAD`, and `HandoffRef` must be the configured
integration branch. The pinned source and target commits remain comparison
baselines and are never used as artifact fetch locations. Alignment assessments
must be read from the protected ledger checkout; the frozen seed on `develop`
is not an ongoing assessment source.
