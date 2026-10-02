# ADR-0005: Explicit private-build ordering and solution Storage access inputs

- Status: proposed
- Date: 2026-09-18
- Owners: AI Landing Zone maintainers; deploying operators own access-profile approval.
- Related issues: [#159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159), [#160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160)
- Design: [implementation plan](../../specs/002-private-deployment-reliability/plan.md)

## Context

An ACR Task agent pool can start before its BYO subnet exists because its
constructed subnet ID does not depend on the subnet-creation module.
Separately, solution Storage hardcodes `AzureServices`, omits instance rules,
and inherits AVM Shared Key `true`. Consumers cannot declare a durable stricter
profile or preserve an approved scanner exception through normal reprovisioning.

The requested changes are independent. Keep the orchestrator and resource
ownership unchanged, preserve standard/isolated behavior, and make stricter
Storage access explicit rather than globally changing defaults.
Source and platform evidence are in [research.md](../../specs/002-private-deployment-reliability/research.md).

## Prioritized characteristics

| Characteristic | Priority | Measure |
| --- | --- | --- |
| Backward compatibility | 1 | Omitted inputs retain effective defaults; unchanged gates, outputs and auxiliary resources. |
| Deployment correctness | 2 | Subnet completion precedes pool start; fresh pool reaches requested worker count without retry. |
| Reproducible access | 3 | Two identical deployments retain the exact selected ACL/key policy. |
| Least surprise / explicit ownership | 4 | No inferred exceptions, live ACL merge, Defender plan, scanner or new role. |
| Bounded operational impact | 5 | Existing resource count and module pins; size gate unchanged; only one new ordering edge. |

## Alternatives considered

### Option A - Existing completion boundary and three typed inputs

Depend directly on the conditional BYO subnet module. Add the three named
Storage parameters and forward through AVM 0.26.2. Use native JSON parameter
values and shared exported types. This minimizes topology/interface changes
while making rule ownership clear. Migration is opt-in; no RBAC expansion.

### Option B - Subnet-output interface and one Storage settings object

Export the created build subnet ID from the networking module and consume it
for implicit dependency. Expose one typed Storage configuration object.
Both are viable, but add output/branching or nested default handling without
additional requested capability. They require wider compatibility testing and
are harder to reverse once downstream consumers adopt the extra interfaces.

### Do not change

Cold starts retain a race and retries mask it. Storage overrides remain
unrepresentable and manual repair is lost on subsequent deployments. This
fails both issues' requirements.

## Decision

Propose Option A. The pool explicitly depends on `virtualNetworkSubnets`;
ARM removes that dependency when the module is conditionally skipped. Retain
the existing implicit new-VNet dependency and parent registry dependency.
Do not add conditional output dereferences, sleeps or unrelated firewall edges.

For solution Storage, add `storageAccountNetworkAclsBypass`,
`storageAccountResourceAccessRules` and `storageAccountAllowSharedKeyAccess`,
defaulting to `AzureServices`, `[]` and `true`. Use AVM's exact eight-value
bypass union and sealed rule entries with required nonempty ID/tenant strings.
Native JSON values avoid new environment parsing/empty-substitution behavior.
This proposed ADR does not constitute deployment or release approval.

Implementation evidence refined type placement to
`constants/storage-types.bicep`, imported only by the root. Placing the new
exports in `constants/constants.bicep` propagated unused schemas through
Firewall's wildcard import. The focused file preserves unrelated compiled
modules without weakening their graph checks or changing networking source.

## Consequences

First-attempt correctness replaces operator retry, at the cost of waiting for
the existing whole subnet deployment. No additional infrastructure is created.
A successfully provisioned nonzero pool incurs its existing worker charges.
No Defender charges are activated by this feature.

The operator owns the complete rule list; external controllers changing the
same ACL need coordination. Explicit defaults do not preserve arbitrary drift.
Native parameter-file overlays, rather than new `azd env set` aliases, are the
supported customization path for these inputs.

## Compatibility and migration

Preserve PNA/IP/default-action/VNet rules, private endpoints, auxiliary Foundry
Storage, naming modes, overrides, modules, manifest and runtime outputs.
Explicit true/empty rules can change template representation without changing
default intent. Azure Policy still determines whether values are accepted or
modified at deployment.

Before disabling Shared Key, inventory key/connection-string and account/service
SAS clients, migrate/test supported Entra or Blob user-delegation paths, and
evaluate any Azure Files consumers. Copy only reviewed required exceptions
into the overlay; do not scrape and import all live exceptions.

Consumers such as GPT-RAG use their normal compatible infrastructure pin and
parameter-overlay workflow, not edits to generated `infra/`. #159 is patch
scope; the additive #160 contract makes a combined release minor and requires
Portal/Terraform parity review. No version is selected by this decision.

## Security and identity

No new role or principal. Resource-instance rules are network eligibility,
not data authorization. Same-tenant/resource validity needs Azure/operator
verification. Supply the exact approved scanner ARM ID, which can have a
different scope from the solution account; do not fabricate it.

PNA disabled does not make trusted/resource-instance exceptions irrelevant.
`bypass=None` alone does not make a public/IP-enabled account private.
Shared Key false does not remove AVM 0.26.2's secure `listKeys()` outputs.
No scanner, Defender activation, access grant or key publication is added.

Keep native Bicep optional/default semantics: a top-level null assignment to
a defaulted parameter is not an explicit private/keyless profile. Operators
must select `None` and Boolean `false`; required nested rule fields remain
non-null and nonempty. Compiler acceptance and live Azure validation are
separate evidence levels, not grounds for a new permissive product fallback.

## Adoption and rollback

The integration prerequisite was completed through #161: `develop` contains
`main` commit `e7847ce83d0a13a029eb554e6075d7ccba8c6afa`. The subsequent,
separately approved parity-recovery fixes are merged through #163; feature
implementation starts from `e58f3f968b5f5955ee3ad458d666323d3be31ee1`.
Deliver #159 first if practical, then #160; integrate focused
tests, graph-fixture exceptions, CI and docs with each slice.

Use explicit approval for cold-start and repeated-deployment test environments.
Prefer roll-forward for an opted-in profile. An old template can restore broad
bypass and remove approved rules; reverting to it is not a safe automatic
rollback. Re-enabling Shared Key/bypass needs operator/security approval.
Reverting #159 restores the race. Do not delete Storage, unrelated subnets or
external scanners as a rollback mechanism.

## Compliance verification

Use the [validation guide](../../specs/002-private-deployment-reliability/quickstart.md).
Require compile/lint/size, focused dependency and nested forwarding tests,
existing graph/firewall/component/preflight contracts and reviewed previews.
Live proof includes cold-start operation ordering, requested worker count,
unrelated-subnet preservation and two-deployment exact ACL persistence.
Consumer authentication and Defender scanning are separate outcomes.
Compilation and preview are not runtime proof.

## Documentation impact

Implementation updates README, changelog, test documentation and both topology
runbooks. Link the companion `Azure/AI-Landing-Zones` `main` documentation
change for parameterization/deployment guidance. Keep the approved parity
baseline and generated inventory untouched until their separate reviewed
advance; follow the existing human-gated assessment/handoff process.

### Coordination review status

| Surface | Impact | Status |
| --- | --- | --- |
| Portal landing zone | Review equivalent operator-selected Storage settings and private-build ordering; do not change Portal defaults implicitly. | Maintainer review pending; no Portal implementation or runtime parity claimed. |
| Terraform `container-registry-private-build` | Assess the explicit subnet-before-pool completion requirement for the network-isolated scenario. | Assessment/handoff approval pending. |
| Terraform `data-services-contract` | Assess the three typed solution Storage inputs in standard and network-isolated scenarios, preserving defaults and explicit rule ownership. | Assessment/handoff approval pending. |
| Public Bicep documentation | Companion parameterization and deployment guidance. | Local draft work coordinated separately; publication not authorized by this ADR. |

#### Release engineering source review

A bounded read-only review was completed against Portal commit
`76431d6a2ee8fc92ee0f0c8493bc3540e549c9d8`, Terraform's approved comparison
commit `abe337894f93de3ddda525ea44898b33e1484070`, and observed Terraform
`main` commit `ffe3d5aa4b1763fd23c864fe2803eaf5f75020af`.
These are source findings, not maintainer approval or runtime parity:

- Portal's [solution Storage input](https://github.com/Azure/AI-Landing-Zones/blob/76431d6a2ee8fc92ee0f0c8493bc3540e549c9d8/portal/template.json)
  hardcodes `networkAcls.bypass=AzureServices` and `defaultAction=Allow`, sets
  PNA Disabled, and omits Shared Key and resource-instance-rule selection.
  Its [Storage wrapper](https://github.com/Azure/AI-Landing-Zones/blob/76431d6a2ee8fc92ee0f0c8493bc3540e549c9d8/portal/wrappers/avm.res.storage.storage-account.json)
  already forwards `allowSharedKeyAccess` and `networkAcls`, with nested support
  for resource-instance rules and Shared Key default true. The gap is the
  solution input/form wiring, not a need to assume a new Storage provider.
- Terraform's [solution Storage input type](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/blob/ffe3d5aa4b1763fd23c864fe2803eaf5f75020af/variables.genai_services.tf)
  exposes `shared_access_key_enabled` with default true, and its
  [module call](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/blob/ffe3d5aa4b1763fd23c864fe2803eaf5f75020af/main.genai_services.tf)
  forwards it to Storage AVM 0.6.6. Neither surface exposes/forwards solution
  bypass or resource-instance rules. These relevant definitions are unchanged
  at the approved comparison pin. Preserve Terraform's existing PNA/SKU
  defaults rather than silently aligning unrelated settings.
- No ACR agent-pool surface was found in the reviewed Portal template/form/
  registry wrapper or Terraform GenAI-service/build inputs. Terraform's
  [build implementation](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone/blob/ffe3d5aa4b1763fd23c864fe2803eaf5f75020af/main.build.tf)
  uses a VM with `local.subnet_ids["DevOpsBuildSubnet"]`, not the Bicep ACR
  Task pool. Do not mechanically copy the pool-specific dependency into a
  different build topology; review private-build equivalence separately.

Recommended follow-up is explicit Portal solution/form and Terraform bypass/
resource-rule exposure under the existing human-gated process. Shared Key
already has a Terraform input. No external source, comparison pin, inventory,
ledger, approval or handoff was changed by this review.

#159 alone is patch scope; the combined additive contract is minor scope.
No version or release pin has been changed. The existing parity inventory,
generated inventory documentation and Terraform repository remain unchanged.
Formal post-merge assessments and any proposal publication require the
existing review/approval process; these pending entries are not approvals.

## Review trigger

Revisit if the Storage AVM/API changes the allowed fields or secure key outputs,
ARM conditional-dependency semantics change, another consumer needs a subnet
output/environment alias, an external ACL controller competes for ownership,
or live tests expose a distinct ordering, authorization or scanner failure.
