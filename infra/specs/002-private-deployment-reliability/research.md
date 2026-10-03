# Research: Reproducible private deployments

Date: 2026-09-18. These are proposed implementation decisions, not deployed fixes.

## R1 - Fix ordering at the resource that needs the subnet

**Decision:** Explicitly depend on `virtualNetworkSubnets` from the pool;
retain current IDs and gates.

**Rationale:** `main.bicep`'s `virtualNetworkResourceId` uses the supplied VNet
ID in BYO mode, not a subnet-deployment output. The pool constructs its subnet
ID from that value. The subnet module is conditional on isolation, BYO VNet,
subnet creation and NSG creation; the pool is conditional on registry, isolation
and pool flags. A string ID cannot establish the missing dependency. The
new-VNet branch already consumes `virtualNetwork.outputs.resourceId`.
ARM removes explicit dependencies on conditionally skipped resources. The
whole subnet module is the current completion boundary and serializes writes.

**Alternatives considered:** Export and consume a subnet ID (viable but expands
the module interface/branching); retain the race and retry (fails acceptance).
Sleeps or public-access workarounds are not acceptable.

**Evidence:** `main.bicep` symbols `virtualNetworkResourceId`,
`virtualNetworkSubnets`, `_deployAcrTaskAgentPool`, `acrTaskAgentPool`;
`modules/networking/subnets.bicep` `subnetsM`; [dependency guidance][1] and
[conditional deployment guidance][2]. #124 addressed firewall bootstrap and
firewall-policy ordering, not this edge.

## R2 - Use the pinned Storage AVM

**Decision:** Retain AVM 0.26.2; expose three independent inputs defaulting to
`AzureServices`, `[]`, `true`, with exported shared types in `constants/`.

**Rationale:** Upstream tag resolves to
`579eb412504f107edb8b0fbd875764e4cdc256af`. It declares
`allowSharedKeyAccess bool = true` and a nullable ACL object with optional
`resourceAccessRules`, requiring string `resourceId` and `tenantId` per entry.
It forwards these to Storage API `2024-01-01`. `[]` is the proposed wrapper
default for no desired exceptions, not an AVM parameter default.
Current solution Storage hardcodes bypass, omits rules and inherits true.

**Alternatives considered:** A typed settings object (viable but unnecessary
for three named inputs); AVM upgrade/new wrapper (unnecessary); manual repair
(not reproducible).

**Evidence:** [AVM parameters][3], [forwarding][4], [ACL type][5];
local `main.bicep` `storageAccount` module.

## R3 - Exact allowed values and native types

**Decision:** Accept the pinned eight bypass spellings: `None`,
`AzureServices`, `Logging`, `Metrics`, `AzureServices, Logging`,
`AzureServices, Metrics`, `AzureServices, Logging, Metrics`, `Logging, Metrics`.
Use sealed rules with required nonempty fields and native JSON defaults.

**Rationale:** Match AVM's comma-space formatting and ordering. Keep `false`
a Boolean, not a truthy string. Existing parameter-file overlays support
native arrays/objects. No new environment alias means no JSON-string parser,
precedence rule or empty-substitution path. Omitted inputs use Bicep defaults;
empty strings and invalid concrete values are not permissive fallback profiles.
The pinned compiler treats top-level null assignments for defaulted inputs as
omission/default selection, distinct from required nested rule fields.

**Alternatives considered:** Scalar aliases plus JSON-string rules (additional
parsing/failure paths); untyped arrays/objects (weaker validation).
String typing does not prove GUID validity, resource existence, supported
resource type or same-tenant eligibility; those remain Azure/operator checks.

**Evidence:** [Pinned union][5], existing `main.parameters.json` arrays, and
[public parameter-file customization guidance][9].

## R4 - Explicit ACL ownership; optional external Defender

**Decision:** Forward the complete supplied list without live merge, discovery,
wildcard generation, automatic scanner creation or role assignment.

**Rationale:** Trusted/resource-instance exceptions may remain effective with
PNA disabled. They grant network eligibility, not data permissions, and require
eligible same-tenant instances. Preserve the exact operator-approved scanner
ARM ID and tenant, not a guessed solution-RG ID or principal ID. Upstream
Security examples contain both subscription- and RG-scoped
`Microsoft.Security/dataScanners/StorageDataScanner` resources.
An empty list does not preserve external exceptions; concurrent ACL owners
must coordinate explicitly.

**Alternatives considered:** Merge all live rules (nondeterministic and possibly
overpermissive); deploy Defender (out of scope); dismiss bypass because PNA
is disabled (contradicts current documentation).

**Evidence:** [Storage limitations][6], [resource-instance rules][7],
[Defender requirements][8], [subscription scanner example][10],
[RG scanner example][11].

## R5 - Shared Key disabled is not key-free deployment

**Decision:** Opt-in false; document consumer migration and retained AVM
management-plane `listKeys()` behavior.

