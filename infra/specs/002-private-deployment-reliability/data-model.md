# Data model: Deployment inputs and evidence

These are declarative infrastructure models, not application tables or a new
database. Details are in the [Storage](contracts/solution-storage-inputs.md)
and [ACR](contracts/acr-subnet-ordering.md) contracts.

## Build topology

| Field | Type / existing default | Role |
| --- | --- | --- |
| `networkIsolation` | Boolean / false | Enables private topology. |
| `useExistingVNet` | Boolean / unchanged | Selects BYO instead of the VNet module output. |
| `existingVnetResourceId` | String / unchanged | Operator-owned VNet identity. |
| `deploySubnets` | Boolean / unchanged | Whether ALZ creates/updates BYO subnets. |
| `deployNsgs` | Boolean / true | Required for BYO subnet mutation under existing validation. |
| `deployContainerRegistry` | Boolean / true | Parent registry gate. |
| `deployAcrTaskAgentPool` | Boolean / true in Bicep; false in the azd parameter-file mapping | Existing independent pool selection; both defaults are preserved. |
| `devopsBuildAgentsSubnetName` | String / `devops-build-agents-subnet` | Existing subnet name contract. |
| `acrTaskAgentPoolTier` | S1, S2 or S3 / S1 | Pool tier. |
| `acrTaskAgentPoolCount` | Integer >= 0 / 1 | Requested workers; 0 remains supported. |

**Relationships:** The enabled pool depends on its registry and the enabled
deployment creating its subnet. The new edge targets the entire BYO subnet
deployment. A string reference to an existing subnet is not subnet creation.

**State transitions:** Fresh BYO: subnet deployment pending -> succeeded ->
pool provisioning -> pool succeeded. A failed subnet deployment blocks the
pool through the dependency. With `deploySubnets=false`, subnet existence is
external. Disabled resources are skipped, not waited on. No recovery state
machine is added.

## Solution Storage access profile

| Field | Proposed type | Default |
| --- | --- | --- |
| `storageAccountNetworkAclsBypass` | `storageTypes.storageAccountNetworkAclsBypassType` | `AzureServices` |
| `storageAccountResourceAccessRules` | `storageTypes.storageAccountResourceAccessRuleType[]` | `[]` |
| `storageAccountAllowSharedKeyAccess` | Boolean | `true` |

**Relationship:** Belongs only to the solution `storageAccount` module. Combine
it with existing public-access/default-action/IP/VNet-rule logic, rather than
replacing that logic or configuring `aiFoundryStorageAccount`.

**State transition:** Deployment reconciles these three desired properties.
Identical redeployment converges to the same configuration. Omission selects
defaults, not live state. Top-level optional-null selection follows the native
Bicep default contract, not a stricter access profile. An empty list means no
resource-instance exceptions.

## Resource-instance rule

| Field | Type validation | Meaning |
| --- | --- | --- |
| `resourceId` | Required nonempty string | Complete ARM ID supplied by the operator. |
| `tenantId` | Required nonempty string | Tenant containing the eligible instance. |

The exported Bicep type is sealed. Missing fields, extra misspelled fields,
nulls and wrong types are rejected by typed validation. Azure/operator checks
must establish ID validity, supported resource type, same-tenant eligibility
and existence; a string type does not establish those facts.

Forward without automatic normalization, discovery, sorting or deduplication.
Operators provide unique, approved entries. A scanner is one possible instance
type, not a new ALZ resource, principal, role assignment or Defender plan.

## Validation scenario and evidence

| Field | Meaning |
| --- | --- |
| `scenarioId` | ACR or Storage matrix identifier. |
| `sourceCommit`, `compilerVersion` | Exact template/compiler under test. |
| `inputs` | Sanitized effective inputs; never commit credentials or live tenant/subscription IDs. |
| `evidenceLevel` | Contract, preflight, preview, deployment, data plane or scanner operation. |
| `expected`, `observed`, `result` | Explicit assertions; result is pass, fail or not run. |
| `deploymentOperations` | Cold start: subnet completion, pool start, final count/state. |
| `beforeAfter` | Complete Storage rules and unrelated-subnet configuration. |
| `approvalReference` | Authorization for live work, not inferred from this plan. |
| `scannerResult` | Separate observation, not derived from ACL equality. |

Attach evidence to implementation review or approved operational storage, not
as product resources. Provider-maintained metadata may be excluded from subnet
comparisons; configuration fields may not.
