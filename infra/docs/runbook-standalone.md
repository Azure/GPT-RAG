# Runbook — Standalone deployment

This runbook covers the simplest deployment scenario: a single Azure subscription, no external hub, all networking and platform resources owned by the AI Landing Zone itself.

This is the default `deploymentMode=standalone` setting and is what `azd init -t azure/bicep-ptn-aiml-landing-zone` produces out of the box.

> If you're building an AI workload that integrates with an existing Application Landing Zone, use the [Hub-and-Spoke runbook](./runbook-hub-spoke.md) instead.

---

## 1. What you'll end up with

```
+--------------------------------------------------+
|  Single VNet (192.168.0.0/22)                    |
|  rg-ailz-MMDDYYHHMM                              |
|                                                  |
|    AI Foundry account + project                  |
|    Container Apps Environment (internal)         |
|    AI Search, Cosmos DB, Key Vault, ACR, Storage |
|    App Configuration                             |
|    Application Insights + Log Analytics WS       |
|    Azure Firewall (egress control)               |
|    Azure Bastion (jumpbox access)                |
|    Jumpbox VM (private IP only)                  |
|    NAT Gateway                                   |
|    Private Endpoints + Private DNS zones         |
+--------------------------------------------------+
```

All in a single resource group, no peering, no external dependencies.

---

## 2. Prerequisites

| What | Why |
| --- | --- |
| Azure subscription with **Contributor** + **User Access Administrator** | Resources + RBAC |
| `az` ≥ 2.60, `azd` ≥ 1.25, PowerShell 7 | Tooling |
| ≥ 10 vCPU quota for `standardDSv2Family` (jumpbox + ACA env) | Default sizing |
| ≥ 5 vCPU quota for `standardDdsv5Family` in your target region | AI Foundry compute |

```pwsh
az login
azd auth login
az account set --subscription '<your-subscription-id>'
```

---

## 3. Initialize the project

You can either work from a fresh `azd init` (consumer pattern) or directly from the repo.

### 3.1. Consumer / `azd init` pattern (recommended for production use)

```pwsh
azd init -t azure/bicep-ptn-aiml-landing-zone
cd <project-folder>
```

This downloads the template into a new folder. You'll customize `main.parameters.json` here without touching the source repo.

### 3.2. Local repo pattern (recommended for landing-zone development)

```pwsh
git clone https://github.com/Azure/bicep-ptn-aiml-landing-zone.git
cd bicep-ptn-aiml-landing-zone
```

---

## 4. Configure the deployment

Choose between **basic** (public, no isolation) for demos and **Zero Trust** (production) below.

### 4.1. Basic (demo) deployment

```pwsh
azd env new ailz-demo
```

That's it — defaults are fine. PaaS planes are public, no PEs, no firewall. Skip ahead to [§5 Provision](#5-provision).

### 4.2. Zero Trust (production) deployment

```pwsh
$stamp = Get-Date -Format 'MMddyyHHmm'
azd env new "ailz-$stamp"

azd env set NETWORK_ISOLATION true
azd env set DEPLOYMENT_MODE standalone        # default; included for clarity
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION true
azd env set DEPLOY_NAT_GATEWAY true
azd env set DEPLOY_AZURE_FIREWALL true
```

The five `DEPLOY_*` flags above match what v1.x used to gate behind the single `DEPLOY_VM` flag. They're listed individually here so you can turn any single one off — for instance, `DEPLOY_AZURE_FIREWALL false` if your egress is managed by a central policy at the management-group level, or `DEPLOY_BASTION false` if you have a workstation reaching the spoke via a corporate VPN.

#### Optional: allow specific developer IPs through PaaS planes

```pwsh
azd env set ALLOWED_IP_RANGES '["203.0.113.10/32","198.51.100.0/24"]'
```

These CIDRs become the only public IPs allowed to hit the data planes of Storage, Key Vault, App Configuration, ACR, Cosmos DB, AI Search, and the AI Foundry storage account. Useful for letting a development laptop talk to Cosmos directly without RDP'ing into the jumpbox. Combine with `NETWORK_ISOLATION=true` for defense in depth — workloads talk through PEs, named developers also have an exception.

