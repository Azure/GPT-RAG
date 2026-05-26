# Changelog

All notable changes to this project will be documented in this file.  
This format follows [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [v2.7.3] - 2026-05-25

### Changed
- **Bumped component releases for Docker-free deploy reliability**: `gpt-rag-ui` to [v2.3.4](https://github.com/Azure/gpt-rag-ui/releases/tag/v2.3.4), `gpt-rag-orchestrator` to [v2.6.5](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.6.5), and `gpt-rag-ingestion` to [v2.3.5](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.3.5).

### Fixed
- **Component deploy no longer requires local Docker Desktop**: service deploy scripts now select ACR remote builds before probing Docker, support explicit `BUILD_MODE=acr-task`/`USE_DOCKER=false`, configure Container App registry identity, and restart the latest revision after image updates. Fixes [Azure/GPT-RAG#449](https://github.com/Azure/GPT-RAG/issues/449).

## [v2.7.2] - 2026-05-25

### Changed
- **Bumped `gpt-rag-orchestrator` to [v2.6.4](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.6.4)** to consume the Agent Service startup warmup fix for default basic deployments.

### Fixed
- **Default `maf_lite` startup no longer creates Agent Service agents**: the orchestrator startup warmup is now strategy-aware, skips Agent Service entirely for the default `maf_lite` strategy, limits reusable startup agent creation to `single_agent_rag`, and reuses any existing `gpt-rag-agent-v2` by name before creating one. Fixes [Azure/GPT-RAG#456](https://github.com/Azure/GPT-RAG/issues/456).

## [v2.7.1] - 2026-05-25

### Changed
- **Bumped `gpt-rag-ui` to [v2.3.3](https://github.com/Azure/gpt-rag-ui/releases/tag/v2.3.3)** to pick up the WSL/Linux Bash script line-ending fix for component deployment.

### Fixed
- **WSL/Linux UI component deploy failure**: `gpt-rag-ui` now ships repository line-ending attributes that keep `scripts/deploy.sh` and `scripts/preProvision.sh` checked out with LF endings, preventing `$'\r': command not found` and `set: pipefail` failures during `azd deploy`. Fixes [Azure/GPT-RAG#451](https://github.com/Azure/GPT-RAG/issues/451).

## [v2.7.0] - 2026-05-19

> v2.7.0 bumps the **AI Landing Zone** Bicep module submodule from **v1.0.7 → v2.0.2**. This is a major-version submodule upgrade that brings several new capabilities (IP allow-lists, BYO Private DNS zones, BYO Log Analytics + App Insights, hub-and-spoke composability, deployment-mode preset, pre-flight validation hook) and a handful of bug fixes (most notably the `${VAR=null}` string-default bug that affected route-table wiring, the hardcoded service-flag defaults that ignored `azd env set` overrides, and two v2.0.0-only template-validation regressions in the AI Foundry account Private Endpoint emission and the AI Foundry-bundled sub-modules' PE subnet propagation — fixed in v2.0.1 and v2.0.2 respectively). Default behavior is **unchanged** for existing GPT-RAG operators — all new landing-zone capabilities are opt-in. See the [v2-migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.0/docs/v2-migration.md) and the [parameterization reference](https://azure.github.io/AI-Landing-Zones/bicep/parameterization) for details.

### Changed
- **AI Landing Zone Bicep submodule bumped to [v2.0.2](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.2) plus the merged ACR Tasks egress hotfix [PR #69](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/69)** (`ailz_tag` in `manifest.json` remains `v2.0.2` for the jumpbox bootstrap script URL). v2.0.2 is a hotfix on top of v2.0.0 that resolves two ARM template-validation errors encountered while validating this very release: (a) a duplicate-name in the AI Foundry account Private Endpoint emission (v2.0.1, [PR #60](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/60)), and (b) an unconditional `varPeSubnetId` propagation that caused the AI Foundry-bundled Cosmos DB, Key Vault, AI Search, and Storage Account modules to emit invalid private endpoint iterators under `_networkIsolation=false` (v2.0.2, [issue #63](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/63) / [PR #64](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/64)). PR #69 adds `packages.microsoft.com` to the network-isolated ACR Task build allow-list and adds `additionalAcrTaskBuildFqdns` for future solution-specific build dependencies. No GPT-RAG-component bumps in this release (`gpt-rag-ui` v2.3.2, `gpt-rag-orchestrator` v2.6.3, `gpt-rag-ingestion` v2.3.4 carry over from v2.6.7).
- **`scripts/preProvision.{ps1,sh}` now fail fast on GPT-RAG regional readiness before ARM deployment starts.** The new GPT-RAG preflight validates the selected region, jumpbox VM SKU restrictions, provider/location support for AI Search, Cosmos DB, Container Apps, and AI Foundry/Cognitive Services, plus Azure OpenAI model quota for the exact deployments in `modelDeploymentList`. If model quota is insufficient, it suggests candidate regions when possible. It is intentionally explicit that transient service-capacity failures (for example Cosmos DB high-demand `ServiceUnavailable`) are not exposed by a reliable pre-create quota API. Bypass only these checks with `GPT_RAG_REGIONAL_PREFLIGHT_SKIP=true`; bypass all preflight hooks with `PREFLIGHT_SKIP=true`.
- **`scripts/preProvision.{ps1,sh}` continue to invoke the landing-zone preflight check** (`infra/scripts/Invoke-PreflightChecks.ps1`). This catches parameter-contradiction errors (BYO ID mismatches, malformed CIDR entries, subnet prefixes outside the VNet, mutually-exclusive hub-integration flags, etc.) *before* `azd provision` reaches Azure Resource Manager. Bypass with `PREFLIGHT_SKIP=true` (CI/offline). The shell version now fails clearly if `pwsh` is missing for the GPT-RAG regional preflight instead of silently skipping regional checks.
- **`scripts/preDeploy.{ps1,sh}` now key Network Isolation behavior only from `NETWORK_ISOLATION`**. Workstation runs should stop after `azd provision`; when `NETWORK_ISOLATION=true`, `azd deploy` must be run from the jumpbox/VNet with `RUN_FROM_JUMPBOX=true`, and the legacy `AZURE_ZERO_TRUST` deploy prompt is no longer used.
- **`scripts/postProvision.{ps1,sh}` now honor `AZURE_SKIP_NETWORK_ISOLATION_WARNING=true` for automated network-isolated workstation provisions.** The local hook skips data-plane work without prompting, while the real data-plane setup still requires rerunning from the jumpbox/VNet with `RUN_FROM_JUMPBOX=true`.

### Added
- **`main.parameters.json` surfaces three v2.0.0 parameters as substitutable env vars** so operators can opt into them via `azd env set`:
  - `allowedIpRanges` (default `[]`) — array of CIDRs uniformly applied as an IP allow-list on Storage, Key Vault, App Configuration, Container Registry, Cosmos DB, AI Search, and the AI Foundry storage account. Works orthogonally to `networkIsolation`. **Note**: `azd` env substitution emits strings, so this parameter accepts an array literal — edit `main.parameters.json` directly to seed it, or use a parameter overlay file.
  - `deploymentMode` (default `standalone`) — `'standalone'` or `'ailz-integrated'`. Advisory in v2.0.0 (surfaced as a deployment tag `deploymentMode=<value>`); future v2.x releases may use it to drive defaults. `azd env set DEPLOYMENT_MODE ailz-integrated` switches it.
  - `enableCosmosAnalyticalStorage` (default `false`) — surfaced explicitly because Azure does not permit toggling this flag on an existing Cosmos DB account (it only takes effect at account creation), and several region / subscription combinations refuse the `true` setting at provision time. Default `false` matches the typical GPT-RAG topology (no Synapse Link / Fabric Mirroring consumer). Toggle via `azd env set ENABLE_COSMOS_ANALYTICAL_STORAGE true` *before* the first `azd provision`.
- **`vmSize` is now env-substitutable** in `main.parameters.json`: `${VM_SIZE=Standard_D2s_v3}`. Default lowered from the previously-hardcoded `Standard_D8s_v5` (8 vCPU / 32 GiB) to `Standard_D2s_v3` (2 vCPU / 8 GiB) for the jumpbox VM. The smaller D2s_v3 SKU is broadly available across Azure regions (the v5 D-family is restricted in several regions including `eastus2`), and the 2 vCPU / 8 GiB sizing is more than sufficient for the jumpbox admin/bootstrap role. Operators with heavier use cases can override with `azd env set VM_SIZE Standard_D8s_v5` (or any other size) before `azd provision`.

### Fixed (via the submodule upgrade)
- **`${VAR=null}` literal-string bug for nullable-string parameters** (landing-zone fix): `azd` passed the literal string `"null"` into `string?` parameters when the env var was unset, which broke every `!empty(...)` guard downstream. Symptom: subnet deployments failed with `LinkedInvalidPropertyId: Property id 'null' at path 'properties.routeTable.id' is invalid`. v2.0.0 changed `${VAR=null}` → `${VAR=}` (empty-string default) for every nullable-string parameter, so route-table wiring, BYO existing IDs, and the App Insights connection string now correctly evaluate as empty.
- **Hardcoded service flags now respect `azd env set`** (landing-zone fix): `deploySearchService`, `deployStorageAccount`, `deployKeyVault`, `deployLogAnalytics`, `deployMcp`, `deployGroundingWithBing`, `deploySoftware`, `deployPostgres`, `greenFieldDeployment`, and `speechServiceSku` are no longer pinned at compile time in the landing-zone parameter file. v2.0.0 switched them to `${ENV=default}` substitution so `azd env set DEPLOY_SEARCH_SERVICE false` (and similar) actually take effect. The umbrella's parameter file passes them through.
- **Cosmos `enableAnalyticalStorage=true` provisioning failures**: the landing-zone now defaults `enableAnalyticalStorage` to `false` and gates it on the new `enableCosmosAnalyticalStorage` parameter. v2.6.x deployments occasionally failed with role-assignment / region-permission errors when this was implicitly enabled — those failures stop in v2.7.0.
- **Jumpbox `SkuNotAvailable` failures in regions without v5 D-family** (umbrella-level fix, see `vmSize` entry under **Added**): `Standard_D8s_v5` was hardcoded in the umbrella `main.parameters.json` since the project's inception; in regions where Azure restricts the `Dsv5` family (notably `eastus2` as of release time), `azd provision` aborted at the AI Search service's internal VM-SKU preflight check with `SkuNotAvailable`. The new env-substitutable default (`Standard_D2s_v3`) provisions reliably across all GPT-RAG-supported regions.
- **PowerShell hooks on Windows jumpbox**: `scripts/preDeploy.ps1` and `scripts/postProvision.ps1` are now stored with a UTF-8 BOM so Windows PowerShell 5.1 reads the existing Unicode status messages correctly instead of parsing corrupted script text. `postProvision.ps1` also suppresses the Azure CLI dynamic-install warning without aborting when `$ErrorActionPreference='Stop'`.

### Opt-in landing-zone v2.0.0 features (not surfaced as umbrella env vars, but reachable via `azd env set <PARAM_NAME>` or by editing the umbrella `main.parameters.json` directly)
- 15 `existingPrivateDnsZone<Service>ResourceId` parameters for BYO Private DNS zones (ALZ-integrated hub-spoke topologies).
- `existingLogAnalyticsWorkspaceResourceId`, `existingApplicationInsightsResourceId`, `existingApplicationInsightsConnectionString` for observability reuse against a hub-managed workspace.
- `hubIntegrationHubVnetResourceId`, `hubIntegrationEgressNextHopIp`, `hubIntegrationExistingRouteTableResourceId`, `hubIntegrationCreateHubPeering`, `hubIntegrationPeeringAllowGatewayTransit`, `hubIntegrationPeeringUseRemoteGateways` for hub-and-spoke composability.
- `deployJumpbox`, `deployBastion`, `deployNatGateway` + matching `existing*ResourceId` BYO variants. The legacy `deployVM` parameter remains as a **deprecated** umbrella that gates all three when left unset — existing GPT-RAG deployments continue to work unchanged.
- `dnsZoneLinkSuffix` for unique VNet-link names when multiple spokes share the same hub DNS zones.

### Validation
End-to-end validation in `swedencentral` (subscription `mcaps-paulolacerda`), basic deployment (`NETWORK_ISOLATION=false`, `deploymentMode=standalone`):

| Aspect | Result |
| --- | --- |
| Preflight hook (`Invoke-PreflightChecks.ps1`) executes from `preProvision.{ps1,sh}` | ✅ |
| `azd provision` succeeds (~9m) | ✅ |
| All infra resources provisioned (VNet, Cosmos, Key Vault, ACR, AI Search, AI Foundry, Container Apps Environment, Container Apps) | ✅ |
| `azd deploy` succeeds (~14m, 3 container apps Running) | ✅ |
| Frontend smoke test (HTTP 200) | ✅ |
| New params (`allowedIpRanges`, `deploymentMode`, `enableCosmosAnalyticalStorage`) honored | ✅ |
| Backward compatibility — existing `azure.env` deploys with no changes | ✅ |

Network-isolated deployment (`NETWORK_ISOLATION=true`) reuses the same Bicep submodule and AILZ v2.0.2 fixes; operators with existing isolated deployments can upgrade in place. Hub-and-spoke topology (a separate v2.0.0 capability) is **not** exercised by this release — operators integrating with an existing ALZ hub should follow the [hub-spoke runbook](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.0/docs/runbook-hub-spoke.md).

## [v2.6.7] - 2026-05-19
### Added
- **Per-conversation file upload from the chat UI** ([#401](https://github.com/Azure/GPT-RAG/issues/401)): Users can now upload files directly through the GPT-RAG chat interface. Uploaded documents are persisted to the conversation-documents storage container (declared in v2.6.0) under conversations/<conversationId>/<recordId>/<filename>, chunked and indexed in Azure AI Search tagged with the per-chunk conversationId field (also declared in v2.6.0), and retrieved by the orchestrator with a conversationId eq '<cid>' or conversationId eq 'NaN' filter so retrieval mixes conversation-private documents with shared/global documents. Implemented across three coordinated component PRs:
  - gpt-rag-ingestion [v2.3.4](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.3.4) ([#183](https://github.com/Azure/gpt-rag-ingestion/pull/183)): new POST /ingest-documents endpoint that authenticates via DATA_INGEST_APP_APIKEY, persists the original bytes, and indexes the chunks with camelCase conversationId.
  - gpt-rag-orchestrator [v2.6.3](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.6.3) ([#188](https://github.com/Azure/gpt-rag-orchestrator/pull/188)): conversation-scoped retrieval filter across all strategies.
  - gpt-rag-ui [v2.3.2](https://github.com/Azure/gpt-rag-ui/releases/tag/v2.3.2) ([#51](https://github.com/Azure/gpt-rag-ui/pull/51)): Chainlit spontaneous_file_upload paperclip wired to the new ingestion endpoint, surfaced only when authentication is configured.

### Changed
- Bumped gpt-rag-ui to 2.3.2.
- Bumped gpt-rag-orchestrator to 2.6.3.
- Bumped gpt-rag-ingestion to 2.3.4.

## [v2.6.6] - 2026-04-20
### Added
- **Multimodal figure/image extraction for Content Understanding** ([Azure/GPT-RAG#446](https://github.com/Azure/GPT-RAG/issues/446)): When using Content Understanding as the document analysis backend (USE_DOCUMENT_INTELLIGENCE=false), the multimodal chunker now extracts figures from documents, uploads them to the documents-images blob container, generates captions using a vision-capable model, and populates 
elatedImages, imageCaptions, and captionVector fields in the search index ΓÇö achieving full multimodal parity with the Document Intelligence path. Supports PDF (PyMuPDF page rendering with bounding-box crop), DOCX (word/media/ ZIP extraction), and PPTX (ppt/media/ ZIP extraction). The ContentUnderstandingClient now parses and returns figure and page metadata from the API response instead of discarding it. New dependencies: PyMuPDF, python-docx, python-pptx.

### Changed
- Bumped gpt-rag-ingestion to 2.3.3.

### Tested Service Versions

| Component | Version |
|---|---|
| gpt-rag-ui | v2.3.1 |
| gpt-rag-orchestrator | v2.6.2 |
| gpt-rag-ingestion | v2.3.3 |
| infra (landing zone) | v1.0.7 |

## [v2.6.5] - 2026-04-18
### Fixed
- **OpenTelemetry version pinning** (orchestrator): Pinned `azure-monitor-opentelemetry==1.8.7`, `azure-monitor-opentelemetry-exporter==1.0.0b49`, `opentelemetry-instrumentation-httpx==0.61b0`, and `opentelemetry-instrumentation-fastapi==0.61b0` in `requirements.txt`. Unpinned versions caused non-deterministic Docker builds where an older exporter (referencing the removed `LogData` class) could be paired with `opentelemetry-sdk>=1.39.0`, crashing the container on startup with `ImportError: cannot import name 'LogData' from 'opentelemetry.sdk._logs'`. ([#445](https://github.com/Azure/GPT-RAG/issues/445))
- **Permission trimming header format** (orchestrator): Removed erroneous `Bearer` prefix from the `x-ms-query-source-authorization` header value in both the REST API path (`search.py`) and the SDK path (`search_context_provider.py`). Azure AI Search expects the raw OBO token without the prefix; including it caused `400 Invalid header` errors when `permissionFilterOption` was enabled on the search index. ([#447](https://github.com/Azure/GPT-RAG/issues/447))

### Changed
- Bumped `gpt-rag-orchestrator` to `v2.6.2`.

## [v2.6.4] - 2026-04-14
### Fixed
- Restored missing `parent_id` field in the RAG search index template (`config/search/search.j2`), which was accidentally removed during the v2.6.0 merge. This caused `gpt-rag-ingestion` blob storage and SharePoint indexers to fail with `Could not find a property named 'parent_id'` errors.

### Changed
- Updated `infra` submodule to [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) tag `v1.0.7`, fixing Log Analytics provisioning failure in Sweden Central caused by `forceCmkForQuery` default.

## [v2.6.3] - 2026-04-08
### Changed
- Updated `infra` submodule to [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) tag `v1.0.6`.
- Parametrized Container App CPU and memory per app entry with fallback defaults (`0.5` CPU / `1.0Gi`).
- Increased `dataingest` Container App resources to `1.0` CPU and `3.0Gi` memory.
- Increased `text-embedding-3-large` deployment capacity from `40` to `100`.
- Bumped `gpt-rag-ingestion` to `v2.3.2`.

## [v2.6.2] - 2026-04-01
### Changed
- Bumped `gpt-rag-orchestrator` to `v2.6.1`.

## [v2.6.1] - 2026-04-01
### Fixed
- Fixed Zero Trust provisioning failure caused by jumpbox Custom Script Extension using incorrect release tag. Replaced `install_script` URL field with `ailz_tag` in `manifest.json`, allowing the install script URL and release parameter to be derived from the landing zone tag.

### Changed
- Updated `infra` submodule to [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) tag `v1.0.5`.
- Bumped `gpt-rag-ui` to `v2.3.1`.
- Bumped `gpt-rag-ingestion` to `v2.2.5`.

## [v2.6.0] - 2026-03-31
### Changed
- Updated `infra` submodule to [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) tag `v1.0.4`.
- Bumped `gpt-rag-ui` to `v2.3.0`.
- Bumped `gpt-rag-orchestrator` to `v2.6.0`.
- Bumped `gpt-rag-ingestion` to `v2.2.4`.
- Added explicit `partitionKey` to all Cosmos DB container definitions, including `/principal_id` for `conversations` container.
- Added `conversation-documents` storage container.
- Added `conversationId` filterable field to search index.
- Removed standalone MCP Container App from default deployment (consolidated into orchestrator).

## [v2.5.3] - 2026-03-24
### Changed
- Updated default chat model from `gpt-5-mini` to `gpt-5-nano` (`2025-08-07`), increased deployment capacity to `100`, and set API version to `2025-12-01-preview`.
- Updated `infra` submodule to [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) tag `v1.0.3`.
- Bumped `gpt-rag-ui` to `v2.2.3`.
- Bumped `gpt-rag-orchestrator` to `v2.5.0`.
### Added
- Added repository development and release instructions (`.github/copilot-instructions.md`).

## [v2.5.2] - 2026-03-16
### Changed
- Updated pre-deployment behavior to skip cloning a component repository when it already exists locally, improving repeat deployment workflows and avoiding unnecessary clone failures. Closes [#428](https://github.com/Azure/GPT-RAG/issues/428).
### Fixed
- Made virtual environment cleanup in `scripts/postProvision.sh` non-fatal so post-provisioning continues even if cleanup cannot complete. Closes [#426](https://github.com/Azure/GPT-RAG/issues/426).

## [v2.5.1] - 2026-03-06
### Changed
- Updated `infra` submodule to external [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) tag `v1.0.1`.
- Bumped `gpt-rag-orchestrator` to `v2.4.2`.
- Bumped `gpt-rag-ui` to `v2.2.2`.
- Improved runtime performance by upgrading the Orchestrator and UI components to `v2.4.2` and `v2.2.2`, respectively.
- Bumped `gpt-rag-ingestion` to `v2.2.3`.

## [v2.5.0] - 2026-03-02
### Changed
- Migrated `infra` folder to external submodule [bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone) pinned to v1.0.0.

## [v2.4.2] - 2026-02-04
### Fixed
- Updated the Docker image to install Microsoft's current public signing key, fixing build failures caused by SHA-1 signature rejection in newer Debian/apt verification policies (orchestrator).
- Fixed Docker builds on ARM-based machines by explicitly setting the target platform to `linux/amd64`, preventing Azure Container Apps deployment failures.
### Changed
- Updated the Docker base image.
- Standardized on the container best practice of using a non-privileged port (`8080`) instead of a privileged port (`80`), reducing the risk of runtime/permission friction and improving stability of long-running ingestion workloads.
- Bumped `aiohttp` to `3.13.3`.

## [v2.4.1] - 2026-01-20
### Changed
- Bumped ingestion component version to include reliability improvements for large spreadsheet ingestion.


## [v2.4.0] - 2026-01-15
### Added
- Document-level security enforcement for GPT-RAG using Azure AI Search native ACL/RBAC trimming with end-user identity propagation via `x-ms-query-source-authorization`.
	Includes permission-aware indexing metadata (userIds/groupIds/rbacScope), safe-by-default behavior for requests without a valid user token, and optional elevated-read debugging support.
### Changed
- Bumped chat model to gpt-5-mini.

## [v2.3.0] – 2025-12-15
### Added
- Support for **SharePoint Lists** in the ingestion component.
- Refactored **Single Agent Strategy** to simplify citation handling. [#161]
- Simplified **MCP Strategy**. [#159]
### Changed
- Improved robustness of **Blob Storage indexing** in the ingestion pipeline.
- Enhanced **data ingestion logging** for better observability and troubleshooting.
### Tested
- Compatibility with **Azure direct models for inference** in the orchestration layer.

## [v2.2.6] – 2025-12-05
### Fixed
- Fixed Issue [#409](https://github.com/Azure/GPT-RAG/issues/409) by updating the main Bicep template to ensure the `SEARCH_CONNECTION_ID` app setting points to the correct AI Search connection ID. It was previously pointing to the AI Foundry AI Search dependency.

## [v2.2.5] – 2025-12-02
### Fixed
- Fixed Issue [#406](https://github.com/Azure/GPT-RAG/issues/406) by updating networking and private endpoint configuration to prevent the `cosmos_vnet_blocked` error in Cosmos DB private-only setups.
### Changed
- Automated the creation and registration of the Azure AI Search connection, removing the need for the previous manual workaround.

## [v2.2.4] – 2025-11-26
### Fixed
- Fixed a bug in data ingestion component where the Blob storage ingestion process was re-indexing unchanged files when AI Search index had more than 1,000 chunks. Fixed in gpt-rag-ingestion v2.0.6.
### Changed
- Small update in `scripts/postProvision.sh` to make the Container Apps API Key check more robust by always converting the `USE_CAPP_API_KEY` variable to lowercase, even when it is unset.


## [v2.2.3] – 2025-11-15
### Fixed
- Intermittent AI Foundry post provisioning setup authentication timeout by increasing `AzureCliCredential` and `ManagedIdentityCredential` process timeout to 30 seconds in `config/aifoundry/setup.py`
- Compatibility with older AZD versions by removing string interpolation syntax from capability host connection arrays in AI Foundry project module (infra/modules/ai-foundry/modules/project/main.bicep lines 229-231)
### Changed
- Suppressed BCP081 warnings for future-dated API versions (2025-01-01, 2025-04-01, 2025-05-01, 2025-06-01) in AI Foundry project module by adding #disable-next-line directives
- Improved PR and Issue templates
- Moved documentation to https://aka.ms/gpt-rag-docs
- Bumped **gpt-rag-mcp** to **v0.2.3**

## [v2.2.2] – 2025-11-09
### Changed
- Updated infra templates to create the **data** private endpoint for Azure Container Registry when in network isolation mode.
- Updated Bastion configuration to retrieve credentials from Key Vault. Users can now simply reset the `testvmuser` password to access the VM for the first time.

## [v2.2.1] – 2025-10-21
### Added
- Added more troubleshooting logs.
### Fixed
- Citations [387](https://github.com/Azure/GPT-RAG/issues/387)

## [v2.2.0] – 2025-10-16
### Added
- Bring your own VNet. [#370](https://github.com/Azure/GPT-RAG/issues/370).
- Agentic Retrieval. [#359](https://github.com/Azure/GPT-RAG/issues/359).

### Fixed
- Citation links opens up new chat windows instead of rendering files [#387](https://github.com/Azure/GPT-RAG/issues/387)
## [v2.1.2] – 2025-10-02
### Changed
- Fixed a bug in data ingestion component where the SharePoint ingestion process was unnecessarily re-indexing unchanged files.

## [v2.1.1] – 2025-09-22
### Changed
- Limit `azd` environment variables to the script process (no longer persisted to the user profile) to reduce secret exposure. Resolves [#378](https://github.com/Azure/GPT-RAG/issues/378).
- Streamline AI Search provisioning: now creates **only** the AI Search index. Previously we also created indexers, skillsets, and data sources that are no longer used and caused confusion about expected runtime behavior. Indexing is performed by the `gpt-rag-ingestion` jobs — see the ingestion docs for how to run, schedule, or troubleshoot ingest jobs. Resolves [#377](https://github.com/Azure/GPT-RAG/issues/377).

## [v2.1.0] – 2025-08-31
### Added
- **User Feedback Loop**. [#358](https://github.com/Azure/GPT-RAG/issues/358). **[Documentation](https://github.com/Azure/GPT-RAG/blob/release/2.1.0/docs/GUIDE.md#configuring-user-feedback-loop)**.

### Changed
- Standardized resource group variable as `AZURE_RESOURCE_GROUP`. [#365](https://github.com/Azure/GPT-RAG/issues/365)

## [v2.0.5] - 2025-08-26
### Fixed
- Resolved VM deployment errors when using CustomScriptExtension under network isolation.

## [v2.0.4] - 2025-08-21
### Added
- Updated orchestrator to version 2.0.3, which includes NL2SQL docs and improved settings checks.

## [v2.0.3] - 2025-08-19
### Fixed
- Resolved issue with using Azure Container Apps under a private endpoint in AI Search as a custom web skill.
### Added 
- Blob Storage Data Source Ingestion.
- NL2SQL Metadata Ingestion from Blob Storage.

## [v2.0.2] - 2025-08-08
### Changed
- Updated deployment documentation.

## [v2.0.1]
### Changed
- Updated deployment documentation.

### Fixed
- Resolved deployment issues introduced in v2.0.0.

## [v2.0.0] - 2025-07-15
### Changed
- Major architecture refactor to support the vNext architecture.
