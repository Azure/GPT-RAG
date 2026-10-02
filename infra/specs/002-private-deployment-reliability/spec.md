# Feature Specification: Reproducible private deployments

**Feature Branch**: `placerda-private-deployment-plan`
**Created**: 2026-09-18
**Status**: Draft for implementation planning
**Input**: Plan the implementation of issues [#159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159) and [#160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160) together.

No existing specification covered these issues. This document consolidates
their published requirements as the input to `/speckit-plan`; it does not
authorize implementation, Azure deployment, or a release.

## User Scenarios & Testing

### User Story 1 - Provision a private build pool on the first attempt (P1)

An operator brings an existing VNet without the build-agent subnet and asks
the landing zone to create its subnets and an ACR Task agent pool. The pool
must wait for subnet creation rather than requiring a retry.

**Independent test**: A compiled-template dependency assertion and an approved
cold-start deployment with no pre-existing build subnet.

**Acceptance scenarios**:

1. Given network isolation, BYO VNet, subnet/NSG creation, ACR and its pool are
   enabled, the subnet deployment succeeds before the pool starts provisioning.
   The pool reaches `Succeeded` with the requested count, initially S1 / 1.
2. Given an already-present build subnet with `deploySubnets=false`, the pool
   can deploy without attempting to run a disabled subnet deployment.
3. Given a template-created VNet, its existing implicit dependency is preserved.
4. Given a disabled pool, disabled registry, or standard deployment, no pool is
   created; existing disabled-state outputs remain unchanged.
5. Given unrelated subnets in the BYO VNet, their configuration is unchanged.

### User Story 2 - Declare a durable Storage access profile (P1)

A consumer configures the solution Storage account's bypass, resource-instance
rules, and Shared Key policy in its deployment inputs instead of repairing the
account after reprovisioning.

**Independent test**: Compiled input-to-resource forwarding checks, followed by
two approved deployments with identical explicit settings.

**Acceptance scenarios**:

1. Omitted new inputs retain the existing effective `AzureServices` bypass,
   no configured resource-instance rules, and Shared Key allowed behavior.
2. Explicit `None`, `false`, and the supplied typed rules reach solution
   Storage unchanged.
3. An explicitly approved, already-configured Defender scanner exception
   remains the exact desired exception after repeated deployment.
4. Without configured Defender, no scanner, plan, role, or exception is added.
5. Public deployments and other Storage accounts retain their existing behavior.

### User Story 3 - Migrate existing accounts without hidden exceptions (P2)

Operators can determine which ACLs the template owns, how to migrate key-based
clients, and which evidence proves rule preservation versus working scanning.

**Independent test**: Follow documented omitted/default, private/keyless,
scanner-enabled, and existing-account migration examples.

**Acceptance scenarios**:

1. Documentation explains that the supplied rule list is desired state, not
   an instruction to merge arbitrary live exceptions.
2. Shared Key is disabled only after the operator evaluates affected clients,
   SAS tokens, and any file-share consumers.
3. ACL preservation and actual Defender scanning have separate outcomes.
4. Consumers update their normal infrastructure pin and parameter overlay,
   not a generated `infra/` checkout.

### Edge cases

- `deployNsgs=false` with BYO subnet creation remains an invalid combination
  under the existing component validation; the ordering fix must not bypass it.
- A missing subnet with `deploySubnets=false` remains an operator prerequisite
  failure, not permission to create or discover it automatically.
- `allowedIpRanges` continues to control public access and default action.
  `bypass=None` alone does not guarantee private-only access.
- An empty rule list removes template-managed exceptions; it does not preserve
  an externally installed scanner exception automatically.
- Invalid bypass values, malformed rule objects, and wrong Boolean types fail
  validation instead of becoming permissive defaults.
- Top-level null for a defaulted parameter follows Bicep's omission/default
  semantics; it does not request private/keyless access. Required nested rule
  fields remain non-null. Concrete `None` and `false` select the stricter profile.
- Azure Policy may deny or modify a deployment. Desired template values and
  effective Azure properties must be recorded separately.

## Requirements

| ID | Requirement | Source |
| --- | --- | --- |
| FR-159-01 | Establish an ARM dependency from the enabled agent pool to enabled BYO subnet creation. | #159 |
| FR-159-02 | Preserve new-VNet, existing-subnet, disabled-pool, and unrelated-subnet behavior. | #159 |
| FR-159-03 | Add a compiled regression assertion and prove cold-start success with the requested workers. | #159 |
| FR-160-01 | Expose typed bypass, resource-instance-rule list, and Shared Key inputs for solution Storage. | #160 |
| FR-160-02 | Preserve omitted-input effective defaults and public-mode compatibility. | #160 |
| FR-160-03 | Forward explicit values through pinned AVM 0.26.2 without a required upgrade. | #160 |
| FR-160-04 | Reconcile supplied rules as desired state and retain them across identical deployments. | #160 |
| FR-160-05 | Do not provision Defender, its scanner, roles, plans, or inferred exceptions. | #160 |
| FR-160-06 | Document inputs, ACL ownership, existing-account migration, and separate scanning verification. | #160 |
| FR-X-01 | Preserve existing feature gates, public access/IP rules, DNS, RBAC, naming, outputs, and consumer overlays except for the requested changes. | Both; constitution |

### Key entities

Build topology and deployment dependency; solution Storage access profile;
resource-instance rule; validation scenario and evidence record. Their design
is defined in [data-model.md](data-model.md).

## Success Criteria

| ID | Observable outcome |
| --- | --- |
| SC-159-01 | Compiled graph contains the BYO dependency; approved fresh deployment shows subnet completion before pool start and `Succeeded` / requested worker count without retry. |
| SC-159-02 | Compatibility scenarios remain valid and unrelated BYO subnets have identical before/after configuration. |
| SC-160-01 | Default and explicit profiles resolve to the expected solution Storage properties; unaffected resources retain baseline semantics. |
| SC-160-02 | Two consecutive deployments retain exactly the approved rule set, bypass and Shared Key setting without manual network repair. |
| SC-160-03 | A no-Defender scenario creates zero Defender resources, roles, plans, or rules; scanning evidence is reported separately where enabled. |
| SC-X-01 | Documentation and targeted CI coverage accompany implementation; live results are never inferred from compilation or preview. |

## Assumptions and exclusions

The two implementation slices are independently deliverable; #160 does not
depend on #159. A shared plan and combined regression pass coordinate their
changes to `main.bicep`, CI, and the resource-graph fixture.

No VPN, NSP, VM, firewall redesign, auxiliary Foundry Storage change, new
runtime key/output, AVM upgrade, or GPT-RAG implementation is requested.
Test subscription, resource groups, scanner identity, region/capacity, spending,
and deployment approval must be supplied at live-validation time. They are
execution prerequisites, not values to guess or commit.
