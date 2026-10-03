# Migrating from v1.x to v2

This document walks you through upgrading an existing AI Landing Zone deployment, or a downstream accelerator that consumes this repo as a submodule, from the v1.x line to **v2**.

v2 is a **major release** (see [issue #58](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/58)) that introduces hub-and-spoke composability, granular reuse of platform resources, IP allow-lists, and a deployment-mode preset. The Zero Trust topology that v1.x operators already use keeps working.

> If you are deploying for the first time, you do **not** need this document — go straight to the [Standalone runbook](./runbook-standalone.md) or the [Hub-and-Spoke runbook](./runbook-hub-spoke.md).

---

## 1. Why v2?

v1.x was designed for the **standalone** scenario: a customer points `azd provision` at an empty subscription, the template builds everything — VNet, Firewall, DNS zones, jumpbox, Bastion, App Insights, Log Analytics, the application stack — and the customer accesses the result.

That assumption breaks when the customer already has an **Application Landing Zone** (or wants to share platform resources across multiple AI workloads):

- the **hub** subscription owns the Azure Firewall, the central Private DNS zones, the Bastion host, and the Log Analytics workspace
- the **spoke** subscription is where the AI workload itself lands, peered to the hub
- the spoke must **not** redeploy hub-owned resources, but **must** still come up with a working private-DNS resolution chain, a route to the hub firewall, and an observability story that does not duplicate platform telemetry

v2.0.0 unblocks this scenario by letting any v1.x resource be brought in from the outside via an existing-resource-ID parameter, without losing the ability to fall back to "create it for me".

Additional deployment-flexibility requirements that v2.0.0 also addresses (common across hub-and-spoke and ALZ-integrated topologies — explained in detail below):

- **Cross-region private endpoints** — a spoke in `eastus2` consuming an AI Search service that lives in `eastus` because the spoke's home region ran out of capacity for that SKU.
- **Resource group override for private endpoints** — placing every PE in a single centrally-managed RG so the platform team can attach policies and locks in one place.
- **Enable / disable DNS entries on private endpoints** — handing DNS off to Azure Policy / DDI when the platform team manages the resolution chain externally.
- **Network access control: Disabled / Public / Public with restricted IPs** — explicit IP allow-lists for PaaS services so a dev workstation can hit the data plane without routing the whole development team through Bastion.

These were already partially solvable by hand-editing the template; v2.0.0 makes each one a first-class parameter so the template itself stays the source of truth and `azd` re-provisions stay idempotent.

---

## 2. Big-picture changes

| Capability | v1.x | v2.0.0 |
| --- | --- | --- |
| Topology preset | Implicit | New `deploymentMode` (`standalone` \| `ailz-integrated`) tag on the deployment |
| IP allow-list for PaaS data planes | Not supported | New `allowedIpRanges` parameter, applied to 7 services |
| Jumpbox / Bastion / NAT Gateway | One coarse `deployVM` flag | Three independent flags + BYO resource IDs |
| Observability | Always creates LAW + App Insights | Can reuse existing LAW and App Insights |
| Private DNS zones | Always created by the spoke | Can BYO **per zone** (15 overrides) |
| Hub egress | Implicit Azure Firewall in same RG | Can route to an **external** firewall / NVA via next-hop IP |
| Hub peering | Manual post-deploy | Spoke→hub created by `main.bicep`; reverse helper script shipped |
| DNS link suffix | Single, fixed | Configurable `dnsZoneLinkSuffix` for multi-spoke shared zones |
| Container app port | Always `8080` | Per-app `target_port` honored (still defaults to `8080`) |
| Generated names | Legacy `resourceToken` pattern | Legacy remains the default; `resourceNamingMode=caf` is opt-in for new greenfield deployments |

Internally, every v2.0.0 parameter has either a sensible default that reproduces v1.x behavior, or a `null`/empty default that means **"don't override"**. Apart from the explicit `deployVM` → `deployJumpbox`/`deployBastion`/`deployNatGateway` split, the v1.x mental model still works.

Name generation also stays backward-compatible. Existing deployments should keep
`RESOURCE_NAMING_MODE=legacy` unless they intentionally want a new greenfield
environment with CAF-style generated names. Explicit `*Name` parameters still
override generated names in either mode.

---

## 3. Things that need attention when upgrading

### 3.1. `deployVM` is split into three flags

`deployVM` is **deprecated** and removed from `main.parameters.json` defaults in a future release. For v2.0.0 it remains as a backwards-compatible umbrella: when explicitly set, it acts as the default for all three new flags that don't have their own explicit value.

Replace:

```bash
azd env set DEPLOY_VM true
```

with one of these, depending on intent:

```bash
# Standalone topology, same as old behavior (jumpbox + bastion + NAT GW)
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION true
azd env set DEPLOY_NAT_GATEWAY true
```

```bash
# Hub-and-Spoke topology: jumpbox + own NAT GW, but reuse hub Bastion
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION false
azd env set DEPLOY_NAT_GATEWAY true
azd env set EXISTING_BASTION_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Network/bastionHosts/<hub-bastion-name>
```

```bash
# ALZ-integrated topology: reuse hub-managed jumpbox VM as well
azd env set DEPLOY_JUMPBOX false
azd env set EXISTING_JUMPBOX_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Compute/virtualMachines/<hub-vm>
azd env set DEPLOY_BASTION false
azd env set EXISTING_BASTION_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Network/bastionHosts/<hub-bastion>
azd env set DEPLOY_NAT_GATEWAY false
azd env set EXISTING_NAT_GATEWAY_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Network/natGateways/<hub-natgw>
```

If you leave `DEPLOY_VM` unset and **don't** set the three new flags either, behavior is **off** for all three (this matches v1.x when `deployVM=false`).

> **CI/CD action**: search your pipelines for `DEPLOY_VM` and update accordingly. The legacy variable still works for v2.0.x; planning to remove in v3.0.0.

### 3.2. `networkIsolation` semantics are unchanged, but `allowedIpRanges` is now available

`NETWORK_ISOLATION=true` still puts the AI Landing Zone in Zero Trust mode (Private Endpoints, Private DNS zones, public access disabled on PaaS services, traffic forced through the firewall).

What changed: you can now **also** allow specific public IPs to reach the data planes of PaaS services — useful for letting a developer workstation talk to Cosmos DB or App Configuration without going through Bastion. This is gated by:

```bash
azd env set NETWORK_ISOLATION true                  # unchanged
azd env set ALLOWED_IP_RANGES '["198.51.100.10/32","203.0.113.0/24"]'
```

When `allowedIpRanges` is non-empty, the public endpoint is opened only to those CIDRs (default action = `Deny`). Applied to: Storage, Key Vault, App Configuration, Container Registry, Cosmos DB, AI Search, the AI Foundry storage account.

The IP allow-list is **independent** of Zero Trust:

- `networkIsolation=false, allowedIpRanges=[]` — fully public PaaS planes (dev / demo only)
- `networkIsolation=false, allowedIpRanges=[...CIDRs]` — public planes restricted to a CIDR list (rare, but supported for hybrid pilot scenarios)
- `networkIsolation=true, allowedIpRanges=[]` — Zero Trust, PaaS reachable only through PE (default)
- `networkIsolation=true, allowedIpRanges=[...CIDRs]` — Zero Trust plus opt-in IP exceptions on top (defense-in-depth + named-developer egress)

### 3.3. Observability can be reused

Production AI Landing Zones typically already have a central Log Analytics workspace owned by the platform team. v2.0.0 lets the spoke reuse it instead of provisioning its own:

```bash
azd env set EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.OperationalInsights/workspaces/<law>
```

When set, the spoke skips LAW creation and binds App Insights, Container Apps Environment, and AMPLS diagnostics to the hub workspace. The cross-subscription / cross-RG case works as long as the deploying identity has `Log Analytics Contributor` on the hub workspace and the workspace is in a region that allows your spoke resources to send logs (typically same region or a paired region).

You can also bring your own Application Insights:

```bash
azd env set EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Insights/components/<appi>
azd env set EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING '<conn-string>'
```

When set, the App Configuration `APPLICATIONINSIGHTS_*` keys point at the existing component, the AI Foundry App Insights connection points at it cross-RG, and the AMPLS scope (if any) does not enroll the resource (the hub already does that).

> **Action**: if you previously had two separate LAWs (hub and spoke) and want to consolidate, set the env var, re-provision, then manually delete the spoke LAW that v1.x left behind (`azd` does not delete resources it no longer references).

### 3.4. Hub-to-spoke peering is now created from the spoke side

If you provide the hub VNet ID:

```bash
azd env set HUB_INTEGRATION_HUB_VNET_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet>
```

`main.bicep` creates the **spoke → hub** peering automatically (`hubIntegrationCreateHubPeering=true` by default). The reverse direction (`hub → spoke`) is **not** created — typically the spoke deployment does not have write access to the hub RG.

To create the reverse direction:

```powershell
pwsh ./tests/scripts/Add-HubSpokePeering.ps1 `
    -HubVnetResourceId  /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet> `
    -SpokeVnetResourceId /subscriptions/<sub>/resourceGroups/<spoke-rg>/providers/Microsoft.Network/virtualNetworks/<spoke-vnet>
```

Run this with credentials that **do** have write access to the hub RG (typically a platform-team operator).

### 3.5. External egress (no spoke firewall)

If your hub already runs Azure Firewall or an NVA, you don't need another firewall in the spoke. v2.0.0 lets you:

```bash
azd env set DEPLOY_AZURE_FIREWALL false
azd env set HUB_INTEGRATION_EGRESS_NEXT_HOP_IP 10.100.0.4   # hub FW private IP
```

When both are set, the spoke creates a Route Table with a `0.0.0.0/0 → <hub FW IP>` UDR and attaches it to all workload subnets. PE traffic stays internal to the spoke; only Internet-bound traffic is forwarded to the hub FW.

Alternatively, BYO route table (e.g., managed by Azure Policy):

```bash
azd env set HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID /subscriptions/<sub>/resourceGroups/<hub-rg>/providers/Microsoft.Network/routeTables/<rt>
```

When set, the spoke does not create its own RT; the existing RT is associated with workload subnets.

### 3.6. BYO Private DNS zones (per zone)

In ALZ topologies, Private DNS zones live in a central platform subscription. To reuse them, set as many of these as apply:

```bash
azd env set EXISTING_PRIVATE_DNS_ZONE_OPENAI_RESOURCE_ID         /subscriptions/<sub>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com
azd env set EXISTING_PRIVATE_DNS_ZONE_COGSVCS_RESOURCE_ID        ...
azd env set EXISTING_PRIVATE_DNS_ZONE_AISERVICES_RESOURCE_ID     ...
azd env set EXISTING_PRIVATE_DNS_ZONE_SEARCH_RESOURCE_ID         ...
azd env set EXISTING_PRIVATE_DNS_ZONE_COSMOS_RESOURCE_ID         ...
azd env set EXISTING_PRIVATE_DNS_ZONE_BLOB_RESOURCE_ID           ...
azd env set EXISTING_PRIVATE_DNS_ZONE_KEYVAULT_RESOURCE_ID       ...
azd env set EXISTING_PRIVATE_DNS_ZONE_APPCONFIG_RESOURCE_ID      ...
azd env set EXISTING_PRIVATE_DNS_ZONE_CONTAINERAPPS_RESOURCE_ID  ...
azd env set EXISTING_PRIVATE_DNS_ZONE_ACR_RESOURCE_ID            ...
azd env set EXISTING_PRIVATE_DNS_ZONE_AZUREMONITOR_RESOURCE_ID   ...
azd env set EXISTING_PRIVATE_DNS_ZONE_OMSOPSINSIGHTS_RESOURCE_ID ...
azd env set EXISTING_PRIVATE_DNS_ZONE_ODSOPSINSIGHTS_RESOURCE_ID ...
azd env set EXISTING_PRIVATE_DNS_ZONE_AZUREAUTOMATION_RESOURCE_ID ...
azd env set EXISTING_PRIVATE_DNS_ZONE_APPINSIGHTS_RESOURCE_ID    ...
```

Each one is **opt-in**. Unset zones continue to be created by the spoke. This lets you migrate incrementally — start by reusing one (e.g., OpenAI) and converting more as your platform team adds them.

For multi-spoke shared zones, set:

```bash
azd env set DNS_ZONE_LINK_SUFFIX spoke02   # unique per spoke
```

This appends `-<suffix>` to the VNet-link names so a single zone can be linked to multiple spoke VNets without name conflicts.

### 3.7. `deploymentMode` preset (advisory)

A new required-ish parameter is added so the topology intent is captured **in the deployment** itself (visible in deployment tags, audit logs, downstream automation):

```bash
azd env set DEPLOYMENT_MODE ailz-integrated   # or 'standalone' (default)
```

The preset is **advisory** in v2.0.0 — it does not auto-flip any other flag. Operators still set the BYO / hub-integration flags explicitly. A future v2.x release may make the preset drive defaults.

---

### 3.8. Workload App Configuration passthrough (additive, opt-in)

The `additionalAppConfigurationSettings` parameter lets a solution accelerator
publish its own runtime key-values into the App Configuration store without new
template parameters. It defaults to an empty array, so existing deployments are
unaffected and produce byte-identical App Configuration output.

If your accelerator currently drives runtime config through the workload-specific
`foundryIq*` parameters, nothing breaks: those parameters still work. Going
forward, prefer publishing accelerator keys through the passthrough so the
landing zone stays workload-agnostic:

```bicep
additionalAppConfigurationSettings: [
  { name: 'MY_WORKLOAD_FLAG', value: 'true' }
  { name: 'MY_WORKLOAD_MODE', value: 'hybrid', label: 'prod' }
]
```

Notes:

- Values are plaintext. Do not pass secrets; use Key Vault references instead.
- Each `name` + `label` pair must be unique. A passthrough entry that collides
  with a built-in setting wins, so it can also override a stamped default.
- App Configuration is only populated on non-isolated deployments where the
  runtime config store is App Configuration. In isolated deployments, stamp
  workload keys through the jumpbox post-provision step instead.
- In the `containerEnv` runtime mode the same entries are injected as Container
  App env vars (name/value only), so the passthrough works in both modes.

`retrievalBackend` is **not** deprecated: it gates real infrastructure (the AI
Foundry knowledge-base connection and shared private links), so it stays a
first-class parameter.

---

## 4. Things that are NOT broken

These v1.x patterns continue to work unchanged:

- `azd init -t azure/bicep-ptn-aiml-landing-zone` (template entry remains the same)
- `azd provision` flow
- `azd env set NETWORK_ISOLATION true` for Zero Trust deployments
- `main.parameters.json` overrides instead of env vars
- `manifest.json` `tag` / `ailz_tag` / `components` bootstrap contract — your downstream accelerator's `manifest.json` does not need a structural change to pick up v2.0.0
- Downstream consumer pattern (submodule pinned to a tag, overlay `main.parameters.json` + `manifest.json` copied in by `preprovision`)

You also do not need to drain any data: every BYO resource is **referenced** (`existing = ...`), not recreated. Switching between "create" and "BYO" mid-life is supported as long as the resource you point at is in a region that satisfies Azure's regional placement rules for the dependent resources.

---

## 5. Upgrade checklist

For an existing v1.x deployment that you want to bring to v2.0.0:

1. **Pin the submodule (downstream consumers)** to `v2.0.0`:
   ```bash
   git -C infra fetch --tags
   git -C infra checkout tags/v2.0.0
   git config -f .gitmodules submodule.infra.branch v2.0.0
   git add .gitmodules infra && git commit -m "Bump AI LZ infra submodule to v2.0.0"
   ```
2. **Audit env vars / `main.parameters.json` for `DEPLOY_VM`** and replace with the three new flags (see §3.1).
3. **Decide on observability** — reuse the hub LAW (set `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID`) or keep the spoke LAW (no change).
4. **Decide on egress** — keep the spoke Azure Firewall (no change) or switch to hub-managed egress (§3.5).
5. **Decide on Private DNS** — keep spoke-owned zones (no change) or reuse hub zones (§3.6).
6. **Set `DEPLOYMENT_MODE`** to match your topology — `standalone` or `ailz-integrated` (defaults to `standalone`).
7. **Run the pre-flight script** (see §6) — it catches parameter mistakes before `azd provision` does. Skipping it is supported via `PREFLIGHT_SKIP=true` but not recommended for first-time ALZ-integrated deployments.
8. **Run `azd provision`** and verify the deployment plan against the change set you expected.
9. **For hub-and-spoke**, after the spoke provision completes, run `tests/scripts/Add-HubSpokePeering.ps1` from a workstation with access to the hub RG to create the reverse peering.

If you encounter unexpected resource creation (e.g., a duplicate DNS zone), it usually means a BYO env var is unset where it should have been set — re-run with the missing override.

---

## 6. Pre-flight validation script

v2.0.0 ships a read-only pre-flight script — **`scripts/Invoke-PreflightChecks.ps1`** — that validates the effective parameter set **before** `azd provision` reaches Azure Resource Manager. It catches the class of mistakes that otherwise surface as deep, late, hard-to-debug ARM errors.

### What it checks

| Category | Checks |
|---|---|
| **Tooling** | `az`, `azd`, pwsh 7+ on PATH; logged in to Azure |
| **Parameter resolution** | Unresolved `${VAR}` substitutions; missing required values |
| **Topology consistency** | `policyManagedPrivateDns=true` + any BYO `existingPrivateDnsZone*ResourceId` set (conflict); `hubIntegrationEgressNextHopIp` + `hubIntegrationExistingRouteTableResourceId` set together (mutually exclusive); `deployAzureFirewall=true` + external egress IP (likely-unintended); `deploymentMode=ailz-integrated` declared without any hub-integration parameters; `existingApplicationInsightsResourceId` set without a connection string (will fail); `existingApplicationInsightsResourceId` without a matching `existingLogAnalyticsWorkspaceResourceId` unless `allowMixedObservabilityWorkspaces=true`; `networkIsolation=true` with no jumpbox/Bastion/allow-list ingress (you'd lock yourself out) |
| **IP allow-list** | CIDR format validation; `0.0.0.0/0` warning |
| **Local CIDR sanity** | Subnet prefixes contained in the VNet; no subnet-to-subnet overlap; each subnet at or above its minimum size (Bastion /26, Firewall /26, PE /27, jumpbox /29, ACA env /27 — /23 recommended for workload-profile ACA) |
| **BYO VNet (when `useExistingVNet=true`)** | VNet exists; required subnets (`agent`, `pe`, `acaEnvironment`, `jumpbox`, `AzureBastionSubnet`, `AzureFirewallSubnet`) present when `deploySubnets=false`; ACA env subnet has `Microsoft.App/environments` delegation under network isolation |
| **BYO Private DNS** | Each `existingPrivateDnsZone*ResourceId` points at a zone whose name matches the expected `privatelink.<namespace>` convention; zone exists in Azure |
| **BYO observability** | `existingLogAnalyticsWorkspaceResourceId`, `existingApplicationInsightsResourceId`, `existingBastionResourceId`, `existingNatGatewayResourceId`, `hubIntegrationExistingRouteTableResourceId` exist in Azure |
| **Hub VNet overlap** | When `hubIntegrationHubVnetResourceId` is set, the spoke's `vnetAddressPrefixes` do not overlap any of the hub's address prefixes (peering would fail) |
| **Regional readiness** | Provider/location support, jumpbox VM SKU availability, and AI Foundry OpenAI model quota for each OpenAI-format `modelDeploymentList` entry in the AI Foundry region |

### How it runs

The script is wired into `azure.yaml` as a `preprovision` hook, so it runs automatically on every `azd provision`. You can also run it standalone at any time:

```pwsh
pwsh ./scripts/Invoke-PreflightChecks.ps1
```

Useful flags:

| Flag | Purpose |
|---|---|
| `-Strict` | Treat warnings as failures (exit 2). Recommended in CI. |
| `-SkipAzureLookups` | Skip every Azure CLI call. Use for offline / CI scenarios where you only want the deterministic checks. |
| `-Skip` | Skip every check. Identical to `PREFLIGHT_SKIP=true`. Emergency bypass. |
| `-AzdEnv <name>` | Read env values from a specific azd env (otherwise current default). |
| `-ParametersFile <path>` | Override parameters file path. |

### Bypass / opt-out

If you intentionally need to skip the hook (e.g., temporarily during a complex rollback), set `PREFLIGHT_SKIP=true` in your environment:

```pwsh
$env:PREFLIGHT_SKIP = 'true'
azd provision
```

### Submodule consumers

The repo's submodule-consumer pattern means `azd` reads the **consumer's** `azure.yaml`, not this repo's — so the default preprovision hook is invoked only for direct consumers. For submodule consumers, copy this snippet into the consumer's `azure.yaml`:

```yaml
hooks:
  preprovision:
    posix:
      shell: pwsh
      run: ./infra/scripts/Invoke-PreflightChecks.ps1
      continueOnError: false
      interactive: true
    windows:
      shell: pwsh
      run: ./infra/scripts/Invoke-PreflightChecks.ps1
      continueOnError: false
      interactive: true
```

(Adjust `./infra/` to wherever the submodule is mounted.)

### Exit codes

| Code | Meaning |
|---|---|
| `0` | All checks passed (possibly with warnings; warnings are non-fatal unless `-Strict`) |
| `1` | At least one fatal finding — fix before provisioning |
| `2` | Only warnings were raised AND `-Strict` was specified |

---

## 7. Known limitations carried forward to v2.1.x

- `deploymentMode` does not yet auto-derive other flags. Set them explicitly.
- The `deployVM` legacy umbrella flag is retained for v2.x; expected removal in v3.0.0.
