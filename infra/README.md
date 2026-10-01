# Azure AI Landing Zone

## Overview

The Azure AI Landing Zone is an enterprise-scale, production-ready reference architecture designed to deploy secure and resilient AI applications and agents on Azure. This repository contains the Bicep implementation, the Terraform implementations are available in separate repositories.   

![Architecture Diagram](media/Architecture%20Diagram.png)

## What's new in v2

**v2.7.1** fixes BYO subnet creation with Bastion disabled: the reserved
`AzureBastionSubnet` no longer inherits a generic NSG. An explicit dedicated
Bastion NSG still takes precedence when enabled. No subnet renaming workaround
is needed for new deployments; existing renamed subnets require a reviewed
address plan before removing their overrides. See the
[patch changelog](CHANGELOG.md#v271---2026-09-20).

**v2.7.0** adds reproducible solution Storage access inputs
and fixes ACR Task agent-pool BYO subnet ordering. See the
[changelog](CHANGELOG.md#v270---2026-09-18) and
[release-guard decision](docs/adr/0006-release-metadata-and-comparison-baselines.md).
Offline contracts and CI cover both changes; live Azure cold-start, persistence,
authentication and scanning evidence remains outstanding. Use preflight,
preview and an approved test scope before production adoption.

The v2 line adds two things that matter most for everyday use:

1. **A topology switch** — set `deploymentMode` to one of:
    - **`standalone`** — the AI Landing Zone provisions everything it needs (VNet, private endpoints, Bastion, jumpbox, NAT Gateway, observability). Best for sandboxes, evaluations, and teams without a corporate hub.
    - **`ailz-integrated`** — the AI Landing Zone deploys only the **spoke** (VNet + private endpoints + AI services) and peers into a hub VNet you already operate, **reusing** the hub's Firewall, Bastion, Private DNS zones, and Log Analytics workspace. Best for production inside an existing Azure Landing Zone.
2. **Granular reuse of existing resources** — every platform service can be brought from the outside via an `existing*ResourceId` parameter (cross-subscription IDs are accepted): Log Analytics, Application Insights, Private DNS zones (per zone, 15 available), hub VNet, jumpbox, Bastion, NAT Gateway, route table.

A handful of other quality-of-life additions:

- **`allowedIpRanges`** — let named CIDRs reach the data plane of Storage, Key Vault, Cosmos DB, AI Search, ACR, AI Foundry, and App Configuration without disabling private endpoints. Use this when developers need to query the workload from their laptops without routing through Bastion.
- **Decoupled hub components** — `deployJumpbox`, `deployBastion`, and `deployNatGateway` are now independent flags. No more all-or-nothing `deployVM`.
- **Hub integration helpers** — `hubIntegration.hubVnetResourceId` creates the spoke→hub peering for you; `hubIntegration.egressNextHopIp` routes spoke egress through your hub firewall / NVA.
- **Pre-flight validation** — `scripts/Invoke-PreflightChecks.ps1` runs automatically as an `azd preprovision` hook and catches the usual mistakes (CIDR overlap, undersized subnets, missing BYO resource IDs, conflicting flags, and insufficient AI Foundry OpenAI model quota) before they reach ARM. Bypass with `PREFLIGHT_SKIP=true`.
- **AI Foundry project naming** — `aiFoundryProjectName`, `aiFoundryProjectDisplayName`, and `aiFoundryProjectDescription` let consumers customize the deployed AI Foundry project instead of using a hardcoded default.
- **Workload App Configuration passthrough** — `additionalAppConfigurationSettings` lets a solution accelerator publish its own runtime key-values into the App Configuration store without adding template-specific parameters. See [Workload App Configuration passthrough](#workload-app-configuration-passthrough).
- **Foundry IQ groundwork for GPT-RAG:** set `RETRIEVAL_BACKEND=foundry_iq` to stamp the orchestrator settings for a Foundry IQ knowledge base. See [Foundry IQ for GPT-RAG](#foundry-iq-for-gpt-rag) for parameters, security expectations, billing, and the post-provision script.
- **Two-phase hosted-agent preparation and deployment** — `prepareHostedAgent` provisions the generic project/registry prerequisites and build handoff before an image exists; `deployHostedAgent` remains the immutable-digest deployment intent and implies preparation. Both flags default to `false` and never remove or change existing Container Apps or data resources. See [Hosted-agent preparation and deployment](#hosted-agent-preparation-and-deployment).

**Pick a runbook to deploy:**

- **[Standalone deployment](docs/runbook-standalone.md)** — single subscription, AI LZ owns all networking and platform resources.
- **[Hub-and-spoke deployment](docs/runbook-hub-spoke.md)** — spoke inside an existing Landing Zone, hub provides the platform.

If you're upgrading from v1.x, see the **[migration guide](docs/v2-migration.md)** — it shows what changed in v2 and the parameters you may need to update.

## How to Deploy

Choose your preferred deployment method based on project requirements and environment constraints.

### Prerequisites

**Required Permissions:**

- Azure subscription with **Contributor** and **User Access Admin** roles
- Agreement to Responsible AI terms for Azure AI Services

**Required Tools:**

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Git](https://git-scm.com/downloads)

> Azure CLI is included as a prerequisite for future pre/post provisioning hooks that may depend on it.

### Validate Bicep changes

Before submitting a Bicep change, compile `main.bicep` and apply the same
compiled-template size gate used by CI:

```pwsh
pwsh ./scripts/Measure-MainJsonSize.ps1
```

The script defaults are authoritative for both local and CI validation. The
gate warns above the 3.5 MB working budget, fails at 4.7 MB, and treats the
5.0 MB ARM ceiling as an unconditional failure.

### Terraform parity coordination

This repository is the functional reference implementation. The Terraform
pattern module lives in
[`Azure/terraform-azurerm-avm-ptn-aiml-landing-zone`](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone)
and no Terraform source is stored here.

- [`parity/inventory.json`](./parity/inventory.json) is the machine-readable gap
  inventory pinned to Bicep `v2.6.1` and Terraform `v0.5.1`.
- [`docs/terraform-parity.md`](./docs/terraform-parity.md) is generated from that
  inventory; edit the inventory and regenerate rather than editing the document.
- [`docs/terraform-parity-process.md`](./docs/terraform-parity-process.md)
  explains the complete process in plain language, including the high-level and
  detailed workflows, assessments, handoffs, proposals, file responsibilities,
  security boundaries, and manual approvals.
- [`docs/terraform-parity-ownership.md`](./docs/terraform-parity-ownership.md)
  names the accountable owners and describes the GitHub App, protected
  environment, and ledger operations.

The [release guard](docs/adr/0006-release-metadata-and-comparison-baselines.md)
validates current manifest/changelog versions independently of those historical
comparison pins. A release bump does not update inventory evidence or approve
parity; baseline advancement remains a separate reviewed operation.

Every pull request merged into `develop` gets exactly one alignment assessment.
The `terraform-parity-assess` workflow creates it from trusted merge metadata and
appends it to the dedicated `terraform-parity-assessments` ledger branch; it never
writes to `develop`. A parity reviewer then records the outcome
(`no-terraform-impact`, `inventory-update`, `proposal-required`, `blocked`,
`deferred`, or `superseded`) and rationale. Approved `proposal-required`
assessments produce a structured handoff, and publication to the Terraform
repository requires protected-environment approval; nothing is published
automatically.

Contributor commands, all offline:

```pwsh
npm ci --ignore-scripts
pwsh ./scripts/parity/Test-ParityAssets.ps1
pwsh ./scripts/parity/Export-ParityMarkdown.ps1 -Check
npm run test:parity
```

Support status (`full`, `partial`, `absent`, `blocked`) is separate from evidence
level. A scenario reaches parity only after its own successful test-subscription
deployment from the Terraform repository plus a reviewed capability comparison.
Compilation, lint, What-If, and `terraform plan` are never parity evidence.

### Basic Deployment

Quick setup for demos without network isolation.

**Initialize the project**

```
azd init -t azure/bicep-ptn-aiml-landing-zone
```

**Sign in to Azure**

```
az login
azd auth login
```

> Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

**Provision Infrastructure**

```
azd provision
```
> **Optional:** You can change parameter values in `main.parameters.json` or set them using `azd env set` before running `azd provision`. The latter applies only to parameters that support environment variable substitution.

### Resource naming

By default, generated resource names follow the Cloud Adoption Framework (CAF)
pattern `type-workload-environment-region-instance`, for example
`kv-a1b2c3-dev-eus2-001`. You do not have to set anything: every CAF token has a
safe default, so a plain `azd provision` produces valid, readable names.

The CAF tokens and their defaults:

- `CAF_WORKLOAD_NAME`: short deterministic hash derived from subscription,
  environment, and location. Override with a meaningful name such as `contosoai`.
- `CAF_ENVIRONMENT_NAME`: the azd environment name.
- `CAF_REGION_NAME`: the deployment location from azd (`AZURE_LOCATION`), mapped
  to a short region code (`eastus2` becomes `eus2`).
- `CAF_INSTANCE`: `001`. Increment only for a second parallel copy of the same
  workload in the same environment and region.

To override a token:

```
azd env set CAF_WORKLOAD_NAME contosoai
```

Names are length-bounded automatically so they stay within Azure limits
(storage 24, Key Vault 24, Container Apps environment 32, and so on). Because the
tokens are deterministic, redeploying the same environment produces the same
names (idempotent).

Explicit resource-name parameters such as `aiFoundryAccountName`,
`containerRegistryName`, `keyVaultName`, `storageAccountName`, and `vnetName`
continue to override generated names in either naming mode.

**Upgrading an existing deployment:** CAF is now the default. To keep the older
`resourceToken`-based names and avoid renaming existing resources, pin the legacy
mode before provisioning:

```
azd env set RESOURCE_NAMING_MODE legacy
```

### Zero Trust Deployment

For deployments that **require network isolation**.

**Before Provisioning**

Enable network isolation in your environment:

```
azd env set NETWORK_ISOLATION true
```

> **Optional:** Update other parameters in `main.parameters.json` or via `azd env set` before provisioning.

Make sure you're signed in with your Azure user account:

```
az login
azd auth login
```

> Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

**Provision Infrastructure**

```
azd provision
```

**Using the Jumpbox VM**

1. **Reset the VM password** in the Azure Portal (required on first access if not set in deployment parameters):

   - Go to your VM resource → **Support + troubleshooting** → **Reset password** → Set new credentials
   - Default username is `testvmuser`

2. **Connect via Azure Bastion**

#### Cloning extra repositories onto the jumpbox

The default `install.ps1` bootstrap clones this repository to `C:\github\ai-lz` and walks `manifest.json#components` for additional repos. Downstream solution accelerators that consume this landing zone as a Bicep module / git submodule and need their own application repository present on the jumpbox (for private-network data-plane post-provisioning — Cosmos seeding, AI Search index creation, sample data loading, etc.) declare those repos in their **overlay** `manifest.json`:

```json
{
  "tag": "v1.0.0",
  "ailz_tag": "v1.1.1",
  "components": [
    {
      "name": "voice-app",
      "repo": "https://github.com/Contoso/voice-app.git",
      "tag": "v0.3.0"
    }
  ]
}
```

`main.bicep` derives the URLs/tags/names from `_manifest.components` at compile time and forwards them to `install.ps1` over the CSE `commandToExecute`. Each entry is cloned into `C:\github\<name>` on the jumpbox. `tag` defaults to `main`; `name` defaults to the repo URL basename without `.git`. There are no per-deployment Bicep parameters to wire — `manifest.json` is the single source of truth, the same one consumers already use to pin their `ailz_tag` release.

#### Building and pushing images with network isolation

When `networkIsolation=true`, the Container Registry is deployed as **Premium** with `publicNetworkAccess=Disabled` and is only reachable via its private endpoint. `az acr build` against the shared Microsoft-managed builder will fail. This landing zone therefore provisions an **ACR Tasks agent pool** attached to the `devops-build-agents-subnet` so image builds run inside the VNet and push to the registry over its private endpoint. No Docker client is required (and the jumpbox has no Docker installed by design — see issue #14).

Build and push from the jumpbox (or any client that can reach ARM):

```powershell
$acr  = (azd env get-values | Select-String '^AZURE_CONTAINER_REGISTRY_ENDPOINT').Line.Split('=')[1].Trim('"').Split('.')[0]
$pool = (azd env get-values | Select-String '^ACR_TASK_AGENT_POOL').Line.Split('=')[1].Trim('"')

az acr build `
  -r $acr `
  --agent-pool $pool `
  -t myapp:latest `
  -f Dockerfile `
  .
```

Pause billing between builds (default tier `S1` is billed per hour whether idle or not):

```powershell
az acr agentpool update -r <acr> -n <pool> --count 0
```

Resume before the next build:

```powershell
az acr agentpool update -r <acr> -n <pool> --count 1
```

The agent pool can be disabled entirely with `deployAcrTaskAgentPool=false` if builds are handled by a central CI/CD runner that already reaches the registry's private endpoint.

##### BYO VNet subnet ordering

For [issue #159](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/159),
`acrTaskAgentPool` explicitly depends on completion of `virtualNetworkSubnets`
(`virtualNetworkSubnetsDeployment`). In a network-isolated BYO VNet deployment
that creates subnets, the pool waits for the **entire subnet deployment to
succeed**, not merely for a subnet resource ID to be constructed.

- Keep `deployNsgs=true` when `useExistingVNet=true` and `deploySubnets=true`
  under network isolation. The existing preflight/Bicep guard still rejects
  `deployNsgs=false` in this combination to prevent detaching current NSGs.
- With `deploySubnets=false`, the VNet owner must provide and manage the
  existing build subnet and its NSG associations. ARM removes the dependency
  on the skipped subnet deployment; no disabled-module output is read.
- Template-created VNets retain their existing implicit completion dependency.
  The pool still requires `networkIsolation`, `deployContainerRegistry`, and
  `deployAcrTaskAgentPool`; disabled paths still skip it and return the existing
  empty pool output. Requested tier/count, including count `0`, are unchanged.
- Cross-resource-group/subscription BYO subnet deployment scopes and VNet
  ownership are unchanged. The dependency targets the orchestrating subnet
  module; it does not grant permissions or replace the VNet's subnet collection.

This is separate from [#124](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/124)'s
firewall bootstrap work: the egress requirements below still apply. In an
approved cold-start test, record that the build subnet was initially absent,
subnet deployment completion preceded pool provisioning, and the requested
pool reached `Succeeded`. A successful retry after the subnet exists is
**not cold-start evidence**. Capacity, region, identity, and egress failures
still require separate investigation; a compiled dependency alone does not
prove live success.

#### Firewall egress allow-list (network isolation)

When `networkIsolation=true`, egress from the jumpbox and workload subnets is forced through the default Azure Firewall. The landing zone codifies the FQDNs required by the default `install.ps1` bootstrap and by the ACR Tasks agent pool. The set is split by purpose so you can audit or trim it:

- ACR Tasks control plane and registry: `*.azurecr.io`, `*.data.azurecr.io`, and Azure Storage queue/blob/table FQDNs.
- Language/runtime feeds: Python.org, PyPI, npm.
- OS package feeds: Debian, Ubuntu, Yarn, and `packages.microsoft.com` for Microsoft-supported Linux packages such as `msodbcsql18`.

If your application build needs additional HTTPS endpoints, add them to the `additionalAcrTaskBuildFqdns` array parameter. The values are appended to the ACR Tasks HTTPS runtime rule only when `networkIsolation`, `deployAzureFirewall`, `deployAcrTaskAgentPool`, and `extendFirewallForAcrTaskBuilds` are all enabled, and are scoped to the `devops-build-agents-subnet`.

| Rule | Source subnet | FQDN group | Used by |
| --- | --- | --- | --- |
| `AllowMicrosoftContainerRegistry` | `*` | `mcr.microsoft.com`, `*.data.mcr.microsoft.com` | ACA/agents/ACR Tasks pulling Microsoft base images |
| `AllowEntraIdAuth` | `*` | `login.microsoftonline.com`, `login.windows.net`, `management.azure.com`, `graph.microsoft.com`, `*.applicationinsights.azure.com` | Entra ID auth, ARM control plane, App Insights telemetry |
| `AllowGitHub` | `*` | `github.com`, `*.github.com`, `raw.githubusercontent.com`, `codeload.github.com`, `objects.githubusercontent.com`, `*.githubusercontent.com` | Repo clones, release downloads |
| `AllowContainerAppsPlatform` | `*` | ACA control-plane/identity FQDNs (`*.servicebus.windows.net`, `*.identity.azure.net`, `*.azurecontainerapps.io`/`.dev`), Azure Monitor/Log Analytics/App Insights ingestion, CRL/OCSP revocation endpoints, and the Microsoft Foundry Agent Service's `agent365.svc.cloud.microsoft` observability endpoint | Container Apps managed-identity token fetch, platform diagnostics, TLS certificate revocation checks, and Foundry hosted-agent observability on the AI Foundry Agents subnet (`agentSubnetPrefix`) |
| `AllowJumpboxBootstrap` | `jumpboxSubnetPrefix` | Chocolatey, NuGet, VS Installer, `download.microsoft.com`, `aka.ms`, `go.microsoft.com`, `*.core.windows.net`, `*.azureedge.net` | `choco install`, VS Code/PowerShell Core/Azure CLI/AZD MSIs (Python is installed from python.org embeddable zip — see `AllowJumpboxDevRuntimes`) |
| `AllowJumpboxDevRuntimes` | `jumpboxSubnetPrefix` | `*.python.org`, `*.pypi.org`, `*.pythonhosted.org`, `*.pypa.io`, `*.npmjs.org` | `pip install`, `npm install`, jumpbox Python embeddable-zip install + `get-pip.py` bootstrap |
| `AllowJumpboxEditors` | `jumpboxSubnetPrefix` | `update.code.visualstudio.com`, `*.vo.msecnd.net`, `*.vscode-cdn.net` | VS Code updates |
| `AllowJumpboxAcme` | `jumpboxSubnetPrefix` | `api.github.com`, `acme-v02.api.letsencrypt.org` | win-acme release discovery + ACME v2 issuance/renewal from jumpbox |
| `AllowAcrTasks` | `devopsBuildAgentsSubnetPrefix` | `*.azurecr.io`, `*.data.azurecr.io` | ACR Tasks agent pool talking to its registry |

Set `extendFirewallForJumpboxBootstrap=false` to skip the jumpbox-scoped rules when egress is managed centrally by another policy.

##### ACR Task agent pool platform Network Rules

The table above lists Application (FQDN) rules. The dedicated ACR Tasks agent
pool additionally requires unconditional outbound **Network Rules** (service
tags, not FQDNs) for its own platform bootstrap traffic — this is a
requirement of the agent pool control plane itself, independent of what a
build script does. When `networkIsolation`, `deployAzureFirewall`, and
`deployAcrTaskAgentPool` are all enabled, the landing zone adds a
`AllowAcrTaskAgentPoolPlatform` Network Rule Collection scoped to
`devopsBuildAgentsSubnetPrefix`, allowing outbound TCP 443 to `AzureKeyVault`,
`Storage`, `EventHub`, and `AzureActiveDirectory`, and TCP 443/12000 to
`AzureMonitor`, matching the [documented ACR Tasks agent pool network
requirements](https://learn.microsoft.com/en-us/azure/container-registry/tasks-agent-pools).
Without these Network Rules the agent pool fails to provision when
VNet-injected (see [Azure/GPT-RAG#597](https://github.com/Azure/GPT-RAG/issues/597)).

### Selecting components for deployment

The following flags support `azd env set` / `${VAR=default}` overrides, in addition to editing `main.parameters.json` directly. All default to `true` (unchanged prior behavior):

| Parameter | Env var | Purpose |
| --- | --- | --- |
| `deployCosmosDb` | `DEPLOY_COSMOS_DB` | Azure Cosmos DB account for globally distributed NoSQL data storage. |
| `deployContainerApps` | `DEPLOY_CONTAINER_APPS` | Azure Container Apps for running your microservices. |
| `deployContainerRegistry` | `DEPLOY_CONTAINER_REGISTRY` | Azure Container Registry for Docker container images. |
| `deployContainerEnv` | `DEPLOY_CONTAINER_ENV` | The Container Apps environment (log ingestion, VNet integration, etc.). |
| `deployNsgs` | `DEPLOY_NSGS` | Network security groups. |

```bash
azd env set DEPLOY_CONTAINER_APPS false
```

Use only `true` or `false` (case-insensitive). Container Apps require the
Container Apps Environment; environment-only deployment is supported. Container
App API keys additionally require Container Apps, Key Vault, App Configuration,
and `appRuntimeConfigurationMode=appConfig`. In a network-isolated deployment
that updates subnets in an existing VNet, NSGs cannot be disabled because doing
so would detach existing subnet NSG associations.

These flags select resources for the next incremental deployment. Setting a
flag to `false` does not delete an existing resource or stale App Configuration
key created by an earlier deployment; remove decommissioned artifacts
explicitly.

### Solution Storage access controls

[Issue #160](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/160)
adds three independent inputs for the **solution** Storage account
(`storageAccount` / `storageAccountSolution`), using the existing Storage AVM
**0.26.2**. They do not configure auxiliary `aiFoundryStorageAccount` resources.
Omitting them preserves the existing effective defaults in both standard and
network-isolated deployments; `deployStorageAccount=false` still skips the
solution account.

| Parameter | Type | Default | Controls |
| --- | --- | --- | --- |
| `storageAccountNetworkAclsBypass` | `storageTypes.storageAccountNetworkAclsBypassType` (string union) | `AzureServices` | `networkAcls.bypass` only. |
| `storageAccountResourceAccessRules` | `storageTypes.storageAccountResourceAccessRuleType[]` (sealed objects) | `[]` | Complete desired `networkAcls.resourceAccessRules` list. Each entry requires nonempty string `resourceId` and `tenantId`; no extra fields. |
| `storageAccountAllowSharedKeyAccess` | Boolean | `true` | Whether the account allows Shared Key authorization. |

The eight accepted bypass spellings are exactly `None`, `AzureServices`,
`Logging`, `Metrics`, `AzureServices, Logging`, `AzureServices, Metrics`,
`AzureServices, Logging, Metrics`, and `Logging, Metrics`, including comma-space
formatting and ordering. Types are defined in
[`constants/storage-types.bicep`](constants/storage-types.bicep). Empty strings,
unsupported spellings and wrong types are invalid, not fallback profiles.
Bicep accepts top-level `null` for a defaulted parameter as omission/default
selection; it is not a request for stricter access. Specify `None` and native
Boolean `false` explicitly for that profile. Required fields inside a supplied
resource-instance rule must still be non-null, nonempty strings.

#### Native parameter profiles

The following are **incomplete JSON fragments**, not full deployment parameter
files. Merge their entries into the `parameters` object of the actual
`main.parameters.json` or consumer-owned parameter overlay used by deployment.
Keep all other required parameters and secure-value resolution intact. Use
native arrays/objects and Booleans, not stringified JSON or `"false"`.
These three fields have **no environment-variable mappings**:
`azd env set` alone does not set them. Direct ARM/Bicep callers can pass the
typed values; Azure DevOps uses its existing parameter artifact.

**Omitted/default profile:** omitting all three selects these Bicep defaults;
the repository parameter file declares the same values explicitly:

```json
{
  "storageAccountNetworkAclsBypass": { "value": "AzureServices" },
  "storageAccountResourceAccessRules": { "value": [] },
  "storageAccountAllowSharedKeyAccess": { "value": true }
}
```

**Private / Shared Key disabled, no Defender or scanner exception:** after
testing consumer compatibility, use this fragment with `networkIsolation=true`
and empty `allowedIpRanges`. It does not enable Defender:

```json
{
  "storageAccountNetworkAclsBypass": { "value": "None" },
  "storageAccountResourceAccessRules": { "value": [] },
  "storageAccountAllowSharedKeyAccess": { "value": false }
}
```

**Optional approved existing resource-instance exception:** only when an
eligible instance (for example, an already-enabled Defender scanner) already
exists and its access is approved, supply its exact ARM ID and tenant:

```json
{
  "storageAccountNetworkAclsBypass": { "value": "None" },
  "storageAccountResourceAccessRules": {
    "value": [
      {
        "resourceId": "<exact-approved-existing-resource-ARM-ID>",
        "tenantId": "<same-tenant-GUID>"
      }
    ]
  },
  "storageAccountAllowSharedKeyAccess": { "value": false }
}
```

These placeholders are deliberately unusable. Replace them only in the
operator's private overlay; never commit live IDs or credentials. Supply the
actual existing instance ID, not a principal ID, wildcard, or a scanner ID
guessed from the solution resource group. The instance and Storage account
must belong to the **same Microsoft Entra tenant** and the resource type must
be eligible; typed strings alone do not prove existence or eligibility.

#### Ownership and security boundaries

The supplied rule list **replaces the complete desired set of resource-instance
exceptions**. It is not appended to live rules: `[]` (including the default)
removes those exceptions on reconciliation. Coordinate with every external ACL
owner and explicitly include each approved ID/tenant pair that must remain.
The landing zone does not discover/import arbitrary live ACLs, generate
wildcard rules, create a scanner, enable a Defender plan, or add roles for these
inputs. A rule grants network eligibility, **not data permission**.

Bypass, authentication, and network reachability remain independent:

- `None` disables bypass, not IP rules or public access. Existing logic keeps
  `publicNetworkAccess=Enabled` in standard mode or with nonempty
  `allowedIpRanges`; isolated mode with no IP exceptions uses `Disabled`.
  `networkAcls.defaultAction` remains `Deny` with IP rules and `Allow` otherwise;
  the existing IP rules and empty VNet-rule list are unchanged.
- Neither `None` alone nor disabled public network access alone guarantees
  isolation. Trusted-service and resource-instance exceptions matter and may
  remain effective with public access disabled. Review effective Azure Policy
  results as well as declared values; see
  [Storage network security limitations](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-limitations).
- `false` is an opt-in authentication change. Inventory key-based clients
  first and test supported Microsoft Entra authorization / Blob user-delegation
  SAS paths. Managed identities, RBAC, private endpoints/DNS, names, containers,
  Blob public-access prohibition, HTTPS, and encryption remain unchanged.
  AVM retains secure outputs that call management-plane `listKeys()`: disabling
  Shared Key does **not** make deployment key-free or remove those calls.

For existing accounts and downstream consumers, follow the migration sequence
in the [Standalone runbook](docs/runbook-standalone.md#43-opt-in-solution-storage-migration)
or [Hub-and-Spoke runbook](docs/runbook-hub-spoke.md#612-opt-in-solution-storage-migration).
Rule persistence, client authentication, and any optional scanner operation
require separate approved live checks; successful compilation or preview is
not proof of any of them.

### AI Foundry deployment modes

`deployAiFoundry` controls the base AI Foundry account, project, and model deployments. `deployAAfAgentSvc` controls the Agent Service Standard Setup and its associated AI Search, Storage, Cosmos DB, and Key Vault resources. `deploySearchService` controls only the workload/RAG Azure AI Search service used by applications.

| Scenario | Parameters |
| --- | --- |
| Full Foundry Agent Service setup | `deployAiFoundry=true`, `deployAAfAgentSvc=true` |
| Foundry inference-only | `deployAiFoundry=true`, `deployAAfAgentSvc=false` |
| Workload Search only | `deploySearchService=true`, independent of `deployAAfAgentSvc` |
| No Foundry resources | `deployAiFoundry=false` |

Use `DEPLOY_AAF_AGENT_SVC=false` when an external app only needs hosted model inference from Foundry and does not need Agent Service capability hosts or their associated state resources.

`aiFoundryDisableLocalAuth` / `AI_FOUNDRY_DISABLE_LOCAL_AUTH` controls whether the AI Foundry account accepts API-key authentication. It defaults to `true` (local auth disabled, Azure AD-only), matching the account's prior inert default. Set `AI_FOUNDRY_DISABLE_LOCAL_AUTH=false` only if API-key auth is explicitly required.

### Hosted-agent preparation and deployment

Hosted-agent infrastructure uses two additive, accelerator-neutral phases:

- `prepareHostedAgent=true` provisions the shared prerequisites and exposes the
  project, registry, network, and private-build handoff before an image or digest
  exists. It does not request agent deployment.
- `deployHostedAgent=true` implies preparation and additionally enables the typed
  agent payload. It continues to require an immutable
  `sha256:<64 lowercase hex characters>` image digest.

Both flags default to `false`, so existing parameter files and deployments remain
unchanged. The flags are **not** workload topology switches: they do not create
an application UI or replacement workload, and they do not modify
`containerAppsList`, Cosmos DB, Storage, Search, App Configuration, or any other
existing workload resource.

| `prepareHostedAgent` | `deployHostedAgent` | Prerequisite RBAC and handoff | Agent payload |
|---|---|---|---|
| `false` | `false` | Disabled | Disabled |
| `true` | `false` | Enabled | Disabled; no image digest required |
| `false` | `true` | Enabled | Enabled; immutable digest required |
| `true` | `true` | Enabled | Enabled; immutable digest required |

When either flag is enabled, the landing zone adds only:

- `Foundry Project Manager` for the deployment principal on the Foundry project;
- the registry-mode-compatible pull role for the Foundry project managed
  identity on the selected registry (`AcrPull` for RBAC-only registries or
  `Container Registry Repository Reader` for ABAC-enabled registries); and
- a typed output handoff containing the project, registry, agent subnet, and
  private-build context. Image, startup command, runtime, and protocol values are
  added only when deployment is requested.

The downstream `azure.ai.agent` service remains responsible for `azd deploy`.
That data-plane operation creates the immutable agent version, dedicated
per-agent identity, invocation endpoint, and the agent identity's registry pull
assignment. `azure.ai.agent` is an azd deployment contract rather than an ARM
resource type, so this Bicep template intentionally does not fabricate an agent
resource or deployment script. See the official
[hosted-agent `azure.yaml` reference](https://learn.microsoft.com/azure/foundry/agents/concepts/azure-yaml-reference#azureaiagent-service)
and [pre-built image workflow](https://learn.microsoft.com/azure/foundry/agents/how-to/deploy-hosted-agent-private-azure-container-registry#deploy-a-pre-built-image).

The typed `hostedAgent` object is sealed and deliberately has no `roles` field.
Arbitrary role names are rejected by preflight rather than silently ignored.
After `azd deploy` creates the dedicated agent identity, the accelerator must
assign explicit least-privilege role definition IDs for any external resources
that identity needs.

| Parameter | Default | Purpose |
|---|---|---|
| `prepareHostedAgent` | `false` | Enables prerequisite RBAC and project/registry/private-build outputs without requiring an image or enabling the agent payload. |
| `deployHostedAgent` | `false` | Implies preparation and enables the downstream agent deployment payload. |
| `hostedAgent.name` | empty | Stable hosted-agent name; downstream deploys create immutable versions under this name. |
| `hostedAgent.image` | empty | Repository path inside the selected ACR, without tag or digest. |
| `hostedAgent.version` | empty | Required only when `deployHostedAgent=true`; must be an immutable OCI digest in `sha256:<64 lowercase hex>` form. |
| `hostedAgent.startupCommand` | empty | Optional container startup command, mapped to `startupCommand` in `azure.ai.agent`. |
| `hostedAgent.runtime` | `1` CPU, `1Gi` | CPU (`0.25`–`4.0`) and memory (`0.5Gi`–`8Gi`) mapped to `container.resources`. |
| `hostedAgent.protocols` | Responses `2.0.0` | Typed `responses`, `invocations`, `invocations_ws`, or `a2a` contracts. |
| `hostedAgentContainerRegistryResourceId` | empty | Existing ACR resource ID when `deployContainerRegistry=false`. |
| `hostedAgentContainerRegistryEndpoint` | empty | Existing ACR login endpoint when `deployContainerRegistry=false`. |
| `hostedAgentContainerRegistryRoleAssignmentMode` | `rbac` | Existing ACR permissions mode: `rbac` uses `AcrPull`; `rbac-abac` uses `Container Registry Repository Reader`. Ignored for the landing-zone registry, which is RBAC-only. |

For a fresh deployment, provision the prerequisites first:

```bash
azd env set PREPARE_HOSTED_AGENT true
azd env set DEPLOY_HOSTED_AGENT false
azd provision
```

At this point `HOSTED_AGENT_PREPARED=true`,
`HOSTED_AGENT_DEPLOYMENT.enabled=false`, and
`HOSTED_AGENT_DEPLOYMENT.agent=null`. The exact Foundry and registry outputs are
available so a separate pipeline or VNet-connected build path can build, scan,
sign, push, and resolve the immutable digest.

After the image exists, enable deployment intent and pin that digest:

```bash
azd env set DEPLOY_HOSTED_AGENT true
azd env set HOSTED_AGENT_NAME sample-agent
azd env set HOSTED_AGENT_IMAGE agents/sample-agent
azd env set HOSTED_AGENT_IMAGE_VERSION sha256:<64-hex-digest>
azd env set HOSTED_AGENT_STARTUP_COMMAND "python main.py"
azd provision
```

`PREPARE_HOSTED_AGENT` may remain `true` or be reset to `false`;
`DEPLOY_HOSTED_AGENT=true` is always a superset.

After provisioning, map `HOSTED_AGENT_DEPLOYMENT` (or the exact Foundry and ACR
outputs) into the accelerator's `azure.ai.agent` service and run `azd deploy`
from that accelerator. Preflight rejects mutable image tags and missing Foundry
or registry prerequisites. It validates the canonical digest syntax but does not
query the registry for manifest existence or signature authenticity; keep those
checks in the image build, scan, signing, and promotion pipeline.

**Private registry:** the landing-zone ACR retains its existing Zero Trust
behavior: Premium SKU, private endpoint and DNS integration, and disabled public
network access when `networkIsolation=true`. Building or pushing an image in
that mode must happen from a VNet-connected runner, build agent, or jumpbox.
Set `DEPLOY_ACR_TASK_AGENT_POOL=true` when using the landing-zone VNet-injected
ACR Tasks pool; its subnet, firewall, private endpoint, and DNS topology remain
independently controlled by the existing registry/isolation/pool flags.
For an existing ACR, set
`HOSTED_AGENT_CONTAINER_REGISTRY_ROLE_ASSIGNMENT_MODE=rbac-abac` when its role
assignment permissions mode is **RBAC Registry + ABAC Repository Permissions**;
the default `rbac` mode is correct for **RBAC Registry Permissions**. Its private
endpoint, DNS, authentication-as-ARM policy, and network reachability remain the
consumer's responsibility. Microsoft
currently documents private ACR support for Foundry projects created after
June 25, 2026; projects created earlier require the registry to remain reachable
over its public endpoint. Verify this platform limitation before a live
deployment. See
[private ACR deployment and RBAC](https://learn.microsoft.com/azure/foundry/agents/how-to/deploy-hosted-agent-private-azure-container-registry)
and [hosted-agent permissions](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agent-permissions#azure-resource-setup).

| Output | Description |
|---|---|
| `DEPLOY_HOSTED_AGENT` | Deployment intent; remains `false` in prepare-only mode. |
| `HOSTED_AGENT_PREPARED` | Effective prerequisite enablement (`prepareHostedAgent || deployHostedAgent`). It does not claim an agent version exists. |
| `AZURE_AI_PROJECT_RESOURCE_ID` / `AZURE_AI_PROJECT_ENDPOINT` | Exact Foundry project handoff in prepare and deploy modes. |
| `AZURE_CONTAINER_REGISTRY_RESOURCE_ID` / `AZURE_CONTAINER_REGISTRY_ENDPOINT` | Exact selected-registry handoff in prepare and deploy modes. |
| `HOSTED_AGENT_DEPLOYMENT` | Consolidated contract. Foundry, registry, network, and private-build values are populated in prepare mode; `enabled` and `agent` remain deployment-only. |

### Workload App Configuration passthrough

The landing zone is workload-agnostic. When a solution accelerator needs its own
runtime keys stamped into the App Configuration store, it should not require new
typed parameters in this template. Use `additionalAppConfigurationSettings` to
publish any number of extra key-values verbatim:

```bicep
module ailz 'br/public:avm/ptn/aiml/ai-landing-zone:<version>' = {
  params: {
    // ...
    additionalAppConfigurationSettings: [
      { name: 'MY_WORKLOAD_FLAG', value: 'true' }
      { name: 'MY_WORKLOAD_MODE', value: 'hybrid', label: 'prod' }
    ]
  }
}
```

Each entry accepts `name` (required), `value` (required), `label` (optional,
defaults to `appConfigLabel`), and `contentType` (optional, defaults to
`text/plain`). Rules and limits:

- Values are stored in plaintext. Do not pass secrets, connection strings, or
  keys through this parameter. Use Key Vault references for sensitive data.
- Each `name` + `label` pair must be unique. If an entry collides with a
  built-in setting the passthrough value wins (the built-in entry is dropped),
  so an accelerator can also override a stamped default when it needs to.
- App Configuration is only populated on non-network-isolated deployments where
  the runtime config store is App Configuration. In isolated deployments the
  post-provision step running on the jumpbox is responsible for stamping config,
  so pass workload keys through that path instead.
- When the consumer selects the `containerEnv` runtime mode (Issue #89) instead
  of App Configuration, the same entries are injected into every Container App as
  environment variables. Only `name` and `value` are used in that mode (`label`
  and `contentType` are ignored, since env vars have neither), and the same
  "passthrough wins on collision" precedence applies.

This is the forward-looking way to configure workload settings such as the
GPT-RAG Foundry IQ keys below: accelerators publish their own keys through the
passthrough instead of the landing zone growing workload-specific parameters.

### Foundry IQ for GPT-RAG

> The individual `foundryIq*` knowledge-source parameters below are retained for
> backward compatibility but are being superseded by the generic
> [workload App Configuration passthrough](#workload-app-configuration-passthrough).
> New accelerators should publish these keys through
> `additionalAppConfigurationSettings` rather than relying on template-specific
> parameters. `retrievalBackend` stays a first-class parameter because it gates
> real infrastructure (the AI Foundry knowledge-base connection and shared
> private links), not just configuration.

The landing zone stamps GPT-RAG runtime settings for a Foundry IQ knowledge
base. New deployments default to Foundry IQ. Existing GPT-RAG deployments can
stay on `RETRIEVAL_BACKEND=ai_search` until the operator intentionally migrates.

| Parameter / env var | Default | Purpose |
| --- | --- | --- |
| `retrievalBackend` / `RETRIEVAL_BACKEND` | `foundry_iq` | Selects direct Azure AI Search or Foundry IQ. Existing deployments can keep `ai_search` until they migrate. |
| `foundryIqPattern` / `FOUNDRY_IQ_PATTERN` | `azureBlob` | `azureBlob` uses native Foundry IQ Blob or ADLS Gen2 ingestion. `managed` is accepted as a compatibility alias for `azureBlob`. `searchIndex` remains an explicit Pattern B opt-in for existing GPT-RAG Azure AI Search indexes. |
| `knowledgeBaseName` / `KNOWLEDGE_BASE_NAME` | `knowledge-base` | Name stamped into `KNOWLEDGE_BASE_NAME`. |
| `knowledgeBaseConnectionName` / `KNOWLEDGE_BASE_CONNECTION_NAME` | `knowledge-base-connection` | Dedicated AI Foundry Search connection for knowledge-base use. |
| `foundryIqApiVersion` / `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | Required for per-user permissions and Pattern B `filterAddOn`. |
| `foundryIqKnowledgeRetrievalBillingPlan` / `FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN` | `free` | Azure AI Search `knowledgeRetrieval` billing plan. Set `standard` only after billing approval. |
| `foundryIqKnowledgeSourceName` / `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | `knowledge-base-blob-ks` | Native Blob Knowledge Source name by default; also used as the Pattern B source name when `searchIndex` is selected. |
| `foundryIqKnowledgeSourceKind` / `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` | Runtime Knowledge Source kind. Keep aligned with `foundryIqPattern`; use `searchIndex` only for Pattern B. |
| `foundryIqStorageContainerName` / `FOUNDRY_IQ_STORAGE_CONTAINER_NAME` | `documents` | Blob or ADLS Gen2 container for native Foundry IQ ingestion. |
| `foundryIqStorageFolderPath` / `FOUNDRY_IQ_STORAGE_FOLDER_PATH` | Empty | Optional folder path within the native Blob or ADLS Gen2 container. |
| `foundryIqIsAdlsGen2` / `FOUNDRY_IQ_IS_ADLS_GEN2` | `false` | Set to `true` when the native source is an ADLS Gen2 account with hierarchical namespace. |
| `foundryIqIngestionPermissionOptionsJson` / `FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` | `["rbacScope"]` | JSON array of permission metadata to ingest for native Foundry IQ sources. |
| `foundryIqSearchIndexName` / `FOUNDRY_IQ_SEARCH_INDEX_NAME` | `gpt-rag-index` | Existing Azure AI Search index to register for Pattern B. |
| `foundryIqSemanticConfigurationName` / `FOUNDRY_IQ_SEMANTIC_CONFIGURATION_NAME` | `default` | Semantic configuration on the existing index. |
| `foundryIqFilterAddOnEnabled` / `FOUNDRY_IQ_FILTER_ADD_ON_ENABLED` | `false` | Enables GPT-RAG query-time security filtering for Pattern B. Leave `false` for native Blob. |
| `foundryIqSecurityFieldName` / `FOUNDRY_IQ_SECURITY_FIELD_NAME` | `metadata_security_id` | Field used by the orchestrator to build Pattern B filters. |
| `foundryIqMaxOutputDocuments` / `FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS` | Empty | Optional cap on documents returned by the knowledge base. |
| `foundryIqContentExtractionMode` / `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE` | `standard` | Native Blob content extraction mode. `standard` uses the Foundry IQ Content Understanding skill (layout and OCR) so scanned and image-only PDFs are ingested with text. `minimal` skips Content Understanding and only ingests text already present in the source. The setting is immutable on an existing Knowledge Source. |
| `foundryIqAiServicesEndpoint` / `FOUNDRY_IQ_AI_SERVICES_ENDPOINT` | Derived from the Foundry account | Required by Azure AI Search when `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE=standard`. Leave empty for deployments that create the Foundry account, or set it to `https://<foundry-resource>.services.ai.azure.com/` when reusing an existing Foundry resource. |
| `foundryIqBaseFilter` / `FOUNDRY_IQ_BASE_FILTER` | Empty | Optional persisted filter for the Pattern B knowledge source. |
| `foundryIqSourceDataFields` / `FOUNDRY_IQ_SOURCE_DATA_FIELDS` | Template default | Fields exposed by the Pattern B knowledge source. |
| `foundryIqSearchFields` / `FOUNDRY_IQ_SEARCH_FIELDS` | Template default | Searchable fields used by the Pattern B knowledge source. |

Security expectations:

- Pattern B (`searchIndex`) keeps the existing GPT-RAG index and enforces
  GPT-RAG security fields through query-time `filterAddOn`.
- Native Foundry IQ permissions use `x-ms-query-source-authorization` and require
  a source that ingests permissions, such as ADLS Gen2 ACLs, SharePoint,
  OneLake/Fabric, or Purview labels.
- Plain Blob storage is container-level RBAC for this purpose. Do not claim
  per-document trimming for plain Blob unless Purview labels or an equivalent
  per-document permission source are used.

Bicep stamps runtime configuration and creates a dedicated Foundry connection
ID, but Azure AI Search knowledge sources and knowledge bases are data-plane
objects. After provisioning, create or update them with the signed-in Azure CLI
identity:

```powershell
./scripts/Configure-FoundryIQKnowledgeBase.ps1 `
  -SearchEndpoint "https://<search-name>.search.windows.net" `
  -KnowledgeBaseName "<knowledge-base-name>" `
  -KnowledgeSourceName "<knowledge-source-name>" `
  -SearchIndexName "<gpt-rag-index-name>" `
  -SemanticConfigurationName "<semantic-config-name>" `
  -SearchServiceResourceId "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Search/searchServices/<search-name>" `
  -KnowledgeRetrievalBillingPlan "free"
```

The caller needs **Search Service Contributor** on the Search service. Use
`-KnowledgeRetrievalBillingPlan standard` only when you want to opt in to
pay-as-you-go agentic retrieval billing after the included free allowance.

### Permissions

The following role assignments are provisioned by the template based on the **default configuration** in `main.parameters.json`. This includes the default set of container apps, their associated roles, and the services they interact with. If you customize the parameters before provisioning — such as adding or removing container apps or changing role mappings — the actual assignments will vary accordingly.

#### Microsoft Foundry and AI Search Assignments

| Resource | Role | Assignee | Description |
| --- | --- | --- | --- |
| Microsoft Foundry Account | Cognitive Services User | Search Service | Allow Search Service to access vectorizers |
| GenAI App Search Service | Search Index Data Reader | Microsoft Foundry Project | Read index data |
| GenAI App Search Service | Search Service Contributor | Microsoft Foundry Project | Create AI Search connection |
| GenAI App Storage Account | Storage Blob Data Reader | Microsoft Foundry Project | Read blob data |
| GenAI App Storage Account | Storage Blob Data Reader | Search Service | Read blob data for indexing |

#### Container App Role Assignments

Current default configuration provisions a single Hello World container app (`orchestrator`), so only the assignments below are expected by default.

| Resource | Role | Assignee | Description |
| --- | --- | --- | --- |
| GenAI App Configuration Store | App Configuration Data Reader | ContainerApp: orchestrator | Read configuration data |
| GenAI App Container Registry | AcrPull | ContainerApp: orchestrator | Pull container images |
| GenAI App Key Vault | Key Vault Secrets User | ContainerApp: orchestrator | Read secrets |
| GenAI App Search Service | Search Index Data Reader | ContainerApp: orchestrator | Read index data |
| GenAI App Storage Account | Storage Blob Data Reader | ContainerApp: orchestrator | Read blob data |
| GenAI App Cosmos DB | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data |
| Microsoft Foundry Account | Cognitive Services User | ContainerApp: orchestrator | Access Cognitive Services |
| Microsoft Foundry Account | Cognitive Services OpenAI User | ContainerApp: orchestrator | Use OpenAI APIs |

#### Executor Role Assignments

| Resource | Role | Assignee | Description |
| --- | --- | --- | --- |
| GenAI App Configuration Store | App Configuration Data Owner | Executor | Full control over configuration settings |
| GenAI App Container Registry | AcrPush | Executor | Push container images |
| GenAI App Container Registry | AcrPull | Executor | Pull container images |
| GenAI App Key Vault | Key Vault Contributor | Executor | Manage Key Vault settings |
| GenAI App Key Vault | Key Vault Secrets Officer | Executor | Create Key Vault secrets |
| GenAI App Search Service | Search Service Contributor | Executor | Create/update search service elements |
| GenAI App Search Service | Search Index Data Contributor | Executor | Read/write search index data |
| GenAI App Search Service | Search Index Data Reader | Executor | Read index data |
| GenAI App Storage Account | Storage Blob Data Contributor | Executor | Read/write blob data |
| GenAI App Cosmos DB | Cosmos DB Built-in Data Contributor | Executor | Read/write Cosmos DB data |
| Microsoft Foundry Account | Cognitive Services OpenAI User | Executor | Use OpenAI APIs |
| Microsoft Foundry Account | Cognitive Services User | Executor | Access Cognitive Services |

#### Jumpbox VM Role Assignments

| Resource | Role | Assignee | Description |
| --- | --- | --- | --- |
| Resource Group | Reader | Jumpbox VM | Enumerate ARM resources from inside the VNet (`az resource list`, `az cosmosdb list`, `az containerapp list`, …) for postProvision / data-seed scripts |
| GenAI App Container Apps | Container Apps Contributor | Jumpbox VM | Full control over Container Apps |
| Azure Managed Identity | Managed Identity Operator | Jumpbox VM | Assign and manage user-assigned identities |
| GenAI App Container Registry | Container Registry Repository Writer | Jumpbox VM | Write to ACR repositories |
| GenAI App Container Registry | Container Registry Tasks Contributor | Jumpbox VM | Manage ACR tasks |
| GenAI App Container Registry | Container Registry Data Access Configuration Administrator | Jumpbox VM | Manage ACR data access configuration |
| GenAI App Container Registry | AcrPush | Jumpbox VM | Push container images |
| GenAI App Configuration Store | App Configuration Data Owner | Jumpbox VM | Full control over configuration settings |
| GenAI App Key Vault | Key Vault Contributor | Jumpbox VM | Manage Key Vault settings |
| GenAI App Key Vault | Key Vault Secrets Officer | Jumpbox VM | Create Key Vault secrets |
| GenAI App Key Vault | Key Vault Certificates Officer | Jumpbox VM | Import/manage Key Vault certificates for public ingress TLS |
| GenAI App Search Service | Search Service Contributor | Jumpbox VM | Create/update search service elements |
| GenAI App Search Service | Search Index Data Contributor | Jumpbox VM | Read/write search index data |
| GenAI App Storage Account | Storage Blob Data Contributor | Jumpbox VM | Read/write blob data |
| GenAI App Cosmos DB | Cosmos DB Built-in Data Contributor | Jumpbox VM | Read/write Cosmos DB data |
| Microsoft Foundry Account | Cognitive Services Contributor | Jumpbox VM | Manage Cognitive Services resources |
| Microsoft Foundry Account | Cognitive Services OpenAI User | Jumpbox VM | Use OpenAI APIs |

### Optional Public Ingress (Application Gateway WAF v2)

**Issue #49.** The landing zone provisions the Container Apps environment in **internal** mode under network isolation, so its apps are unreachable from the public Internet by default. Some workloads need a controlled, audited public entry point (a tester, a partner integration, a public demo). The optional `publicIngress` feature deploys an **Application Gateway WAF v2** in front of the internal ACA environment without changing any of the existing internal topology.

> ⚠️ **Cost warning.** Enabling this feature deploys WAF_v2 + a Standard Public IP, which incur **hourly charges even when idle** (~USD 240/month for the gateway alone, region-dependent). Keep `publicIngress.enabled = false` unless actively needed and tear the stack down with `azd down` (or delete the resources manually) when the access window ends. **Setting `publicIngress.enabled` back to `false` after a deploy will NOT delete the resources** — `azd`/ARM incremental deployments only stop managing them.

**Default state:** disabled. No public-ingress resources are provisioned.

**Parameter contract** (`publicIngressType` exported from `main.bicep`):

```bicep
publicIngress: {
  enabled: bool                              // master toggle, default false
  backendAppIndex: int?                      // index into containerAppsList; default 0
  frontendHostName: string?                  // e.g., 'app.contoso.com' — required to activate HTTPS
  sslCertSecretId: string?                   // versionless Key Vault secret URI — required to activate HTTPS
  allowedSourceAddressPrefixes: string[]?    // CIDRs allowed to reach :443; empty list = deny-all
  wafMode: ('Prevention' | 'Detection')?     // default 'Prevention'
  wafCustomRules: object[]?                  // merged with OWASP CRS 3.2 managed ruleset
  capacity: object?                          // default { minCapacity: 0, maxCapacity: 2 }
  sslPolicy: object?                         // default Azure baseline
}
```

**Resources deployed when `enabled = true`** (only effective with `networkIsolation`, `deployContainerEnv`, and at least one entry in `containerAppsList`):

| Resource | Purpose |
| --- | --- |
| `Microsoft.Network/networkSecurityGroups` (`nsg-<vnet>-AppGatewaySubnet`) | Deny-all inbound except `GatewayManager` (65200-65535) and `AzureLoadBalancer`. Adds an `AllowHttpsFromAllowedSources` rule on TCP/443 only when `allowedSourceAddressPrefixes` is non-empty. **Port 80 is never opened from the Internet.** |
| `Microsoft.Network/publicIPAddresses` | Standard SKU, Static, zone-redundant when `useZoneRedundancy=true`. |
| `Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies` | OWASP CRS 3.2, mode `Prevention` (or `Detection`), `wafCustomRules` merged in. |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | Dedicated UAI for the gateway. |
| `Microsoft.Authorization/roleAssignments` (`Key Vault Secrets User`) | Granted to the AGW UAI on the landing-zone Key Vault when `deployKeyVault=true`. External Key Vaults must be granted manually. |
| `Microsoft.Network/applicationGateways` | WAF_v2 SKU, autoscale 0..2, zone-redundant, attached to the existing `AppGatewaySubnet` (192.168.3.0/27). Backend pool targets the Container App's internal FQDN over HTTPS:443 with `pickHostNameFromBackendAddress=true`. |
| Diagnostic settings | Streamed to the existing Log Analytics workspace (`allLogs` + `AllMetrics`). |

**Two operational states:**

1. **Skeleton mode** (`enabled=true` and either `sslCertSecretId` or `frontendHostName` empty)
   - Gateway exists with a single HTTP:80 listener routed to the backend.
   - NSG denies all Internet inbound (port 80 is never opened by the NSG).
   - The skeleton is **inert**: no client can reach it from the Internet until the operator transitions to live mode.

2. **Live mode** (`enabled=true` with both `sslCertSecretId` and `frontendHostName` set, plus `allowedSourceAddressPrefixes` non-empty)
   - HTTPS:443 listener using the Key Vault certificate (the AGW UAI reads it via `Key Vault Secrets User`).
   - HTTP:80 becomes a permanent HTTP→HTTPS redirect.
   - NSG allows TCP/443 from the supplied source CIDRs only.

**Post-deploy runbook (provider-agnostic DNS + jumpbox ACME):**

1. **Workstation (DNS provider side):** choose your DNS provider/registrar and prepare your hostname (example: `app.contoso.com`). No provider-specific integration is required in this landing zone.
2. **Jumpbox (certificate issuance/import side):** use the built-in ACME client installed by `install.ps1` at `C:\tools\win-acme\wacs.exe` (DNS-01 flow), then import the resulting certificate into the landing-zone Key Vault. The jumpbox MI has `Key Vault Certificates Officer` for this workflow.
3. **Workstation (DNS provider side):** create/update the public DNS A record for the hostname pointing at `PUBLIC_INGRESS_PUBLIC_IP` (deployment output).
4. Capture the **versionless** Key Vault secret URI for the certificate (`https://<kv>.vault.azure.net/secrets/<name>`), then set operator parameters in `main.parameters.json` (or via `azd env set` followed by an edit since `publicIngress` is an aggregate object):
   ```jsonc
   "publicIngress": {
      "value": {
       "enabled": true,
       "frontendHostName": "app.contoso.com",
       "sslCertSecretId": "https://<kv>.vault.azure.net/secrets/<name>",
        "allowedSourceAddressPrefixes": ["203.0.113.0/24"]
      }
    }
    ```
5. Run `azd provision` again. The HTTPS listener, redirect rule, and NSG allow rule are now in place.
6. Validate end-to-end: `curl -v https://app.contoso.com/` should return the Container App's response; `curl -v http://app.contoso.com/` should redirect to HTTPS.

**Teardown:** run `azd down` to remove the entire deployment, or delete the gateway/PIP/WAF policy/NSG/UAI manually. As stated above, flipping `enabled` back to `false` and re-provisioning will **not** delete the resources due to ARM incremental deployment semantics.

**Outputs surfaced by `main.bicep`:**

| Output | Description |
| --- | --- |
| `PUBLIC_INGRESS_ENABLED` | Whether the stack was effectively deployed (also requires `networkIsolation` + `deployContainerEnv` + non-empty `containerAppsList`). |
| `PUBLIC_INGRESS_PUBLIC_IP` | The gateway's public IPv4 address (point your DNS A record at this). |
| `PUBLIC_INGRESS_GATEWAY_RESOURCE_ID` | Application Gateway resource ID. |
| `PUBLIC_INGRESS_NSG_RESOURCE_ID` | NSG attached to the AGW subnet. |
| `PUBLIC_INGRESS_WAF_POLICY_RESOURCE_ID` | WAF policy resource ID (for adding custom rules outside the template). |
| `PUBLIC_INGRESS_IDENTITY_PRINCIPAL_ID` | Principal ID of the AGW UAI (use to grant access to external Key Vaults). |
| `PUBLIC_INGRESS_LIVE` | `true` only when both `sslCertSecretId` and `frontendHostName` are set (live mode). |

In addition, the landing zone now surfaces a small set of outputs that consumers (and this module) depend on: `APP_GATEWAY_SUBNET_RESOURCE_ID`, `VNET_RESOURCE_ID`, `KEY_VAULT_RESOURCE_ID`, `KEY_VAULT_NAME`, `LOG_ANALYTICS_RESOURCE_ID`, and `CONTAINER_APP_INTERNAL_FQDN`.
