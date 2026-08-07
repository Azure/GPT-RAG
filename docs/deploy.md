# 🚀 Deployment Guide

Use this page as the canonical installation guide. Start with **Basic Deployment** for a simple environment, or **Zero Trust Deployment** when network isolation is required.

> **Note:** You can change parameter values in `main.parameters.json` or set them with `azd env set` before running `azd provision`. This applies only to parameters that support environment variable substitution.

> **Underlying infrastructure:** GPT-RAG provisions the **[Azure AI Landing Zone (AILZ) Bicep module](https://azure.github.io/AI-Landing-Zones/bicep/parameterization)** as its infrastructure foundation. For the full list of parameters, opt-in features (IP allow-lists, BYO Private DNS / Log Analytics, hub-and-spoke integration, etc.), and the v2 migration path, see the [AILZ parameterization reference](https://azure.github.io/AI-Landing-Zones/bicep/parameterization) and the [v2-migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.0/docs/v2-migration.md).

## Prerequisites

**Required Permissions:**

- Azure subscription with **Contributor** and **User Access Admin** roles
- Agreement to Responsible AI terms for Azure AI Services

**Required Tools:**

- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package) (Windows only)
- [Git](https://git-scm.com/downloads)
- [Python 3.12](https://www.python.org/downloads/release/python-3120/)

## Basic Deployment

Quick setup for demos without network isolation. In this mode, the workstation can run the full flow: provision, post-provision configuration, and service deployment.

```
azd init -t azure/gpt-rag
az login
azd auth login
azd env set NETWORK_ISOLATION false
azd provision
azd deploy
```

> Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

> **Resource naming:** Starting with GPT-RAG v3.1.0 and AI Landing Zone v2.2.0,
> fresh deployments name resources using the Cloud Adoption Framework pattern
> (for example `cosmos-<hash>-<env>-<region>-001`). No extra variables are
> required. If you need to keep the pre-v3.1.0 names, set
> `RESOURCE_NAMING_MODE=legacy` before `azd provision`. See the
> [resource naming guide](howto_resource_naming.md) for details, override
> options, and a before/after table.

`azd provision` runs GPT-RAG preflight checks before Azure Resource Manager deployment starts. These checks validate the selected region, jumpbox VM SKU restrictions, provider/location support for AI Search, Cosmos DB, Container Apps, and AI Foundry/Cognitive Services, and Azure OpenAI model quota for the configured deployments. If model quota is insufficient, the hook fails early and suggests candidate regions when possible.

Some transient Azure capacity failures are not exposed by reliable pre-create APIs. For example, Cosmos DB can still fail later with regional high-demand `ServiceUnavailable`; the preflight reports this limitation explicitly. Use `GPT_RAG_REGIONAL_PREFLIGHT_SKIP=true` only to bypass GPT-RAG regional checks, or `PREFLIGHT_SKIP=true` to bypass all preflight hooks.

For current published releases, the `postProvision` hook runs locally after
`azd provision`, and `azd deploy` deploys the UI, orchestrator, and ingestion
services in the classic Container Apps topology. The hosted-default
implementation is merged to `develop`, but the fresh-deployment default changes
only after the release gates below are complete.

### Chat runtime modes (upcoming hosted-default release)

!!! warning "Do not treat the target default as shipped"
    The umbrella implementation merged to `develop` in
    [Azure/GPT-RAG PR #617](https://github.com/Azure/GPT-RAG/pull/617) as
    [`b614d0a`](https://github.com/Azure/GPT-RAG/commit/b614d0ad19a66cbc06b34a3ad764b0d94428999f).
    UI release PR
    [#94](https://github.com/Azure/gpt-rag-ui/pull/94) merged to `main` as
    [`763fa7e`](https://github.com/Azure/gpt-rag-ui/commit/763fa7eb2135037382673d2eb968421f084941cc),
    while AI Landing Zone
    [PR #131](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/131)
    initially stamped and merged the unpublished `v2.5.0` state as
    [`a6ae728`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/commit/a6ae7284d654abb7ec53810cb8765b2975b51baa).
    [PR #132](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/132)
    then fixed the local/CI size-gate defaults, and
    [PR #133](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/133)
    merged that correction to `main`. AILZ `main` and `develop` now both point
    to [`cacf418`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/commit/cacf418216ce7381d06263e0dd704a86b8a6f225).
    AILZ [`v2.5.0`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.5.0)
    is published; UI `v2.6.0` remains unpublished. The capability-first
    continuity contract merged in
    [PR #630](https://github.com/Azure/GPT-RAG/pull/630), but live OQ-OWN
    evidence supersedes it with delegated `x-ms-user-identity`. The platform
    pivot, compatible component pins, and `OWNER_BINDING_VALIDATED` gate are not
    published. Continuity remains off and compatible history endpoints must
    return HTTP 503. Final umbrella pins, integrated validation, and a new
    GPT-RAG release remain. Current published GPT-RAG `v3.7.0` stays classic.
    Use this workflow only with the release that explicitly announces the
    hosted-default contract.

The upcoming release resolves one canonical topology before provisioning and
materializes the corresponding legacy flags and App Configuration values.
Topology never changes automatically during a chat request.

| Environment or operator choice | Resolved settings | Resulting topology |
| --- | --- | --- |
| Genuinely fresh environment after the gated release | `DEPLOYMENT_TOPOLOGY=hosted-no-panel`, `DEPLOY_HOSTED_AGENT_ORCHESTRATION=true`, `DEPLOY_ADMINISTRATIVE_PANEL=false`, `CHAT_BACKEND=hosted_agent` | Web UI and ingestion remain in Container Apps. Chat runs in a Microsoft Foundry hosted agent. No orchestrator Container App or panel-only Cosmos DB is provisioned. |
| Existing environment with persisted topology | Existing topology and `CHAT_BACKEND` stay sticky. An unmarked pre-cutover environment resolves to `classic`. | Upgrade does not implicitly migrate identity, conversation, authorization, or cost semantics. |
| Explicit Container Apps fallback | `DEPLOYMENT_TOPOLOGY=classic`, materialized hosted and panel flags `false`, `CHAT_BACKEND=orchestrator` | UI routes chat to the orchestrator Container App. Classic history and panel data remain available. |
| Explicit migration to hosted/no-panel | `DEPLOYMENT_TOPOLOGY=hosted-no-panel`, delegated hosted scope configured, panel `false` | Runs the two-phase hosted lifecycle below, then validates the hosted request path before the classic chat path is removed or deactivated. |

Do not select `hosted-panel`. Hosted/panel history, feedback, curation, and
dashboard workflows remain blocked by
[issue #611](https://github.com/Azure/GPT-RAG/issues/611), and
`DEPLOY_ADMINISTRATIVE_PANEL=false` remains required.

The deployment hooks publish the shared runtime contract under the App
Configuration label `gpt-rag`:

| Setting | Operator contract |
| --- | --- |
| `DEPLOYMENT_TOPOLOGY` | Canonical deployment choice: `hosted-no-panel` or `classic`. `hosted-panel` fails closed while #611 is open. |
| `CHAT_BACKEND` | The upcoming UI release treats missing or blank as `hosted_agent`; the umbrella deployment always publishes the resolved sticky value. `orchestrator` is the explicit fallback. Unknown values fail startup. Environment configuration takes precedence over App Configuration. |
| `ORCHESTRATOR_BASE_URL` | Classic service root, used only when `CHAT_BACKEND=orchestrator`. The UI calls the `/orchestrator` route on this endpoint. |
| `HOSTED_AGENT_BASE_URL` | Required HTTPS hosted service root. The pending OQ-OWN UI sends Responses protocol `2.0.0` requests to `POST /responses` when `CHAT_BACKEND=hosted_agent`. The separate `POST /invocations` endpoint retains the legacy messages-based invocation contract but does not satisfy delegated continuity. |
| `HOSTED_AGENT_RESOURCE_SCOPE` | Required explicit non-ARM hosted data-plane Entra scope ending in `/.default`, for example `api://<application-id>/.default`. |
| `HOSTED_AGENT_AUTH_MODE` | `user_delegated` is the default and required continuity path. Under OQ-OWN, it means the trusted UI BFF derives `x-ms-user-identity`; it does not mean an OBO token is sent to the agent. OBO remains a separate retrieval flow. `service_identity` is an explicit reviewed exception that is incompatible with owner-bound continuity, so continuity stays off/503 in that mode. |
| `HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS` | Finite positive wait for the next SSE event. The UI default is `60`; an infinite timeout is rejected. |
| `HOSTED_AGENT_IMAGE_VERSION` | Canonical lowercase immutable digest in `sha256:<64-hex-characters>` form. Mutable tags are rejected. |
| `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` | Generative-AI prompt and completion telemetry capture. Defaults to `false`. Set to `true` only when the deployment's data-handling policy explicitly permits sensitive content telemetry. |

Hosted configuration, authentication, connection, timeout, protocol, and
runtime failures are terminal for startup or the affected request. The UI does
not silently switch to the orchestrator or to managed identity. Foundry passes
opaque `x-agent-foundry-call-id` context to Toolbox; user and delegated bearer
tokens are not copied into tool payloads or client-defined identity headers.

#### Hosted conversation continuity platform gate

!!! danger "Delegated owner binding is pending"
    `HOSTED_CONTINUITY_ENABLED` defaults to `false` and must stay false until the
    OQ-OWN platform pivot and compatible components are published. The
    deployment must prove Responses protocol `2.0.0`, trusted UI BFF identity
    derivation, and the two exact direct agent-scoped roles before recording
    `OWNER_BINDING_VALIDATED=true`. Otherwise compatible history endpoints
    return HTTP 503.

The trusted UI BFF derives `x-ms-user-identity` from the authenticated
server-side principal and sends it on the hosted Responses request. This owner
header is not an OBO token: OBO remains a separate downstream retrieval flow
with its own audience and bearer token.

Activation assigns only the UI BFF:

- built-in **Foundry Agent Consumer**
  (`eed3b665-ab3a-47b6-8f48-c9382fb1dad6`); and
- the exact GPT-RAG custom role containing only the reviewed
  `UserIdentityImpersonation` DataAction.

Both assignments must be direct and scoped to the individual hosted agent.
Broader, inherited, group-derived, wildcard, or extra-DataAction access fails
validation. The hosted runtime is not an identity-header source and receives no
key, Conversation or impersonation RBAC, or Cosmos DB in hosted/no-panel.

| Setting or gate | Required posture |
| --- | --- |
| `HOSTED_CONTINUITY_ENABLED` | `false` until delegated owner binding validates; false/missing validation means history HTTP 503. |
| `OWNER_BINDING_VALIDATED` | Becomes `true` only after the live protocol, identity-source, role-definition, assignment, and scope checks pass. |
| `HOSTED_CONVERSATIONS_TOKEN_AUDIENCE` | Exact Foundry audience `https://ai.azure.com`; distinct from `x-ms-user-identity` and downstream OBO audiences. |
| `HOSTED_HISTORY_MAX_ITEMS` | Default `100`; accepted range 1-1,000. |
| `HOSTED_HISTORY_MAX_TOKENS` | Default `32000`; accepted range 1-1,000,000. |
| `HOSTED_HISTORY_TRUNCATION` | Must be `drop_oldest`. |

Capability/HMAC is a disabled fallback only. The delegated primary path does
not create a capability key, require
`HOSTED_CONTINUITY_KEY_VAULT_URI`/`HOSTED_CONTINUITY_KEY_VAULT_NAME`, publish
`HOSTED_CONVERSATION_CAPABILITY_KEY`, or grant a capability-secret role.
Fallback key ID, TTL, vault, reference, and retained key-history behavior apply
only if a future release explicitly selects and validates capability mode. See
the
[hosted conversation continuity platform contract](hosted_continuity_platform_contract.md)
for the complete trust and rollout boundary.

`POST /responses` and `POST /invocations` are distinct protocols, not aliases, and their request bodies are not interchangeable. Microsoft Foundry hosts the Responses protocol `2.0.0` route through `azure-ai-agentserver-responses`. It accepts a non-empty string `input`; set `stream` to `true` for an SSE lifecycle or `false` for a synchronous JSON response. `store` accepts `true` or `false`, and `background` enables background execution. The route also supports `previous_response_id`, string-valued `metadata`, and the platform-injected `agent_reference`.

Managed `conversation` accepts either a non-empty id string or an object containing only `{"id": "<non-empty-id>"}`. `conversation` and `previous_response_id` are mutually exclusive to prevent history from crossing conversation boundaries. Invalid conversation identifiers are rejected rather than creating a new thread. List and multimodal input are rejected, as are request fields outside the supported Responses contract.

```json
{
  "input": "What is the document retention policy?",
  "stream": true,
  "store": true,
  "background": false,
  "conversation": {
    "id": "<conversation-id>"
  },
  "metadata": {
    "correlation_id": "<correlation-id>"
  }
}
```

The compatibility `POST /invocations` route retains the legacy messages-based schema:

```json
{
  "messages": [
    {
      "role": "user",
      "content": "What is the document retention policy?"
    }
  ],
  "conversation_id": "<conversation-id>",
  "metadata": {}
}
```

The Responses route returns either SSE or synchronous JSON according to `stream`; the legacy Invocations route streams SSE. Each validates its own protocol-specific input before entering the shared hosted execution path. See the Microsoft Foundry [hosted-agent protocol comparison](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents#key-concepts).

Responses protocol `2.0.0` also owns the stored-response lifecycle:

| Route | Purpose |
| --- | --- |
| `GET /responses/{response_id}` | Retrieve a stored response. Responses created with `store=false` are not available. |
| `GET /responses/{response_id}/input_items` | List the input items recorded for a stored response. |
| `POST /responses/{response_id}/cancel` | Cancel an in-flight background response. |
| `DELETE /responses/{response_id}` | Delete a stored response. |

These storage routes belong to the Responses protocol and do not accept the legacy invocation body. For Toolbox-backed configurations, the hosted identity guard validates `x-agent-foundry-call-id` before create, retrieve, input-item listing, cancellation, or deletion can access the protocol provider. Values containing surrounding whitespace are rejected rather than trimmed, and the provider receives the exact validated value unchanged.

#### Two-phase hosted deployment

For a fresh hosted deployment, configure the delegated data-plane scope before
the first provision:

```powershell
azd env set HOSTED_AGENT_RESOURCE_SCOPE "api://<application-id>/.default"
azd env set HOSTED_AGENT_SSE_IDLE_TIMEOUT_SECONDS 60
# Keep continuity disabled until compatible component pins and owner validation publish.
azd env set HOSTED_CONTINUITY_ENABLED false
azd provision
pwsh scripts/prepareHostedDeployment.ps1
azd provision
azd deploy
```

On POSIX systems, use `scripts/prepareHostedDeployment.sh` for the preparation
step. For an explicit migration, set
`DEPLOYMENT_TOPOLOGY=hosted-no-panel` before the first `azd provision`.

The first provision creates hosted prerequisites with image preparation
enabled but hosted deployment disabled. The preparation command clones and
verifies the manifest-pinned orchestrator source, builds the standard image and
the hosted-entrypoint derivative, resolves the pushed manifest to an immutable
digest, and persists that digest and source provenance. The second provision
materializes the digest-backed hosted handoff; `azd deploy` then deploys the
hosted agent.

Public deployments use shared ACR Tasks. Network-isolated deployments use the
dedicated VNet-connected ACR Tasks agent pool; shared ACR Tasks cannot reach a
private endpoint. Operators may pass an already-built immutable
`sha256:<64-hex-characters>` digest to the preparation command to skip builds.
No lifecycle hook recursively invokes `azd provision`.

#### Explicit fallback after the hosted-default release

Fallback is a deployment operation, not a request-time retry:

```powershell
azd env set DEPLOYMENT_TOPOLOGY classic
azd provision
azd deploy
```

This restores the orchestrator Container App and publishes
`CHAT_BACKEND=orchestrator` without deleting hosted Conversations or existing
classic panel data.

#### Current classic release

GPT-RAG `v3.7.0` remains the latest published umbrella release at the time this
target architecture was documented. Its classic pin set is UI `v2.3.13`,
orchestrator `v3.8.0`, ingestion `v2.5.0`, and AI Landing Zone `v2.3.0`.
Do not combine the upcoming topology contract with those released hooks or
manifests.

### Retrieval backend

GPT-RAG can retrieve grounding content directly from Azure AI Search or through a
Foundry IQ knowledge base. Starting with GPT-RAG v3.0.2 and AI Landing Zone
v2.1.2, new deployments use Foundry IQ by default through a native Azure Blob
Knowledge Source. Existing deployments can stay on `RETRIEVAL_BACKEND=ai_search`
until you explicitly migrate.

Use the [grounding sources overview](howto_grounding_overview.md) to
understand the default Foundry IQ path, when to keep using Azure AI Search, and
when to use the `searchIndex` pattern for custom GPT-RAG ingestion pipelines.

The most important settings are:

| Setting | Typical value | Purpose |
| --- | --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` for new deployments, `ai_search` for existing compatibility or rollback | Selects the retrieval path. |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` by default, or `searchIndex` for custom GPT-RAG ingestion | Selects the Foundry IQ setup choice. |
| `KNOWLEDGE_BASE_NAME` | `<env>-knowledge-base` | Foundry IQ knowledge base name. |
| `KNOWLEDGE_BASE_CONNECTION_ID` | Generated by AILZ | Dedicated Foundry connection for knowledge-base use. |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | Required for per-user permissions and custom ingestion path `filterAddOn`. |
| `FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN` | `free` or `standard` | Controls Azure AI Search agentic retrieval billing. |

With the default Blob path, Foundry IQ processes files directly from the
`documents` container. GPT-RAG ingestion is not used in that path. Use
`FOUNDRY_IQ_PATTERN=searchIndex` only when you intentionally keep a custom
GPT-RAG ingestion pipeline that writes chunks to Azure AI Search.

Two optional Foundry IQ Knowledge Sources can run alongside the documents
source on the same Knowledge Base. Both are off by default and require
signed-in users:

- [Foundry IQ: Work IQ (Microsoft 365)](howto_grounding_work_iq.md) blends
  in mail, meetings, files, chats, and people from the signed-in user's
  M365 world. Gated public preview.
- [Foundry IQ: Fabric ontology (Microsoft Fabric)](howto_grounding_fabric_ontology.md)
- [Foundry IQ: Fabric Data Agent (Microsoft Fabric)](howto_grounding_fabric_data_agent.md)
  blends in analytical data from a Fabric ontology (semantic model,
  lakehouse, warehouse, KQL). Preview. Review data-egress caveats before
  enabling.

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/nZMDtaDQuP4?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="GPT-RAG Tutorial" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

## Zero Trust Deployment

For deployments that **require network isolation**.

Network-isolated deployments use a two-host flow:

| Phase | Where to run | Command |
| --- | --- | --- |
| Provision infrastructure | Workstation | `azd provision` |
| Configure data-plane resources | Jumpbox or VNet-connected host | `scripts/postProvision.ps1` |
| Deploy services | Jumpbox or VNet-connected host | `azd deploy` |

Do not run `azd deploy` from the workstation when `NETWORK_ISOLATION=true`. The deploy hook blocks that path because private resources and the private ACR build pool are reachable only from inside the VNet.

### Network Isolation runbook

Use this runbook for a clean network-isolated deployment:

1. On your workstation, create or select the azd environment and enable network isolation.
2. Still on your workstation, run `azd provision`. This creates the infrastructure and then stops before local data-plane configuration.
3. Connect to the jumpbox through Azure Bastion, or use another machine with VNet/VPN access.
4. On the jumpbox, authenticate with the VM managed identity.
5. On the jumpbox, run `scripts/postProvision.ps1` with `RUN_FROM_JUMPBOX=true`.
6. On the jumpbox, run `azd deploy` with `RUN_FROM_JUMPBOX=true`. To build the UI, orchestrator, ingestion, and hosted-agent derivative images with the dedicated VNet-connected ACR Tasks agent pool, set `ACR_TASK_AGENT_POOL=build-pool`.

`BUILD_MODE` is normally not required when deploying the UI, orchestrator, or ingestion services. The hosted-agent derivative image can use the same dedicated pool. Shared ACR Tasks cannot reach a private endpoint.

### Regional preflight

Run preflight before every Zero Trust deployment. It is much faster to fail in
the first few minutes than to wait for a long network-isolated deployment and
then discover that a regional dependency cannot be created.

`azd provision` runs the `scripts/preProvision` hook. The hook invokes
`scripts/Invoke-RegionalPreflight.ps1` before the Azure Resource Manager
deployment starts.

Preflight checks include:

- the selected Azure region and provider support,
- common regional readiness checks for Azure AI Search, Cosmos DB, Container
  Apps, AI Foundry, and Cognitive Services,
- jumpbox VM SKU availability and restrictions,
- Azure OpenAI model quota for the configured deployments.

Preflight is an early warning, not a live capacity reservation. Azure capacity
can still change after the check passes, and some regional capacity errors are
only returned when Azure creates the resource. Recent examples include Azure AI
Search Standard capacity in Sweden Central and Cosmos DB zonal capacity in West
Europe.

Use the result this way:

| Result | Operator action |
| --- | --- |
| `FAIL` | Stop. Fix the subscription, quota, region, or parameter issue before provisioning. |
| `WARN` | Review the warning before continuing. If it mentions capacity or regional risk, consider changing region first. |
| Pass | Continue, but keep the deployment logs open because live capacity can still change. |

If a region fails or warns on a critical dependency, try another fully supported
region instead of waiting 30 minutes or more for a deployment that is likely to
fail. Use `GPT_RAG_REGIONAL_PREFLIGHT_SKIP=true` only when you intentionally
bypass regional checks, or `PREFLIGHT_SKIP=true` to bypass all preflight hooks.

**Before Provisioning**

Enable network isolation in your environment:

```
azd env set NETWORK_ISOLATION true
```

Optional v2 parameters can be set before provisioning:

```shell
azd env set DEPLOYMENT_MODE standalone
azd env set VM_SIZE Standard_D2s_v3
azd env set ENABLE_COSMOS_ANALYTICAL_STORAGE false
```

`ALLOWED_IP_RANGES` is also available for CIDR allow-listing, but because it is an array parameter, prefer editing `main.parameters.json` or using a parameter overlay rather than storing a complex array in the azd environment.

Make sure you’re signed in with your Azure user account:

```

az login
azd auth login

```

> Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

**Provision Infrastructure**

```
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING true   # optional for automation; skips the local post-provision prompt
azd provision
```

**Post-Provision Configuration**

With `NETWORK_ISOLATION=true`, data-plane configuration must run from inside the VNet. A workstation should only run `azd provision`; if it does not have VNet/VPN access, the local post-provision hook will skip data-plane work and tell you to continue from the jumpbox.

Using the Jumpbox VM

1) **Reset the VM password** in the Azure Portal (required on first access if not set in deployment parameters):

- Go to your VM resource → **Support + troubleshooting** → **Reset password** → Set new credentials
- Default username is `testvmuser`

2) **Connect via Azure Bastion**

3) **Authenticate with the VM's Managed Identity:**

   ```powershell
   az login --identity
   azd auth login --managed-identity
   ```

   > Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

4) **Run the post-provision script:**

   PowerShell:
   ```powershell
   cd C:\github\GPT-RAG
   azd env set RUN_FROM_JUMPBOX true
   .\scripts\postProvision.ps1
   ```

   Bash:
   ```bash
   cd /mnt/c/github/gpt-rag
   ./scripts/postProvision.sh
   ```

> **Note:** If you have re-initialized or cloned the gpt-rag repo again, refresh your `azd` environment before running the postProvision script so it points to the **existing** deployment:
> `azd init -t azure/gpt-rag` then `azd env refresh`. When prompted, select the **same Subscription, Resource Group, and Location** as the original provisioning so `azd` correctly links to your environment.

## Existing Platform / AI Landing Zone Integrated

Use these settings when GPT-RAG must deploy into an existing enterprise platform, such as a hub-spoke network with centrally managed Private DNS Zones, Log Analytics, Application Insights, Bastion, NAT Gateway, or Azure Firewall.

**Core mode:** set `DEPLOYMENT_MODE` to `ailz-integrated`, then pass the existing resource IDs that your platform team owns. The default remains `standalone`, so basic deployments do not require these settings.

```powershell
azd env set DEPLOYMENT_MODE ailz-integrated
azd env set USE_EXISTING_VNET true
azd env set EXISTING_VNET_RESOURCE_ID "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>"
```

**Existing Private DNS Zones:** set the zone resource IDs for services already managed by the platform. Common values include `EXISTING_PRIVATE_DNS_ZONE_OPENAI_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_AISERVICES_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_SEARCH_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_COSMOS_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_BLOB_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_KEYVAULT_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_APPCONFIG_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_CONTAINERAPPS_RESOURCE_ID`, `EXISTING_PRIVATE_DNS_ZONE_ACR_RESOURCE_ID`, and Azure Monitor / App Insights zone IDs.

```powershell
azd env set EXISTING_PRIVATE_DNS_ZONE_SEARCH_RESOURCE_ID "/subscriptions/<sub>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"
azd env set EXISTING_PRIVATE_DNS_ZONE_OPENAI_RESOURCE_ID "/subscriptions/<sub>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
azd env set DNS_ZONE_LINK_SUFFIX "<unique-spoke-name>"
```

**Shared platform resources:** set `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID`, `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID`, `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING`, `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID`, `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP`, or `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID` when those resources are centrally managed.

**Spoke resource switches:** use `DEPLOY_JUMPBOX`, `DEPLOY_BASTION`, `DEPLOY_NAT_GATEWAY`, `EXISTING_JUMPBOX_RESOURCE_ID`, `EXISTING_BASTION_RESOURCE_ID`, `EXISTING_NAT_GATEWAY_RESOURCE_ID`, `DEPLOY_AZURE_FIREWALL`, and `DEPLOY_ACR_TASK_AGENT_POOL` to align GPT-RAG with the platform topology. These are optional and preserve the default standalone behavior when unset.

## Deploy GPT-RAG Services

> **Note:** For Zero Trust deployments with network isolation, deploy services from the jumpbox or another host with VNet connectivity. If using the jumpbox VM, the repositories are located in the `C:\github` directory.

Once the GPT-RAG infrastructure is provisioned, you can deploy the services.

To deploy **all services at once**, navigate to the `gpt-rag` directory (with azd environment configured) and run:

```powershell
cd C:\github\GPT-RAG
azd env set RUN_FROM_JUMPBOX true
azd env set NETWORK_ISOLATION true
azd env set ACR_TASK_AGENT_POOL build-pool
azd deploy
```

This command deploys the services selected by the active mode. The UI, orchestrator, ingestion, and hosted-agent derivative images can use Azure Container Registry remote builds (`az acr build`) against the dedicated VNet-connected ACR Tasks agent pool provided by AILZ `v2.4.1`. Shared ACR Tasks cannot reach a private endpoint.

The deploy hook uses `NETWORK_ISOLATION` as the source of truth. When `NETWORK_ISOLATION=true`, `azd deploy` fails fast unless it is running from the VNet with `RUN_FROM_JUMPBOX=true`. The older `AZURE_ZERO_TRUST` variable is not used.

If you prefer to **deploy a single service**, for example, when updating only that service, you can deploy it individually. Below is an example using the orchestrator service. The same approach applies to other services (frontend, dataingest, mcp).

### Deploy Individual Services

Make sure you're logged in to Azure:

```bash
az login
```

**Example: Deploying the Orchestrator**

**Using azd (recommended):**

Initialize the template:
```shell
azd init -t azure/gpt-rag-orchestrator 
```

> **Important:** Use the **same environment name** with `azd init` as in the infrastructure deployment to keep components consistent.

Update environment variables then deploy:
```shell
azd env refresh
azd deploy 
```

> **Important:** Run `azd env refresh` with the **same subscription** and **resource group** used in the infrastructure deployment.

**Using a shell script:**

Clone the repository, set the App Configuration endpoint, and run the deployment script.

PowerShell (Windows):
```powershell
git clone https://github.com/Azure/gpt-rag-orchestrator.git
$env:APP_CONFIG_ENDPOINT = "https://<your-app-config-name>.azconfig.io"
cd gpt-rag-orchestrator
.\scripts\deploy.ps1
```

Bash (Linux/macOS):
```bash
git clone https://github.com/Azure/gpt-rag-orchestrator.git
export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
cd gpt-rag-orchestrator
./scripts/deploy.sh
```

## Permissions

The role tables below describe the currently released classic Container Apps
topology. The merged but unreleased hosted/no-panel implementation omits the
orchestrator Container App assignments and adds Foundry data-plane,
delegated-user, Toolbox, and immutable-image pull assignments. Component and AI
Landing Zone tags, final umbrella pins, integrated validation, and the GPT-RAG
release remain outstanding. Hosted/panel remains unsupported and is tracked by
[issue #611](https://github.com/Azure/GPT-RAG/issues/611).

**Microsoft Foundry Role and AI Search Assignments**

| Resource                  | Role                       | Assignee           | Description                                |
| ------------------------- | -------------------------- | ------------------ | ------------------------------------------ |
| GenAI App Search Service  | Search Index Data Reader   | Microsoft Foundry Project | Read index data                            |
| GenAI App Search Service  | Search Service Contributor | Microsoft Foundry Project | Create AI Search connection                |
| GenAI App Storage Account | Storage Blob Data Reader   | Microsoft Foundry Project | Read blob data                             |
| Microsoft Foundry Account        | Cognitive Services User    | Search Service     | Allow Search Service to access vectorizers |

**Container App Role Assignments**

| Resource                      | Role                                | Assignee                   | Description               |
| ----------------------------- | ----------------------------------- | -------------------------- | ------------------------- |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: orchestrator | Read configuration data   |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: frontend     | Read configuration data   |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: dataingest   | Read configuration data   |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: mcp          | Read configuration data   |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: orchestrator | Pull container images     |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: frontend     | Pull container images     |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: dataingest   | Pull container images     |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: mcp          | Pull container images     |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: orchestrator | Read secrets              |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: frontend     | Read secrets              |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: dataingest   | Read secrets              |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: mcp          | Read secrets              |
| GenAI App Search Service      | Search Index Data Reader            | ContainerApp: orchestrator | Read index data           |
| GenAI App Search Service      | Search Index Data Contributor       | ContainerApp: dataingest   | Read/write index data     |
| GenAI App Search Service      | Search Index Data Contributor       | ContainerApp: mcp          | Read/write index data     |
| GenAI App Storage Account     | Storage Blob Data Reader            | ContainerApp: orchestrator | Read blob data            |
| GenAI App Storage Account     | Storage Blob Data Reader            | ContainerApp: frontend     | Read blob data            |
| GenAI App Storage Account     | Storage Blob Data Contributor       | ContainerApp: dataingest   | Read/write blob data      |
| GenAI App Storage Account     | Storage Blob Data Contributor       | ContainerApp: mcp          | Read/write blob data      |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data |
| Microsoft Foundry Account            | Cognitive Services User             | ContainerApp: orchestrator | Access Cognitive Services |
| Microsoft Foundry Account            | Cognitive Services User             | ContainerApp: dataingest   | Access Cognitive Services |
| Microsoft Foundry Account            | Cognitive Services User             | ContainerApp: mcp          | Access Cognitive Services |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: orchestrator | Use OpenAI APIs           |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: dataingest   | Use OpenAI APIs           |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: mcp          | Use OpenAI APIs           |

**Executor Role Assignments**

| Resource                      | Role                                | Assignee | Description                              |
| ----------------------------- | ----------------------------------- | -------- | ---------------------------------------- |
| GenAI App Configuration Store | App Configuration Data Owner        | Executor | Full control over configuration settings |
| GenAI App Container Registry  | AcrPush                             | Executor | Push container images                    |
| GenAI App Container Registry  | AcrPull                             | Executor | Pull container images                    |
| GenAI App Key Vault           | Key Vault Contributor               | Executor | Manage Key Vault settings                |
| GenAI App Key Vault           | Key Vault Secrets Officer           | Executor | Create Key Vault secrets                 |
| GenAI App Search Service      | Search Service Contributor          | Executor | Create/update search service elements    |
| GenAI App Search Service      | Search Index Data Contributor       | Executor | Read/write search index data             |
| GenAI App Search Service      | Search Index Data Reader            | Executor | Read index data                          |
| GenAI App Storage Account     | Storage Blob Data Contributor       | Executor | Read/write blob data                     |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor | Executor | Read/write Cosmos DB data                |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | Executor | Use OpenAI APIs                          |

**Jumpbox VM Role Assignments**

| Resource                      | Role                                                       | Assignee   | Description                                |
| ----------------------------- | ---------------------------------------------------------- | ---------- | ------------------------------------------ |
| GenAI App Container Apps      | Container Apps Contributor                                 | Jumpbox VM | Full control over Container Apps           |
| Azure Managed Identity        | Managed Identity Operator                                  | Jumpbox VM | Assign and manage user-assigned identities |
| GenAI App Container Registry  | Container Registry Repository Writer                       | Jumpbox VM | Write to ACR repositories                  |
| GenAI App Container Registry  | Container Registry Tasks Contributor                       | Jumpbox VM | Manage ACR tasks                           |
| GenAI App Container Registry  | Container Registry Data Access Configuration Administrator | Jumpbox VM | Manage ACR data access configuration       |
| GenAI App Container Registry  | AcrPush                                                    | Jumpbox VM | Push container images                      |
| GenAI App Configuration Store | App Configuration Data Owner                               | Jumpbox VM | Full control over configuration settings   |
| GenAI App Key Vault           | Key Vault Contributor                                      | Jumpbox VM | Manage Key Vault settings                  |
| GenAI App Key Vault           | Key Vault Secrets Officer                                  | Jumpbox VM | Create Key Vault secrets                   |
| GenAI App Search Service      | Search Service Contributor                                 | Jumpbox VM | Create/update search service elements      |
| GenAI App Search Service      | Search Index Data Contributor                              | Jumpbox VM | Read/write search index data               |
| GenAI App Storage Account     | Storage Blob Data Contributor                              | Jumpbox VM | Read/write blob data                       |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor                        | Jumpbox VM | Read/write Cosmos DB data                  |
| Microsoft Foundry Account            | Cognitive Services Contributor                             | Jumpbox VM | Manage Cognitive Services resources        |
| Microsoft Foundry Account            | Cognitive Services OpenAI User                             | Jumpbox VM | Use OpenAI APIs                            |