**Rationale:** Local solution consumers use Storage IDs/endpoints, not access-key
outputs. Still, AVM contains four secure outputs calling `listKeys()` plus
optional secret-export logic. The new flag governs data authorization, not
those management-plane calls. Do not infer guaranteed deployment failure or
absence of key-listing activity.
Entra authorization/Blob user-delegation SAS differ from account/service SAS,
which fail when Shared Key is disabled. Inventory external key clients and
Azure Files consumers before opting in. Add no new keys, roles or secrets.

**Alternatives considered:** Change global default (breaks compatibility);
patch AVM key outputs (separate scope); add runtime flags (no consumer need).

**Evidence:** [Shared Key guidance][12], [AVM secure outputs][13],
`main.bicep` Storage output consumers and centralized roles.

## R6 - Focused static tests plus separate runtime proof

**Decision:** Add two focused PowerShell contracts; preserve graph, firewall,
component, preflight and size checks. Require approved live evidence separately.

**Rationale:** Both changed resources currently have protected graph hashes
under Bicep 0.42.1. Recognize only their intentional changes, never regenerate
all hashes. Nested AVM Storage `properties` may be a `shallowMerge` ARM
expression string. Assert exact root/module/resource forwarding and resolve
controlled values for each case; fail explicitly on unexpected shapes.
A retry cannot prove cold start, and ACL equality cannot prove scanning.

**Alternatives considered:** Wholesale rebaselining (hides unrelated changes);
source regex only (not compiled proof); use preview as runtime proof (invalid).

**Evidence:** Existing `tests/contracts/` scripts and graph fixture;
[compiled AVM][14]; [Defender operational verification][15].

## Investigation limits

**Validation refinement (2026-09-18):** Actual-root `.bicepparam` and module
fixtures proved Bicep 0.42.1 accepts explicit null for all three defaulted inputs.
Pinned [SemanticModel source][16] explicitly treats a null parameter assignment
as absent when checking required parameters. S9's original compiler-rejection
expectation for top-level null was therefore incorrect. Tests now distinguish
native optional/default selection from invalid concrete values and nested rule
fields; no product fallback, nullable declaration, compiler upgrade or broader
bypass is introduced. Compiler acceptance does not substitute for live Azure
parameter/property validation. Operators must explicitly supply `None`/`false`
to request stricter access.

**Implementation refinement (2026-09-18):** The original placement of the two
new types in `constants/constants.bicep` caused Firewall's wildcard import to
emit both unused type definitions and a different generated template hash.
Compiled baseline comparison identified those exact differences. The types
were moved to focused `constants/storage-types.bicep`, imported by the root
as `storageTypes`; no Firewall source or validation exemption is needed.
This changes only internal type placement, not public inputs or deployment
behavior, and preserves the original shared-constants surface.

The Azure best-practices router timed out twice. Current Microsoft Learn
Bicep best practices, dependency guidance and pinned AVM provided the fallback.
No router result, product build, Azure resource inspection or deployment is
claimed. No unresolved design questions remain; live scope/approval and release
selection are future human inputs. Integration ancestry is recorded in the plan.

[1]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/resource-dependencies
[2]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/conditional-resource-deployment
[3]: https://github.com/Azure/bicep-registry-modules/blob/579eb412504f107edb8b0fbd875764e4cdc256af/avm/res/storage/storage-account/main.bicep#L64-L81
[4]: https://github.com/Azure/bicep-registry-modules/blob/579eb412504f107edb8b0fbd875764e4cdc256af/avm/res/storage/storage-account/main.bicep#L435-L453
[5]: https://github.com/Azure/bicep-registry-modules/blob/579eb412504f107edb8b0fbd875764e4cdc256af/avm/res/storage/storage-account/main.bicep#L785-L816
[6]: https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-limitations
[7]: https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-resource-instances
[8]: https://learn.microsoft.com/en-us/azure/defender-for-cloud/introduction-malware-scanning
[9]: https://github.com/Azure/AI-Landing-Zones/blob/main/docs/bicep/parameterization.md
[10]: https://github.com/Azure/azure-rest-api-specs/blob/cd0309a346719a0c30931fc927e09b917046d129/specification/security/resource-manager/Microsoft.Security/Security/stable/2026-08-01/examples/DataScanners/GetDataScanner.json
[11]: https://github.com/Azure/azure-rest-api-specs/blob/cd0309a346719a0c30931fc927e09b917046d129/specification/security/resource-manager/Microsoft.Security/Security/stable/2026-08-01/examples/DataScanners/GetDataScannerResourceGroupScope.json
[12]: https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent
[13]: https://github.com/Azure/bicep-registry-modules/blob/579eb412504f107edb8b0fbd875764e4cdc256af/avm/res/storage/storage-account/main.bicep#L740-L754
[14]: https://github.com/Azure/bicep-registry-modules/blob/579eb412504f107edb8b0fbd875764e4cdc256af/avm/res/storage/storage-account/main.json#L1450-L1462
[15]: https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-storage-test
[16]: https://github.com/Azure/bicep/blob/v0.42.1/src/Bicep.Core/Semantics/SemanticModel.cs