#### Optional: Foundry inference-only

```pwsh
azd env set DEPLOY_AAF_AGENT_SVC false
```

This keeps the AI Foundry account, project, and model deployments, but skips the Agent Service Standard Setup and its associated AI Search, Storage, Cosmos DB, and Key Vault resources. `DEPLOY_SEARCH_SERVICE` remains independent and controls only the workload/RAG Search service.

#### Optional: GPT-RAG Foundry IQ Pattern B

Use this only for a GPT-RAG environment that has been validated for Foundry IQ.
Pattern B registers the existing GPT-RAG Azure AI Search index as a Foundry IQ
`searchIndex` knowledge source.

```pwsh
azd env set RETRIEVAL_BACKEND foundry_iq
azd env set FOUNDRY_IQ_PATTERN searchIndex
azd env set FOUNDRY_IQ_API_VERSION 2026-05-01-preview
azd env set FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN free
azd env set FOUNDRY_IQ_FILTER_ADD_ON_ENABLED true
```

After `azd provision`, run `scripts/Configure-FoundryIQKnowledgeBase.ps1` to
create or update the Search data-plane knowledge source and knowledge base. The
caller needs **Search Service Contributor** on the Search service. Set
`FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN=standard` only after billing
approval.

#### Optional: jumpbox post-config bootstrap

