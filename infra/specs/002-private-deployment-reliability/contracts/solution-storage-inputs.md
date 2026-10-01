# Contract: Solution Storage access inputs

Proposed additive contract for [#160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160).
Unavailable until implementation is merged.

## Public input and forwarding

| Parameter | Type / default | Owning AVM parameter |
| --- | --- | --- |
| `storageAccountNetworkAclsBypass` | Exact string union / `AzureServices` | `networkAcls.bypass` |
| `storageAccountResourceAccessRules` | Sealed `{resourceId: string, tenantId: string}[]` / `[]` | `networkAcls.resourceAccessRules` |
| `storageAccountAllowSharedKeyAccess` | Boolean / `true` | `allowSharedKeyAccess` |

Declare described/exported `storageAccountNetworkAclsBypassType` and
`storageAccountResourceAccessRuleType` in `constants/storage-types.bicep`,
consumed through `storageTypes`. Rule fields are required and nonempty.
The focused type file avoids exporting unused schemas into unrelated modules
that wildcard-import the existing shared constants.

Allowed bypass values exactly match AVM 0.26.2:

| Individual values | Combinations |
| --- | --- |
| `None`, `AzureServices`, `Logging`, `Metrics` | `AzureServices, Logging`; `AzureServices, Metrics`; `AzureServices, Logging, Metrics`; `Logging, Metrics` |

Empty strings, unsupported spellings and wrong types are not fallback profiles.
Existing parameter files can omit inputs and use Bicep defaults. Bicep 0.42.1
also accepts top-level `null` for these defaulted parameters as omission/default
selection. It must not be interpreted as `None` or `false`; operators must
provide those concrete values for the stricter profile. This does not make
required fields inside a resource-instance rule nullable.

## Parameter-file and azd surface

Use native JSON defaults, without environment aliases, a stringified array or
secondary JSON input. This fragment belongs inside the parameter file's
`parameters` object; it is not a complete deployment file:

```json
{
  "storageAccountNetworkAclsBypass": { "value": "AzureServices" },
  "storageAccountResourceAccessRules": { "value": [] },
  "storageAccountAllowSharedKeyAccess": { "value": true }
}
```

For private/keyless opt-in, select `None`, native Boolean `false`, and an empty
rule list if no exception is intended. For an approved existing scanner:

```json
{
  "storageAccountNetworkAclsBypass": { "value": "None" },
  "storageAccountResourceAccessRules": {
    "value": [
      {
        "resourceId": "<exact-approved-existing-resource-ARM-ID>",
        "tenantId": "<resource-tenant-GUID>"
      }
    ]
  },
  "storageAccountAllowSharedKeyAccess": { "value": false }
}
```

Replace placeholders in the operator's private overlay. Do not infer an ID
from the solution resource group. Use native overlays through azd, direct
ARM/Bicep parameters and Azure DevOps's existing parameter artifact.
`azd env set` does not map these new inputs. There is no new empty-substitution
path to normalize.

## Scope, defaults and ownership

Only `main.bicep` module `storageAccount` / deployment `storageAccountSolution`
receives the new values. Keep AVM 0.26.2 and all other module parameters.

| Existing behavior | Preservation |
| --- | --- |
| PNA | `_publicNetworkAccess`; isolation and no IP exception disables ordinary public access. |
| ACL default action | Existing `_applyIpRules ? 'Deny' : 'Allow'`. |
| IP/VNet rules | Existing `_storageIpRules` and `[]`. |
| Blob public access, HTTPS, encryption, containers | Unchanged. |
| Auxiliary Foundry Storage | No propagation or modification. |
| RBAC, DNS, private endpoints, resource names | Unchanged. |
| Runtime keys and outputs | No additions needed. |

Default equivalence is effective behavior, not identical JSON: `true` and `[]`
become explicitly forwarded instead of inherited/omitted. Policy effects must
be recorded independently of declared values.

The supplied list is complete desired state. No live merge, inferred wildcard,
Defender activation or automatic rule exists. Empty/default lists do not
preserve manual exceptions. Callers own approval and identity; Azure enforces
resource eligibility, tenant and service-specific constraints.

`None` does not disable IP rules or override PNA/default action. Network
exceptions do not authorize data access. Shared Key disabled does not remove
AVM's existing `listKeys()` outputs.

## Verification contract

| ID | Scenario | Assertion |
| --- | --- | --- |
| S1 | All three omitted or selected as top-level null/default, standard mode | Native default contract remains `AzureServices`, no rules, `true`; compiler acceptance is distinguished from live evidence. |
| S2 | All three omitted, isolated mode | Same defaults; current PNA/private endpoints retained. |
| S3 | `None`, `false`, `[]`, isolation and no Defender | Exact forwarding; no scanner/plan/role/exception added. |
| S4 | `None`, `false`, one approved rule | Exact ID/tenant; retained after two identical deployments. |
| S5 | Zero/one/multiple distinct rules | No dropped, normalized, duplicated, inferred or merged entries. |
| S6 | All eight bypass values and explicit true/false | All supported values reach AVM and its resource. |
| S7 | Isolation on/off crossed with empty/nonempty `allowedIpRanges` | Current PNA/default-action/IP expressions remain authoritative. |
| S8 | `deployStorageAccount=false` | No solution account/new associated resources; other gates unchanged. |
| S9 | Invalid bypass, missing/extra/wrong-type rule fields, empty strings/nested nulls, wrong Boolean type | Typed validation fails, never permissive fallback; top-level optional-null selection is covered separately by S1. |

The proposed focused test inspects root definitions/defaults, exact solution
module bindings and nested AVM forwarding. Nested `properties` can be a
`shallowMerge` expression. Resolve the controlled expressions for table cases
and fail on unexpected shapes; do not build a permissive general ARM evaluator
or treat token presence as rendered-value proof. Use typed parameter fixtures
for negative cases; compiling `main.bicep` alone does not validate arbitrary
JSON parameter files.

Only `storageAccount` may gain this slice's fixture exemption, with focused
checks protecting unaffected fields. Persistence/authentication need live
evidence. Defender scanning needs its own authorized test and observed result,
not ACL equality or an assumed provisioning side effect.
