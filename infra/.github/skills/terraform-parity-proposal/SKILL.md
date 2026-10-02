---
name: terraform-parity-proposal
description: Converts an approved structured parity handoff into a read-only, human-reviewable proposal plan for the allow-listed Terraform repository.
---

# Terraform parity proposal

## Boundary

- Bicep is the source of truth and this repository remains read-only.
- The only target is
  `Azure/terraform-azurerm-avm-ptn-aiml-landing-zone`.
- Terraform source belongs only in the target repository.
- Never use credentials, merge, deploy, release, publish, create a pull request,
  or bypass target-repository review and branch protection.

## Workflow

1. Validate the handoff against `parity/schemas/terraform-handoff.schema.json`.
2. Require `approval.status=approved` and exactly one valid, immutable
   provenance form. Pending, rejected, and superseded drafts cannot be consumed,
   dispatched, or used for T033. Stop if the baseline is stale.
3. For approved baseline provenance, require `inventoryCommitSha` and
   `inventoryReviewUrl`; use `git show
   <inventoryCommitSha>:parity/inventory.json`, hash its exact bytes, and verify
   its baseline ID and Bicep/Terraform commits. Never infer the inventory commit
   from `source.commitSha`. Issue #136 supplies context, not review or approval.
4. Confirm every capability exists in the active inventory and the source and
   target repositories, refs, and commits match `parity/config.json`.
5. Reject Terraform source, secrets, tenant or subscription IDs, private
   addresses, and environment-specific names in the handoff.
6. Read only the cited Bicep contracts and the allow-listed target baseline.
7. Produce a proposal plan, not a patch. Keep standard and network-isolated
   implications independent.
8. Hand the plan to a human-approved contribution workflow in the target
   repository.

## Acceptance checklist

- Existing inputs, outputs, and defaults are preserved, or migration,
  deprecation, and semantic-version impact are explicit.
- Required behavior and acceptance criteria cover every capability.
- Managed identity and least-privilege control-plane and data-plane RBAC are
  preferred.
- Local authentication, secret handling, public access, private endpoints,
  DNS, routes, subnet delegation, and dependency ordering are explicit.
- AVM formatting, lint, documentation, examples, tests, and pattern-module
  checks are identified.
- Hub-spoke and arbitrary optional-feature combinations remain excluded.
- Each scenario requires its own approved deployment and reviewed comparison;
  static validation and plan output do not prove parity.

## Exit conditions

Return the proposal plan, affected contracts, expected semantic-version impact,
target validation commands, evidence still required, exclusions, and open
risks. Stop without a plan if approval, provenance, allow-list, capability,
security, or compatibility checks fail. Never claim parity or perform a write.