`main.bicep` ships an `install.ps1` Custom Script Extension that installs az/azd/git/PowerShell modules and clones the repos listed in `manifest.json` into `C:\github\`. To run it during provisioning:

```pwsh
azd env set DEPLOY_SOFTWARE true
```

You can leave it off (`false`) and run the bootstrap manually after RDP'ing into the jumpbox via Bastion.

### 4.3. Opt-in solution Storage migration

Use the canonical [Solution Storage access controls](../README.md#solution-storage-access-controls)
reference for the three parameter types, exact bypass spellings, and native JSON
profiles. Defaults remain `AzureServices`, `[]`, and `true` in both basic and
isolated modes. These inputs affect only solution Storage, not auxiliary
Foundry Storage. Existing managed identities, RBAC, private endpoints/DNS, and
other account settings are unchanged.

For a new private deployment with no Defender integration, the README's
`None` / `false` / `[]` profile needs no scanner exception. For an existing
account, **complete the inventory and authentication tests before opting in**:

1. **Inventory consumers and owners first.** Identify account-key clients,
   key-based connection strings, account SAS, service SAS, and Azure Files
   clients (including tools, mounts, and portal workflows). Record their
   supported authentication paths without logging credentials. Inventory
   current trusted-service/resource-instance exceptions, Azure Policy effects,
   and any automation or team that also owns the account ACLs.
2. **Test replacement authentication before disabling Shared Key.** Migrate
   clients to supported Microsoft Entra authorization, preferably managed
   identity; test Blob user-delegation SAS where used. Account/service SAS use
   Shared Key and are denied when it is disabled; Blob user-delegation SAS is
   distinct. Confirm service/protocol-specific support for Azure Files rather
   than assuming Blob behavior applies. Test each actual client from its
   intended network with approved data permissions. See
   [Prevent Shared Key authorization](https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent).
   These inputs do not create or change RBAC assignments.
3. **Declare the complete approved exceptions.** In the consumer-owned native
   parameter overlay, include only explicitly approved existing `resourceId`
   and `tenantId` pairs. Each instance must be eligible and in the same tenant
   as Storage; copy its exact ARM ID, not a principal ID or a guessed
   solution-RG scanner ID. Network eligibility is independent of data
   permission. Coordinate the complete list with external ACL owners:
   `[]`, including omission/default, removes resource-instance exceptions
   rather than preserving manual rules. Do not import arbitrary live rules
   or use wildcards. No scanner, Defender plan, or role is created.
4. **Select the profile and review the effective deployment.** After the client
   tests, set `storageAccountNetworkAclsBypass` to `None` and
   `storageAccountAllowSharedKeyAccess` to native Boolean `false`, with `[]`
   or the approved complete rule list. Ensure the actual deployment parameter
   file receives the overlay; `azd env set` has no mapping for these fields.
   For a private profile, also review `networkIsolation=true` and empty
   `allowedIpRanges`. `None` alone or disabled public network access alone is
   not a guarantee: trusted-service/resource-instance exceptions can still
   matter. PNA, IP rules, and `defaultAction` retain the independent behavior
   described in the README. Inspect Azure Policy outcomes, not just inputs.
5. **Review preflight and preview, then seek deployment approval.** For a direct
   template deployment, run the existing
   `pwsh ./scripts/Invoke-PreflightChecks.ps1` and `azd provision --preview`.
   Submodule consumers should use their existing preprovision hook/script path
   against the resolved overlay and run preview from the consumer project.
   Review scopes, effective parameter values, unexpected exposure/replacement,
   and Policy findings; do not bypass failures. AVM 0.26.2 still has secure
   outputs calling management-plane `listKeys()`, so disabling Shared Key is
   not a key-free deployment or removal of the deployment identity's existing
   requirements. Preflight/preview are risk controls, not live authentication
   proof or authorization to provision.
6. **Verify after separately approved provisioning.** Compare bypass, Shared
   Key, the entire rule list, PNA/default action, and IP rules with the reviewed
   desired state. For a persistence check, obtain approval for two deployments
   with identical inputs and compare after both, without manual ACL repair.
   Re-test approved Entra/user-delegation clients and confirm key-based requests
   are denied. An already-enabled Defender scanner needs its own authorized
   operational test and observed scan result; ACL equality does not prove
   scanning. Record each unrun check as not run.

**Consumer adoption and recovery:** use the normal reviewed ALZ pin and
parameter-overlay workflow with a revision containing these inputs. Do not
patch generated `infra/` checkouts or accelerator-generated files to work
around an older pin. Keep reviewed desired rules and fix forward with the
least-permissive working profile if validation fails. Reverting to an older
ALZ template can reintroduce `AzureServices`, allow Shared Key again, and lose
the declared rules. Re-enabling keys or broader bypass requires explicit
operator approval; it is not an automatic recovery step. Coordinate any rule
change with its owners and repeat preview before an approved roll-forward.

For BYO networks or shared ACL ownership, also see the
[Hub-and-Spoke migration guidance](./runbook-hub-spoke.md#612-opt-in-solution-storage-migration).

---

## 5. Provision

```pwsh
azd provision
```

> A **pre-flight script** (`scripts/Invoke-PreflightChecks.ps1`) runs automatically as an `azd preprovision` hook before the deployment touches Azure. It validates the parameter set and fails fast on deterministic mistakes (CIDR overlap, missing BYO resources, conflicting flags, and insufficient AI Foundry OpenAI model quota). Bypass with `$env:PREFLIGHT_SKIP = 'true'` if needed. See [docs/v2-migration.md §6](./v2-migration.md#6-pre-flight-validation-script).

**Expected duration**:

| Topology | Time |
| --- | --- |
| Basic (no isolation) | ~10–15 min |
| Zero Trust without firewall | ~20–25 min |
| Zero Trust full (firewall + jumpbox + bootstrap) | ~30–40 min |

If `azd` reports "Login expired" mid-deploy, run `azd auth login` and re-run `azd provision`. The in-flight ARM deployment continues server-side; `azd` just lost its progress stream.

---

## 6. Verify

```pwsh
$rg = azd env get-value AZURE_RESOURCE_GROUP

az resource list -g $rg --query "length(@)" -o tsv
az containerapp list -g $rg --query "[].{name:name,fqdn:properties.configuration.ingress.fqdn}" -o table
az vm get-instance-view -g $rg -n (az vm list -g $rg --query "[0].name" -o tsv) `
    --query "instanceView.statuses[?starts_with(code,'PowerState')].displayStatus" -o tsv
```

Expected: ~60 resources for basic, ~80 for Zero Trust full. Container App FQDN is the public DNS for the ACA env (which under `networkIsolation=true` is internal-only and only resolves to a private IP from inside the VNet).

---

## 7. Test the hello-world app

### 7.1. Basic (public) deployment

```pwsh
$fqdn = az containerapp show -g $rg -n (az containerapp list -g $rg --query "[0].name" -o tsv) --query "properties.configuration.ingress.fqdn" -o tsv
curl http://$fqdn
```

You should see the ASP.NET hello-world HTML.

### 7.2. Zero Trust deployment — via the jumpbox

Under `networkIsolation=true` the Container App is **not** reachable from your workstation. Test from the jumpbox:

```pwsh
$vmName = az vm list -g $rg --query "[0].name" -o tsv
$fqdn   = az containerapp show -g $rg -n (az containerapp list -g $rg --query "[0].name" -o tsv) --query "properties.configuration.ingress.fqdn" -o tsv

# Non-interactive equivalent of "RDP in and run curl":
$script = @"
try {
    `$r = Invoke-WebRequest -Uri 'http://$fqdn' -UseBasicParsing -TimeoutSec 30
    Write-Host ('Status=' + `$r.StatusCode + ' Len=' + `$r.Content.Length)
} catch { Write-Host ('ERROR: ' + `$_.Exception.Message) }
"@

az vm run-command invoke -g $rg -n $vmName --command-id RunPowerShellScript --scripts $script --query "value[0].message" -o tsv
```

Expected: `Status=200 Len=3753`.

### 7.3. Interactive RDP via Bastion

Reset the jumpbox password first (Azure portal → VM → **Support + troubleshooting → Reset password**, username `testvmuser`), then:

```pwsh
$bastionName = az network bastion list -g $rg --query "[0].name" -o tsv
$vmId        = az vm show -g $rg -n $vmName --query id -o tsv

az network bastion rdp --name $bastionName --resource-group $rg --target-resource-id $vmId
```

Once logged in, open the browser and navigate to `http://<container-app-fqdn>`.

---

## 8. Tear down

```pwsh
azd down --force --purge
```

`--purge` immediately purges soft-deleted Key Vault / App Configuration / Cognitive Services accounts so the names are available for the next deployment.

---

## 9. Common knobs

These are the parameters most operators tweak after the first deploy. Set them via `azd env set` (and re-`azd provision`) or in `main.parameters.json`.

| Env var | Default | What it does |
| --- | --- | --- |
| `NETWORK_ISOLATION` | `false` | Zero Trust mode: PEs + Private DNS + public access disabled on PaaS |
| `ALLOWED_IP_RANGES` | `[]` | Public IP CIDRs allowed through PaaS data planes (independent of `NETWORK_ISOLATION`) |
| `DEPLOY_AZURE_FIREWALL` | `true` (Zero Trust only) | Set `false` if your egress is managed centrally |
| `DEPLOY_JUMPBOX` | inherits `DEPLOY_VM` | Jumpbox VM for in-VNet operations |
| `DEPLOY_BASTION` | inherits `DEPLOY_VM` | Azure Bastion to reach the jumpbox |
| `DEPLOY_NAT_GATEWAY` | inherits `DEPLOY_VM` | NAT Gateway for jumpbox outbound traffic |
| `DEPLOY_SEARCH_SERVICE` | `true` | Set `false` to skip AI Search (saves ~$75/mo and 7 minutes of provision time) |
| `DEPLOY_POSTGRES` | `false` | Set `true` to add Postgres Flexible Server |
| `DEPLOY_COSMOS_DB` | `true` | Include the workload Cosmos DB account |
| `DEPLOY_CONTAINER_APPS` | `true` | Include the configured Container Apps |
| `DEPLOY_CONTAINER_REGISTRY` | `true` | Include Azure Container Registry |
| `DEPLOY_CONTAINER_ENV` | `true` | Include the Container Apps Environment |
| `DEPLOY_NSGS` | `true` | Include landing-zone-managed network security groups |
| `AI_FOUNDRY_DISABLE_LOCAL_AUTH` | `true` | Keep Foundry local API-key authentication disabled |
| `AZURE_SEARCH_LOCATION` | same as `AZURE_LOCATION` | Cross-region Search (PE still in spoke region) — workaround for regional SKU capacity |
| `BASTION_SKU_NAME` | `Standard` | `Basic`, `Standard`, or `Premium` |
| `BASTION_ENABLE_TUNNELING` | `false` | Set `true` for native-client tunneling (RDP/SSH via `az network bastion rdp/ssh`) |
| `DEPLOY_SOFTWARE` | `true` when `DEPLOY_VM=true` | Run jumpbox post-config Custom Script Extension during provision |
| `EXTEND_FIREWALL_FOR_JUMPBOX_BOOTSTRAP` | `true` when `DEPLOY_VM=true` | Add jumpbox-scoped FQDN rules to the firewall |
| `PUBLIC_INGRESS` | `{ enabled: false }` | Set to `{ enabled: true, ... }` to add an Application Gateway WAF v2 in front of the internal ACA env |

Component selectors `DEPLOY_COSMOS_DB`, `DEPLOY_CONTAINER_APPS`,
`DEPLOY_CONTAINER_REGISTRY`, `DEPLOY_CONTAINER_ENV`, and `DEPLOY_NSGS` accept
only `true` or `false` (case-insensitive). Container Apps require
`DEPLOY_CONTAINER_ENV=true`; an environment-only deployment is supported.
Container App API keys require apps, Key Vault, App Configuration, and
`appRuntimeConfigurationMode=appConfig`.

These selectors control what is included in the next incremental deployment.
Changing one to `false` does not delete a resource or App Configuration key
created earlier. Decommission those artifacts explicitly after reviewing
dependencies and data-retention requirements. Keep
`AI_FOUNDRY_DISABLE_LOCAL_AUTH=true` unless API-key authentication is an
explicit requirement.

For the full list, see `main.bicep` parameters and `main.parameters.json`.

---

## 10. Troubleshooting

| Symptom | Resolution |
| --- | --- |
| `InsufficientResourcesAvailable` on AI Search | `azd env set AZURE_SEARCH_LOCATION eastus` (or another sibling region) and re-`azd provision` |
| `NameUnavailable: appcs-... is already in use` | Previous Key Vault / App Config in soft-delete state; `az appconfig purge --name <name> --yes` then `az keyvault purge --name <name> --location <loc>` |
| `Login expired` mid-deploy | `azd auth login` and re-`azd provision`; in-flight deployment continues server-side |
| Container App returns 502 | Image pull failure: `az containerapp logs show -g <rg> -n <ca>`; if it's an MCR pull, check the firewall `AllowMicrosoftContainerRegistry` rule (it's on by default) |
| Jumpbox post-config script (CSE) failed | Open the VM in the portal → **Settings → Extensions → AzureCustomScriptExtension** to see the error. Common cause: firewall blocking an FQDN the bootstrap needs — see the firewall egress allow-list table in the [main README](../README.md#firewall-egress-allow-list-network-isolation) |
| Provision succeeded but DNS doesn't resolve PaaS FQDNs from the jumpbox | The Private DNS zone is not linked to the spoke VNet, or you set a BYO override (`EXISTING_PRIVATE_DNS_ZONE_*_RESOURCE_ID`) pointing at a zone in a different VNet without manually creating the link |

---

## 11. Next steps

- For **multi-spoke / ALZ-integrated** topologies, follow the [Hub-and-Spoke runbook](./runbook-hub-spoke.md).
- For **upgrading an existing v1.x deployment** to v2.0.0, follow the [Migration guide](./v2-migration.md).
- To **consume this landing zone from a downstream accelerator** (submodule pattern), see [README §How to consume from another repository](../README.md#how-to-consume-this-landing-zone-from-another-repository) (TBD in v2.0 follow-up).
