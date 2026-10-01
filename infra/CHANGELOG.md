# Changelog

All notable changes to this project will be documented in this file.  
This format follows [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [v2.7.3] - 2026-09-26

### Fixed
- Cosmos DB account updates failing with `Continuous backup mode cannot be disabled for an existing database account`. The AVM database-account module omitted locations, consistency, network rules and failover settings when no database was passed in the same call, which the v2.7.x split into `modules/cosmos-db/sql-database.bicep` triggered. The account is now declared in `modules/cosmos-db/database-account.bicep` with the full property set.

## [v2.7.2] - 2026-09-25

### Fixed

- **Container Apps keep their image on re-provision (Azure/GPT-RAG#708).** `containerAppsList[].image` is now honored (with the ACR registry pull identity); the placeholder image is used only when it is empty.

## [v2.7.1] - 2026-09-20

### Fixed

- **Bastion-disabled BYO subnet creation (#168).** Do not attach the generic
  fallback NSG to reserved `AzureBastionSubnet`. This prevents Azure's
  `NetworkSecurityGroupNotCompliantForAzureBastionSubnet` failure when
  `deployBastion=false` and BYO subnet/NSG creation are enabled. Explicit NSGs
  still take precedence, preserving the dedicated NSG when Bastion is enabled.
  Subnet creation, other subnet NSGs, feature flags and public contracts are
  unchanged. Added compiled regression and narrow graph-mutation coverage.

**Migration:** New deployments can retain the default reserved subnet name.
If an environment used a renamed-subnet workaround, do not rename/delete it
or reuse its occupied address prefix automatically. Review the subnet plan
and What-If before reverting that override. The patch does not delete old
subnets or unattached NSGs, enable Bastion, or change existing Bastion rules.

**Validation:** The patched orchestrator successfully created the default-named
`AzureBastionSubnet` without a generic NSG or Bastion host in the isolated Azure
test environment. The sentinel subnet, ACR pool and exact Storage access profile
remained unchanged. The test used a free subnet prefix to avoid the prior
workaround subnet; it did not rename or delete existing subnets.
Live deployment completed on 2026-09-20 at 21:07:03 UTC. The 188-assertion
compiled subnet contract also covers enabled-Bastion NSG precedence; no new
Bastion host was provisioned to validate that enabled path.

## [v2.7.0] - 2026-09-18

This backward-compatible minor release adds explicit solution Storage access
inputs and corrects private ACR build-pool subnet ordering. The release metadata
guard is independent of historical parity comparisons as documented in
[ADR-0006](docs/adr/0006-release-metadata-and-comparison-baselines.md).
Portal/Terraform source-impact findings and follow-up gaps are recorded in
[ADR-0005](docs/adr/0005-reproducible-private-deployments.md).

**Validation boundary:** build, lint, offline contracts, mutation checks and CI
passed. Live Azure cold-start ordering, repeated-deployment ACL persistence,
consumer authentication and Defender scanning were not executed for this
release. No runtime parity or automatic approval for production rollout is
claimed. Operators must use the documented preflight, preview and approved
test-scope procedure before adopting an explicit private/keyless profile.

### Added

- **Reproducible solution Storage access profiles (#160).** Added typed
  `storageAccountNetworkAclsBypass`, `storageAccountResourceAccessRules`, and
  `storageAccountAllowSharedKeyAccess` inputs with native parameter-file values.
  Defaults remain `AzureServices`, `[]`, and `true`, using the existing Storage
  AVM 0.26.2. Explicit rules are desired state; no live exceptions are imported
  and no Defender scanner, plan or role is created. The inputs do not change
  auxiliary Foundry Storage or existing public-network/IP-rule behavior.
- **Terraform parity coordination assets.** The repository now owns a pinned,
  machine-readable parity inventory (`parity/inventory.json`), JSON Schema
  contracts (`parity/schemas/`), structured Terraform handoffs
  (`parity/handoffs/`), an append-only alignment-assessment ledger seed
  (`parity/assessments/`), deterministic PowerShell tooling (`scripts/parity/`),
  fixture-based tests (`tests/parity/`), the generated view
  [`docs/terraform-parity.md`](docs/terraform-parity.md), and ownership and
  operations guidance in
  [`docs/terraform-parity-ownership.md`](docs/terraform-parity-ownership.md).
  The plain-language
  [`docs/terraform-parity-process.md`](docs/terraform-parity-process.md) guide
  explains the complete high-level and detailed workflows, record types, file
  responsibilities, approval points, and security boundaries.
- **Per-merge alignment assessments.** `terraform-parity-assess.yml` records
  exactly one assessment for every pull request merged into `develop`, keyed by
  repository, pull request number, and merge commit SHA. Records are appended to
  the dedicated `terraform-parity-assessments` ledger branch; the workflow never
  writes to `develop` and never executes pull-request head code. A recorded
  outcome and rationale are immutable, and an approved or rejected review is
  terminal apart from supersession; both decisions require a reviewer, an
  absolute `https` decision URL, and a review timestamp.
- **Gated cross-repository publication.** `terraform-parity-publish.yml` runs only
  from a manual dispatch behind the protected `terraform-parity-publication`
  environment, mints an ephemeral GitHub App token scoped to the Terraform
  repository, and sends an identifier-only `repository_dispatch` payload. An
  already recorded proposal is reconciled instead of dispatched twice.
- **Versioned handoff artifact retrieval.** Publication payload version `2.0.0`
  carries a distinct immutable handoff commit, branch, schema path, and normalized
  digest. The producer proves that the trusted checkout contains the exact handoff
  and schema bytes before dispatch; pinned Bicep and Terraform commits remain
  comparison baselines rather than artifact locations.
- **Ledger coverage validation.** `terraform-parity-validate.yml` reads the ledger
  branch when it exists and fails when any `develop` merge after the adoption
  marker lacks exactly one assessment.

### Changed

- **Proposed independent release-metadata guard.** Candidate manifest tags must
  be equal, exact `vMAJOR.MINOR.PATCH` values matching the latest changelog
  section. Historical parity comparison pins, inventory bytes, handoffs,
  assessments and approvals remain unchanged. The Storage graph guard verifies
  the actual compiled manifest, then normalizes only its two release fields
  against the original fingerprint; all other graph protections remain.
  Manifest, changelog and shared guard edits now trigger both validation
  workflows without changing permissions or publication gates.
- Parity validation now also validates the ledger adoption marker, scans
  `parity/` and `tests/parity/fixtures/` for sensitive values with documented
  exclusions, and asserts a 60-second budget for full inventory validation plus
  Markdown generation.
- Parity validation and its workflow tests run entirely from repository content:
  workflow YAML is read by the pinned in-repository reader
  `scripts/parity/Parity.WorkflowYaml.ps1`, so no PowerShell module is installed
  from a package gallery at workflow runtime, and the only installed tooling is
  the lockfile-pinned JSON Schema validator (`npm ci --ignore-scripts`).
- The append-only ledger guard moved out of inline workflow YAML into the tested
  `scripts/parity/Test-LedgerAppendOnly.ps1`, which rejects modification,
  deletion, rename, foreign paths, and any checkout that is not on the ledger
  branch before the assessment workflow commits anything.
- `scripts/parity/Test-AssessmentCoverage.ps1` now fails on a first-parent commit
  after the adoption marker that has no pull request reference, because such a
  commit cannot be assessed; `-AllowUnattributedCommits` is a deliberate opt-out
  for an integration branch that is not yet protected against direct pushes.
- Publication and aggregate validation read ongoing alignment assessments from
  the dedicated ledger checkout rather than the frozen seed on `develop`.
  Ledger discovery distinguishes an absent branch from transport or
  authentication failures, which now fail explicitly.

Compatibility impact of the parity coordination assets: none for deployments;
these assets are repository automation and documentation only. The solution
Storage inputs are an additive public contract with unchanged defaults.
Operators opting out of Shared Key must migrate affected consumers first and
declare every approved resource-instance exception they intend to retain.

Follow-up boundary: merging Terraform proposals, deploying the standard and
network-isolated scenarios in an approved test subscription, and recording
reviewed parity evidence remain owned by
`Azure/terraform-azurerm-avm-ptn-aiml-landing-zone`. No scenario is declared at
parity here.

Rollback: disable the `terraform-parity-*` workflows and revoke the GitHub App
installation or key. Records and the ledger branch are retained and superseded
rather than deleted, and no Azure resource or consumer contract is affected.

### Fixed

- **ACR Task agent-pool BYO subnet ordering (#159).** The pool explicitly waits
  for the conditional BYO subnet deployment, preserving new-VNet dependencies,
  existing-subnet ownership, disabled-pool behavior and unrelated subnet
  configuration. Added focused compiled-template coverage without sleeps or
  public-network workarounds.
- Parity validation refreshes and revalidates its ledger snapshot immediately
  before checking coverage, so assessments appended during the test run are
  observed without suppressing missing-record or transport failures.
- Parity ledger coverage recognizes custom merge subjects such as
  `Merge pull request #161: synchronize main into develop` while still
  requiring an exact pull request number and merge-SHA assessment. Documented
  recovery for a missing assessment ledger branch without bypassing coverage.

## [v2.6.1] - 2026-08-21

### Fixed

- Fixed provisioning for long azd/CAF environment names by replacing resource-name-derived Foundry deployment names and moving Cosmos DB SQL database/container resources out of the account AVM's name-derived nested deployment. All replacement deployment names stay below ARM's 64-character limit while preserving the configured Azure resource names (fixes #119).

## [v2.6.0] - 2026-08-20

### Added

- **`aiFoundryDisableLocalAuth` / `AI_FOUNDRY_DISABLE_LOCAL_AUTH` parameter.** The AI Foundry account's local (API-key) authentication toggle was previously hardcoded inside `modules/ai-foundry/foundry/main.bicep` with no way to override it from `main.bicep`/`main.parameters.json`/azd env. It is now a top-level parameter, defaulting to `true` (local auth disabled, Azure AD-only) to preserve prior behavior exactly.
- **`azd env set` support for `deployCosmosDb`, `deployContainerApps`, `deployContainerRegistry`, `deployContainerEnv`, and `deployNsgs`.** These five flags were previously hardcoded literals in `main.parameters.json` with no environment-variable indirection. They now follow the `${VAR=default}` convention (`DEPLOY_COSMOS_DB`, `DEPLOY_CONTAINER_APPS`, `DEPLOY_CONTAINER_REGISTRY`, `DEPLOY_CONTAINER_ENV`, `DEPLOY_NSGS`), all defaulting to `true` to preserve prior behavior exactly.

### Changed

- Hardened component deployment flags so invalid Container Apps, API-key, and BYO subnet/NSG combinations fail before deployment, while environment-only Container Apps deployments retain the required private DNS zone.
- Documented that component flags select resources for an incremental deployment and do not delete resources or App Configuration values created by earlier deployments.
- This backward-compatible public control surface is a minor release. Portal and Terraform landing-zone parity follow-up is tracked in [Azure/AI-Landing-Zones#132](https://github.com/Azure/AI-Landing-Zones/issues/132).

## [v2.5.2] - 2026-08-20

### Fixed

- **A release source for the Portal Maintenance Configuration wrapper now
  forwards its complete typed object to AVM 0.3.1.** `maintenanceScope`, `maintenanceWindow`,
  `extensionProperties`, `installPatches`, `namespace`, `visibility`,
  `enableTelemetry`, `lock`, and `roleAssignments` are no longer dropped.
  Omitted non-nullable values retain the AVM defaults, while nullable lock,
  role assignments, and tags remain nullable. Regenerated Portal wrappers can
  therefore retain an `InGuestPatch` configuration's schedule and reboot
  settings instead of silently falling back to `Host`. The corresponding
  generated Portal wrapper is updated through the normal downstream release
  adoption process.

## [v2.5.1] - 2026-08-11

### Fixed

- **Azure Firewall now allows the Microsoft Foundry Agent Service's
  `agent365.svc.cloud.microsoft` observability endpoint for hosted agents
  under network isolation.** Live Azure validation of a network-isolated
  deployment proved that Azure Firewall's default-deny blocked this exact
  FQDN: the capability host and hosted-agent runtime started successfully,
  but every hosted-agent request failed immediately after startup because
  the runtime's own post-startup observability/telemetry call had no allow
  rule. The FQDN is added to the existing `AllowContainerAppsPlatform`
  Application Rule (source `*`, already covering the AI Foundry Agents
  subnet) alongside the other always-on platform diagnostics endpoints — no
  new firewall rule, resource, or feature flag is introduced, and no other
  rule, output, or default changes. Upgrade compatibility: this is a
  strictly additive allow-list change; existing deployments with
  `networkIsolation=true` and `deployAzureFirewall=true` pick it up on the
  next `azd provision`/redeploy with no parameter or manual action required,
  and deployments without network isolation or the firewall are unaffected.

## [v2.5.0] - 2026-08-06

### Added

- **Two-phase Microsoft Foundry hosted-agent preparation and deployment.**
  Added the backward-compatible `prepareHostedAgent` flag (azd environment
  variable `PREPARE_HOSTED_AGENT`), defaulting to `false`. Preparation now
  provisions the existing generic Foundry project and selected-registry RBAC and
  exposes the Foundry, ACR, network, and private-build handoff before an image
  exists, without requiring `hostedAgent.version` or enabling an agent payload.
  `deployHostedAgent=true` remains a superset, still fails closed unless
  `hostedAgent.version` is an immutable `sha256:<64 lowercase hex>` digest, and
  continues to represent downstream `azure.ai.agent` deployment intent. Existing
  deployments with both flags omitted or `false` retain the previous resource
  graph and empty hosted-agent outputs. Private ACR, VNet-injected ACR Task agent
  pool, firewall, private endpoint, and DNS topology remain controlled by their
  existing flags. This additive public contract is a **minor** release change;
  Portal and Terraform landing-zone parity require follow-up review.

### Fixed

- **Compiled-template size validation now uses one release gate locally and in
  CI.** The bare `pwsh ./scripts/Measure-MainJsonSize.ps1` command now preserves
  the 3.5 MB working warning while failing at the repository-authoritative
  4.7 MB ratchet and 5.0 MB ARM ceiling. GitHub Actions calls the bare command
  instead of overriding stale script defaults, and deterministic regression
  coverage prevents the local and CI contracts from diverging again.
- **Foundry IQ shared private-link names now stay within Azure AI Search's
  60-character resource-name limit for every Search service name, without
  requiring short (<=7 character) environment names.** Network-isolated
  deployments with long explicit or CAF-generated Search service names
  previously produced `foundry_account` (61 chars) and `cognitiveservices_account`
  (71 chars) child names longer than the service accepts, failing late in
  provisioning after the long-running Foundry resources completed — reproduced
  live against Azure/GPT-RAG. `openai_account` names were unaffected in that
  scenario but remain in scope for the fix. Each of the three shared
  private-link names now keeps its existing plain `spl-<searchServiceName>-
  <groupId>-1` form whenever that name already fits (preserving names —
  and avoiding orphaned/renamed child resources — for the vast majority of
  existing deployments and ordinary CAF/azd Search service names), and only
  falls back to a bounded, collision-resistant token (a truncated Search name
  plus a deterministic hash) when the plain name would exceed 60 characters.
  The three names remain pairwise distinct via their semantic group suffix and
  are bounded to exactly 60 characters in the worst case (a maximum-length
  60-character Search service name). **Upgrade compatibility:** each of the
  three shared private-link names is evaluated independently, so an existing
  deployment is renamed only for the specific name(s) that actually exceed 60
  characters — a deployment where all three names already fit is completely
  unaffected on the next `azd provision`/redeploy, with no manual action
  required. Only names that were already failing to provision (or would
  newly exceed the limit) move to the bounded fallback form. See
  [Azure/GPT-RAG#592](https://github.com/Azure/GPT-RAG/issues/592) and
  [Azure/GPT-RAG#597](https://github.com/Azure/GPT-RAG/issues/597).

## [v2.4.1] - 2026-08-03

### Fixed

- **ACR Task agent pool now provisions successfully with VNet injection under `NETWORK_ISOLATION=true`.** The Azure Firewall Policy on the devops build agents subnet only allowed Application/FQDN rules, but ACR Tasks dedicated agent pools require unconditional outbound Network Rules for their own platform bootstrap traffic (not just the task's own build-time egress). Added a `deployAcrTaskAgentPool`-gated Network Rule Collection Group granting the pool's subnet outbound access to `AzureKeyVault`, `Storage`, `EventHub`, `AzureActiveDirectory` (443), and `AzureMonitor` (443, 12000), matching Microsoft's documented ACR Tasks agent pool network requirements. Previously the pool failed to provision every time when VNet-injected (6/6 in the reporter's environment); confirmed live in a disposable network-isolated deployment that the pool now reaches `Succeeded` on first attempt, with the private endpoint reachable (DNS + TCP 443) from its subnet and all FQDN rules required for a private build (base image pulls, ACR data plane, task dispatch) already present and correctly scoped. See [Azure/GPT-RAG#597](https://github.com/Azure/GPT-RAG/issues/597).
- **Firewall policy rule collection groups no longer race the Azure Firewall resource's own provisioning.** The chained `ruleCollectionGroups` (Default → ACS media → ACR Task agent pool) only depended on each other and on the firewall policy, not on the `azureFirewall` resource itself, which can take 10–25 minutes to finish associating on a fresh deployment. On cold deployments the last group in the chain could reach Azure Resource Manager before the firewall finished provisioning and be rejected with `FirewallPolicyUpdateFailed` ("faulted referenced firewalls"), leaving the policy — and the newly added ACR Task agent pool rules — in a `Failed` state even though the pool itself could still show `Succeeded`. The ACR Task agent pool rule collection group now also depends on `azureFirewall`, guaranteeing deterministic, first-attempt success. Confirmed live in a disposable network-isolated deployment: the policy and rule collection group both reached `Succeeded` after the fix, versus `Failed` before it.

## [v2.4.0] - 2026-07-30

### Added

- **Accelerator-neutral Microsoft Foundry hosted-agent prerequisites (`deployHostedAgent`).** The new opt-in flag defaults to `false` and leaves the complete pre-existing resource graph unchanged. Enabling it adds only the generic Foundry project and Container Registry RBAC needed for a downstream `azure.ai.agent` deployment, plus typed image repository, immutable digest, startup command, CPU, memory, protocol, existing-registry, Foundry, network, and private-build handoff values. Container Apps, Cosmos DB, Search, Storage, App Configuration, and all workload lists remain governed only by their existing parameters.
- **Hosted-agent deployment outputs.** Exact Foundry project and selected-registry resource IDs/endpoints are exposed with a consolidated `HOSTED_AGENT_DEPLOYMENT` object. The landing zone intentionally does not create a placeholder ARM resource: the downstream accelerator's `azd deploy` creates the immutable agent version, dedicated agent identity, registry pull grant, and invocation endpoint.
- **Hosted-agent contract validation.** Preflight now requires Foundry and registry prerequisites, rejects mutable image references and unsupported role-name lists, and explains the VNet-internal build requirement for private ACR. An offline compiled-resource fixture proves disabled graph parity and limits enabled mutations to the two centralized RBAC payloads.
- This backward-compatible capability is a **minor** release change. The Portal experience and Terraform landing-zone implementation require follow-up parity review.
- **GitHub Copilot engineering-agent framework.** Added a concise repository
  operating contract, specialized architecture, implementation, validation,
  operations, and release agents, reusable Bicep/Azure-IaC skills, path-scoped
  instructions, and PowerShell-native YAML frontmatter/link validation in CI.
  These assets guide repository development and operations only; they do not
  change deployed resources, Microsoft Foundry agents, Bicep contracts,
  parameters, scripts, or landing-zone behavior.

### Fixed

- **Hosted-agent registry pull RBAC now matches the selected ACR permissions mode.** The landing-zone registry uses its existing RBAC-only mode and grants `AcrPull`. Existing registries default to the same mode and can set `hostedAgentContainerRegistryRoleAssignmentMode=rbac-abac` to grant `Container Registry Repository Reader` instead. This prevents hosted-agent image pulls from failing because an ABAC-only role was assigned to an RBAC-only registry.

## [v2.3.0] - 2026-07-02

### Added

- **Workload App Configuration passthrough (`additionalAppConfigurationSettings`).** Solution accelerators can now publish their own runtime key-values into the App Configuration store without adding workload-specific parameters to this template. Each entry takes `name`, `value`, and optional `label` and `contentType`. The landing zone stamps the entries verbatim. Values are plaintext (do not pass secrets), each `name`+`label` must be unique, and a passthrough entry that collides with a built-in setting wins so accelerators can override a stamped default. When the consumer opts out of App Configuration and uses the `containerEnv` runtime mode (Issue #89), the same entries are injected into every Container App as env vars (name/value only, labels ignored), so the passthrough works in both runtime modes. The parameter defaults to an empty array, so existing deployments produce byte-identical App Configuration and container env output. This keeps the landing zone workload-agnostic: GPT-RAG and other accelerators publish their Foundry IQ and other runtime keys through the passthrough instead of the template growing accelerator-specific parameters. See [Workload App Configuration passthrough](README.md#workload-app-configuration-passthrough).

### Deprecated

- **Accelerator-specific `foundryIq*` knowledge-source parameters.** `foundryIqPattern`, `foundryIqKnowledgeSourceName`, `foundryIqSearchIndexName`, `foundryIqBaseFilter`, and `foundryIqFilterAddOnEnabled` (and the wider `foundryIq*` runtime family) still work and are unchanged, but they are superseded by the generic `additionalAppConfigurationSettings` passthrough. New accelerators should publish these keys through the passthrough. `retrievalBackend` is not deprecated: it gates real infrastructure (the AI Foundry knowledge-base connection and shared private links), not just configuration.

## [v2.2.0] - 2026-06-30

### Changed

- **BREAKING: CAF-aligned resource naming is now the default.** `resourceNamingMode` now defaults to `caf`, so a plain `azd provision` generates Cloud Adoption Framework-style names (`type-workload-environment-region-instance`, for example `kv-a1b2c3-dev-eus2-001`) instead of the previous `resourceToken`-based names. No manual token input is required: `CAF_WORKLOAD_NAME` defaults to a short deterministic hash (stable per subscription, environment, and location), `CAF_ENVIRONMENT_NAME` defaults to the azd environment name, `CAF_REGION_NAME` defaults to the azd location mapped to a short region code (`eastus2` becomes `eus2`), and `CAF_INSTANCE` defaults to `001`. Explicit `*Name` parameters still override generated names.

  **Impact on existing deployments:** upgrading with default settings will generate new names and can create parallel resources instead of updating existing ones. To keep your current names, pin the previous behavior before provisioning with `azd env set RESOURCE_NAMING_MODE legacy`.

### Added

- **CAF token defaults so no manual naming input is required.** Every CAF token has a safe default, so operators can adopt CAF naming without setting any environment variables. Override any token (for example `azd env set CAF_WORKLOAD_NAME contosoai`) when a meaningful name is preferred.

### Fixed

- **Generated CAF names are length-safe and idempotent.** Region tokens are abbreviated to short CAF codes (with a 5-character fallback for unmapped regions), and every generated name is bounded to its Azure limit (storage 24, Key Vault 24, Container Apps environment 32, Cosmos DB 44, Container Registry 50, and so on). Truncation never leaves a trailing hyphen, so names such as `kv-...` stay valid after bounding. Because the tokens are deterministic, redeploying the same environment produces the same names.

## [v2.1.6] - 2026-06-30

### Added

- **CAF-aligned generated resource names are now available as an opt-in mode** ([#83](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/83), [#87](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/87)). `resourceNamingMode` defaults to `legacy` so existing deployments keep the current generated names. New greenfield environments can set `RESOURCE_NAMING_MODE=caf` with `CAF_WORKLOAD_NAME`, `CAF_ENVIRONMENT_NAME`, `CAF_REGION_NAME`, and `CAF_INSTANCE` to generate Cloud Adoption Framework-style names. Explicit `*Name` parameters continue to override generated names in both modes.

### Changed

- **`main.bicep` is smaller and easier to maintain (issue [#87](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/87)).** Large resource bodies were moved out of the monolithic orchestration template into local modules, with no change to any deployed resource, name, condition, dependency, or property value. The Azure Firewall (policy, rule collection groups, public IP, diagnostics, and FQDN rule data) moved to `modules/networking/azure-firewall.bicep` and now exposes its private IP as a module output that feeds the spoke default route. The per-app container control-plane role loops and the remaining cross-service control-plane role grants (Search, Storage, and AI Foundry project identities) were consolidated into array-driven `resource-role-assignment` invocations. Container Apps naming, Dapr, and base-environment shaping now use named locals, and private endpoint DNS zone groups are centralized in a single map. The template went from roughly 4329 to 3387 lines. This is an internal refactor only; existing deployments are unaffected.

## [v2.1.5] - 2026-06-30

### Fixed

- **Foundry IQ Zero Trust deployments create AI Search private links after Foundry exists.** The primary application Search service now defers the Foundry, Azure OpenAI, and Cognitive Services shared private link resources until both Search and the Foundry account are provisioned. This avoids the ARM `ParentResourceNotFound` race that occurred when Search tried to create those private links before the Foundry account resource was available, while keeping the dependency graph cycle-free.
- **Foundry IQ native Blob defaults are consistent across parameter substitution and preflight.** `main.parameters.json` now defaults `FOUNDRY_IQ_PATTERN` to `azureBlob`, and the preflight validator accepts `azureBlob` as the default Pattern A value instead of treating `searchIndex` as the fallback.
- **Foundry IQ native Blob runtime settings are parameterized for fresh GPT-RAG deployments.** Added parameter-file substitution for Knowledge Source kind, container, folder path, ADLS mode, extraction mode, ingestion permission options, and Pattern B filter add-on so App Configuration stays aligned with `azd env` values.
- **Fresh Foundry IQ deployments now stamp the native Blob prerequisites used by GPT-RAG search setup.** App Configuration includes the deterministic `SEARCH_RAG_INDEX_NAME` and a `FOUNDRY_IQ_AI_SERVICES_ENDPOINT` value derived from the Foundry account unless the operator overrides it for an existing Foundry resource.

## [v2.1.4] - 2026-06-27

### Fixed

- **Zero Trust Foundry capability host provisioning** ([#110](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/110)). The agent subnet delegation now uses the canonical `Microsoft.App/environments` service name (capital `A`) so AmlRp accepts the subnet when auto-creating the `<account>@aml_aiagentservice` capability host during the Foundry account PUT. Previously the delegation literal was `Microsoft.app/environments` (lowercase `a`), which the AVM virtual-network module emitted for both the delegation `name` and `properties.serviceName`. AmlRp does a case-sensitive comparison against `serviceName` when validating that the agent subnet is delegated to the Azure Container Apps control plane. With the lowercase form it concluded the subnet was not delegated and surfaced a generic `BadRequest: Invalid vnet resource ID provided, or the virtual network could not be found` about 47 minutes into the deployment, even though the VNet and subnet were healthy. The `aca-environment-subnet` delegation was updated for consistency; ACA was tolerant of the lowercase form but the canonical casing avoids any further case-sensitive lookups. Standard mode deployments were unaffected because the Foundry account is created without network injection in that path.

## [v2.1.3] - 2026-06-26

### Changed

- **Default `foundryIqContentExtractionMode` is now `standard`.** The native Foundry IQ azureBlob knowledge source now defaults to `standard` content extraction so scanned and image-only PDFs are ingested with OCR by the Foundry IQ Content Understanding skill. Under the prior `minimal` default, such PDFs were ingested with empty content and silently unsearchable. Operators that only ingest text PDFs can opt down with `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE=minimal` before provisioning. The setting is immutable on an existing Knowledge Source; changing it requires recreating the Knowledge Source and Knowledge Base. `standard` mode requires a Foundry resource in a [Content Understanding-supported region](https://learn.microsoft.com/azure/ai-services/content-understanding/service-limits#region-support), may require a one-time `PATCH /contentunderstanding/defaults` call against the Foundry resource on first use, has per-document limits of 300 pages and 5 minutes of processing time, and is billed through Content Understanding meters in addition to the Azure AI Search `knowledgeRetrieval` plan.
- **`main.parameters.json` now substitutes `FOUNDRY_IQ_CONTENT_EXTRACTION_MODE` and defaults it to `standard`** so `azd env set` and the parameter file stay aligned with the Bicep default.

## [v2.1.2] - 2026-06-26

### Fixed

- **Foundry IQ native Blob permission default matches the service contract.** `foundryIqIngestionPermissionOptions` now defaults to `['rbacScope']`, which Foundry IQ accepts for `azureBlob` Knowledge Sources when `foundryIqIsAdlsGen2=false`. ADLS Gen2 deployments can still override the parameter to include ACL-driven metadata such as `userIds` and `groupIds` when the source supports it.

## [v2.1.1] - 2026-06-26

### Added

- **Foundry IQ runtime configuration groundwork for GPT-RAG** ([Azure/GPT-RAG#526](https://github.com/Azure/GPT-RAG/issues/526)). Added `retrievalBackend`, Foundry IQ Pattern A/B parameters, dedicated `KNOWLEDGE_BASE_CONNECTION_ID` stamping, Pattern B searchIndex knowledge-source settings, `knowledgeRetrieval` billing-plan configuration, preflight checks, and a post-provision helper script for creating the Azure AI Search data-plane knowledge source and knowledge base. `ENABLE_AGENTIC_RETRIEVAL` is now documented as deprecated but remains stamped for one-release compatibility.
- **Foundry IQ defaults to native Blob or ADLS Knowledge Sources.** `foundryIqPattern` now defaults to `azureBlob`, while `searchIndex` remains available as explicit Pattern B opt-in. App Configuration now stamps the native Knowledge Source kind, container, folder path, ADLS mode, content extraction mode, and permission options so GPT-RAG can let Foundry IQ process files directly.

## [v2.0.20] - 2026-06-18

### Fixed

- **Preflight now preserves structured parameters before regional model quota checks** ([#103](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/103)). `Expand-ParamValue` no longer coerces arrays and objects such as `modelDeploymentList` into strings while expanding `${VAR}` tokens. The AI model quota preflight can now inspect requested OpenAI deployments and fail early with `MODEL_QUOTA_INSUFFICIENT` when the requested capacity exceeds available regional quota, instead of reporting "All checks passed" and letting ARM fail later.

## [v2.0.19] - 2026-06-17

### Fixed

- **AI Foundry project deployments now honor `aiFoundryProjectName`** ([#101](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/101)). The template already exposed `aiFoundryProjectName` and published it to App Configuration as `AI_FOUNDRY_PROJECT_NAME`, but the AI Foundry project resource still used the hardcoded name `aifoundry-default-project`. The deployed project name now follows the parameterized naming pattern, the display name defaults to that same generated project name, and both display name and description can still be customized with `aiFoundryProjectDisplayName` and `aiFoundryProjectDescription`.

## [v2.0.18] - 2026-06-16

### Fixed

- **Regional preflight no longer emits non-actionable transient capacity warnings.** Removed the `SEARCH_CAPACITY`, `COSMOS_CAPACITY`, and `ACA_WORKLOAD_PROFILE_CAPACITY` warnings because Azure does not expose reliable pre-create APIs for those transient capacity pools. The preflight now stays focused on checks it can actually validate, such as provider/location support, VM SKU availability, and AI model quota.

## [v2.0.17] - 2026-06-14

### Added

- **App Configuration is now optional for external Container Apps via the new `appRuntimeConfigurationMode` parameter** ([#89](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/89)). The parameter accepts three values, each gating the runtime configuration plane independently of `deployAppConfig` (which still controls whether the store itself is deployed):
  - `appConfig` (default): preserves the existing behavior. The App Configuration store is populated with deployment outputs (`appConfigPopulate`, `appConfigKeyVaultPopulate`, `cosmosConfigKeyVaultPopulate`), each Container App receives the `APP_CONFIG_ENDPOINT` env var, and the per-app `App Configuration Data Reader` role assignment is created. Existing consumers see no change.
  - `containerEnv`: skips the three App Configuration population modules and the per-app `App Configuration Data Reader` RBAC. Each Container App instead receives a curated bootstrap env block (`SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `LOCATION`, `ENVIRONMENT_NAME`, `RESOURCE_TOKEN`, `RELEASE`, `NETWORK_ISOLATION`, `USE_UAI`, `ENABLE_AGENTIC_RETRIEVAL`, `LOG_LEVEL`, `ENABLE_CONSOLE_LOGGING`, the Foundry account/project names + computed `AI_FOUNDRY_ACCOUNT_ENDPOINT` and `AI_FOUNDRY_OPENAI_ENDPOINT`, and the deployed resource names for App Insights / Container Env / Container Registry / Cosmos / Search / Storage / Key Vault / App Config). Consumers resolve endpoints and other runtime details through the Azure SDK from these names. The block contains no cross-module `.outputs` references, so it is free of circular dependencies and re-deploys idempotently (each provision recomputes from current parameter and resource-name expressions).
  - `none`: deploys the Container App shells with only the identity bootstrap (`AZURE_TENANT_ID`, plus `AZURE_CLIENT_ID` when `useUAI=true`). Callers are expected to supply runtime configuration through their own mechanism.
- Secrets remain on secure params / Key Vault references in every mode; they are never emitted into env vars by this template.
- New output `APP_RUNTIME_CONFIGURATION_MODE` echoes the active mode so downstream tooling can branch on it.
- **Container Apps Dapr sidecar is now opt-in** ([#90](https://github.com/Azure/bicep-ptn-aiml-landing-zone/pull/90)). Workloads that do not need Dapr no longer pay the sidecar cost by default; consumers can re-enable it per app via the existing parameter shape.

## [v2.0.16] - 2026-06-14

### Fixed

- **Foundry Agent Service v2 Cosmos data-plane assignments now cover lazily-created containers** ([#94](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/94)). The `cosmosDbDataPlane.bicep` module previously created five per-collection `Cosmos DB Built-in Data Contributor` assignments scoped to a fixed list of capability-host containers (`thread-message-store`, `system-thread-message-store`, `agent-entity-store`, `agent-definitions-v1`, `run-state-v1`). The Foundry Agent Service v2 runtime creates additional containers on demand (for example `<workspaceId>-aoaiv2-vector-store-store`), and the data-plane RBAC check against any not-yet-created collection scope returns `403`, breaking `AIProjectClient.agents.create_version` and `run_stream` in regions such as `swedencentral`. The module now creates a single role assignment scoped at the database level (`dbs/enterprise_memory`) so the project identity is authorized over every container the capability host owns, including ones materialized at runtime. The assignment name uses `guid(roleDefinitionId, principalId, dbScope, projectWorkspaceId)` so redeploys are idempotent. The database is dedicated to the Foundry capability host, so this is not a privilege widening in practice.
  - Operator note for upgrades from v2.0.13 / v2.0.14: the previous five per-collection assignments remain on the account as orphans. They are informational only, not blocking, and are not removed by Bicep. If you want to clean them up, use `az cosmosdb sql role assignment delete` against the `dbs/enterprise_memory/colls/<workspaceId>-<suffix>` scopes.
- **Preflight warns when `enableCosmosAnalyticalStorage=true` targets a region that rejects analytical storage at account creation** ([#93](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/93)). Several region/subscription combinations (notably `swedencentral`) reject Cosmos DB account creation with `Enabling analytical storage on account creation is not supported in this subscription/region. Please disable analytical storage on the account creation request and try again.`, and the flag cannot be toggled post-creation. `scripts/Invoke-PreflightChecks.ps1` now runs `Test-CosmosAnalyticalStorageRegionSupport`, which emits a `WARN` (code `COSMOS_ANALYTICAL_REGION`) when `enableCosmosAnalyticalStorage=true` and `cosmosLocation` (or `location` as fallback) is on the known-restrictive list. It is a `WARN` rather than `FAIL` because subscription/region eligibility for analytical storage can change without notice. The `@description` of `enableCosmosAnalyticalStorage` in `main.bicep` now also names the literal Cosmos error and links #93 so operators can self-diagnose without re-reading the issue.

## [v2.0.15] - 2026-06-11

### Fixed

- **AI Foundry inference-only deployments no longer create Agent Service dependencies** ([#88](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/88), [#84](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/84)). `deployAAfAgentSvc` now controls the Agent Service Standard Setup and its associated AI Search, Storage, Cosmos DB, and Key Vault resources through the AI Foundry wrapper's `includeAssociatedResources` flag. `deployAiFoundry=true` with `deployAAfAgentSvc=false` deploys the Foundry account, project, and model deployments for hosted inference only, while `deploySearchService` remains scoped to the workload/RAG Search service.

## [v2.0.14] - 2026-06-04

### Changed

- **Dapr is now opt-in per Container App** (addresses #86): Container Apps no longer receive Dapr configuration automatically. Apps can enable Dapr explicitly through `containerAppsList[].dapr.enabled=true`, with optional per-app overrides for `appId`, `appPort`, `appProtocol`, and `enableApiLogging`. This makes external app deployments avoid unnecessary Dapr sidecars by default while allowing GPT-RAG and other Dapr-dependent workloads to preserve service invocation by declaring Dapr explicitly.

## [v2.0.13] - 2026-06-02

### Fixed

- **Foundry Agent Service v2 Cosmos data-plane permissions.** The AI Foundry project managed identity now receives Cosmos DB Built-in Data Contributor assignments for the capability-host containers used by declarative/versioned agents: `agent-definitions-v1` and `run-state-v1`. These containers back `AIProjectClient.agents.create_version()` / `PromptAgentDefinition` agent definitions and run state. Without these assignments, new deployments that use the Foundry Agent Service v2 agent API can fail with Cosmos DB `403` errors even though the legacy thread/entity stores are accessible.

## [v2.0.12] - 2026-06-01

### Fixed

- **Jumpbox CSE disables azd first-run prompts before `azd init`**. The Windows jumpbox bootstrap now sets `AZD_SKIP_FIRST_RUN=true` before running azd commands under Custom Script Extension. This prevents `azd init` from blocking on the non-interactive "Would you like to check your Azure development tools?" first-run prompt until the watchdog times out, while preserving the `v2.0.9` bounded execution behavior.

## [v2.0.11] - 2026-06-01

### Fixed

- **Git clone watchdog captures native stderr as text**. The jumpbox clone wrapper now stringifies `git clone` output inside the background job before returning it to the parent PowerShell session. This prevents benign native stderr such as `Cloning into ...` from surfacing as a PowerShell job error record and causing the Custom Script Extension to fail even when the clone succeeds.

## [v2.0.10] - 2026-06-01

### Fixed

- **Windows jumpbox CSE script remains parseable under Windows PowerShell 5.1**. The `v2.0.9` timeout fix added optional-step budget warnings that used a Unicode em dash inside double-quoted strings. The CSE executes `install.ps1` with Windows PowerShell 5.1, which can read UTF-8-without-BOM scripts through the system ANSI code page; the em dash bytes were mis-decoded before parsing and caused an `Unexpected token` parser failure near the Python PATH update. Those warning strings now use ASCII hyphens, preserving the `v2.0.9` wall-clock budget and watchdog behavior while keeping the script parseable on the jumpbox.

## [v2.0.9] - 2026-06-01

### Fixed

- **ZTA: Jumpbox Windows CSE no longer times out with `VMExtensionProvisioningTimeout`** ([#82](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/82)). The Windows `CustomScriptExtension` that runs `install.ps1` has a fixed 90-minute platform provisioning timeout that cannot be extended from the extension definition. Several bootstrap operations were unbounded and their cumulative worst-case wall time could exceed 90 minutes under Zero Trust (where all jumpbox egress traverses the Azure Firewall and feeds can be slow or transiently blocked) — most significantly the Chocolatey package installs, which inherited Chocolatey's **default 2700s (45 min) per-package** execution timeout (5 packages → up to ~225 min on their own). When the script was still running at minute 90, ARM failed the extension with "the extension did not report a message," even though every other resource had provisioned successfully. `install.ps1` is now self-limiting:
  - Added `--execution-timeout=600` to the Chocolatey args (10 min/package cap).
  - Bounded the Chocolatey bootstrap download/install and every `Invoke-WebRequest` (Python embeddable zip, `get-pip.py`, win-acme) with explicit timeouts.
  - Added a new `Invoke-NativeWithTimeout` process-tree watchdog and wired it around `azd auth login --managed-identity` and `azd init` so a hung azd network call cannot keep the extension in `Transitioning`.
  - Introduced an overall wall-clock budget (~75 min) that **skips OPTIONAL steps** (Python, win-acme, component/extra repo clones) when little budget remains, while keeping **CORE steps fatal** (Chocolatey, `git`/`azure-cli`/`azd`, the main LZ repo clone, `azd auth login`, `azd init`) so the CSE only reports success when the jumpbox is actually usable. Critical Chocolatey package failures now `throw` instead of being silently swallowed as warnings.
  - win-acme is now staged into a temp directory and only swapped into `C:\tools\win-acme` after a successful download + version check, and its failure is non-fatal (a previously working install is left intact) — it is a certificate convenience tool, not a dependency of any other resource.
  - Routed the component/extra repo "update existing" path (previously an unbounded `git fetch --all` / `git checkout`, a real re-run hang risk given `forceUpdateTag`) through the bounded `Invoke-GitCloneWithTimeout` helper.

  No Bicep parameter contract changes. Because `install.ps1` is fetched from the tag pinned in `manifest.json#ailz_tag`, this release also bumps `manifest.json#ailz_tag` (and `tag`) from `v2.0.0` to `v2.0.9` so the fixed script is actually fetched by the jumpbox CSE. Previously the pin was never advanced past `v2.0.0`, so every deployment ran the original `install.ps1` regardless of the template version in use.

## [v2.0.8] - 2026-05-31

### Fixed

- **ZTA: `DefaultRuleCollectionGroup` deployment rejected with `BadRequest: "The request is invalid."`** ([#80](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/80)). Azure Firewall validates `ApplicationRule.targetFqdns` at ARM request-validation time and rejects any rule whose `targetFqdns` array is empty — the entire rule collection group creation fails in ~0.3s with no operation logged, leaving the firewall with zero rules. This regression hit any consumer that disabled one of the optional egress extensions, including the most common GPT-RAG ZTA path where `deployAcrTaskAgentPool=false` (default) made `AllowAcrTasks`, `AllowAcrTaskDevRuntimes`, and `AllowAcrTaskOsPackages` ship with `targetFqdns: []`. The same shape also failed when `extendFirewallForJumpboxBootstrap=false` (all four jumpbox rules empty). With the firewall empty, the `aca-environment-subnet` UDR (`0.0.0.0/0 → AzFW`) silently blocked MCR, which then surfaced as the `azd provision` "Container App creation failed: GET mcr.microsoft.com: EOF" symptom that v2.0.7's `dependsOn` ordering fix tried to address. Wrapped the rule list in `filter(..., rule => !empty(rule.targetFqdns))` so the ARM payload only ever contains application rules with at least one FQDN target. Each rule definition is preserved verbatim — the only behavioural change is that rules whose feature flag resolved to "no targets" are omitted from the payload instead of being submitted as empty. Basic mode (`networkIsolation=false`) and topologies that do not deploy a local firewall are unaffected because the rule collection group is conditional on `deployAzureFirewall && _networkIsolation`. The `dependsOn` fix from v2.0.7 is retained as defence-in-depth: even with a valid RCG payload, container apps must still wait for the rules to land before MCR is reachable.

## [v2.0.7] - 2026-05-30

### Fixed

- **ZTA: Container App creation no longer races the firewall MCR allow rule** ([#78](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/78)). Under `networkIsolation=true` + `deployAzureFirewall=true`, the `aca-environment-subnet` UDR forces all egress through the firewall, and the ACA control plane validates the placeholder image (`mcr.microsoft.com/dotnet/samples:aspnetapp-9.0`) at create time. The Container Apps module previously did not depend on `firewallPolicyDefaultRuleCollectionGroup`, so Bicep created the apps in parallel with the rule collection group; the MCR pull was denied (`GET https://mcr.microsoft.com/v2/: EOF`) and the whole `azd provision` aborted before the firewall rules ever landed. Added the missing dependency so the `AllowMicrosoftContainerRegistry` application rule is in place before any container app is created. Basic mode (`networkIsolation=false`) and AI-LZ-integrated topologies that do not deploy a local firewall are unaffected because the referenced resource is conditional.

## [v2.0.6] - 2026-05-30

### Changed

- **`deployVmKeyVault` default flipped from `true` to `false`** in `main.bicep` and `main.parameters.json` (`${DEPLOY_VM_KEY_VAULT=false}`). The parameter is declared and surfaced as the `DEPLOY_VM_KEY_VAULT` output but does not currently gate any resource in the template — so the previous `true` default never actually produced a VM-side Key Vault and only created a misleading signal for downstream tooling. The output is preserved so existing consumers reading `azd env get-values` continue to receive a value; only the default changes.

## [v2.0.5] - 2026-05-30

### Added

- **ACR Task build egress extension point**: new `additionalAcrTaskBuildFqdns` array parameter appends solution-specific HTTPS FQDNs to the ACR Tasks build-agent runtime rule, scoped to `devops-build-agents-subnet` and gated by `networkIsolation`, `deployAzureFirewall`, `deployAcrTaskAgentPool`, and `extendFirewallForAcrTaskBuilds`.

### Changed

- **Foundry-bundled AI Search default `replicaCount` lowered from `3` to `1`** in `modules/ai-foundry/foundry/modules/aiSearch.bicep`. The 3-replica default was inherited from the AVM Foundry reference and is the threshold for Azure AI Search's read/write SLA, but is overkill for the typical landing-zone bootstrap workload and roughly triples the Search bill (Standard SKU ~$245/mo per replica × partition, i.e. ~$735/mo for 3r×1p vs ~$245/mo for 1r×1p — a recurring ~$490/mo savings on every deployment that includes the Agent Service). The new default matches the workload AI Search service (`main.bicep` already used `replicaCount: 1` / `partitionCount: 1` for the workload Search). Operators who need the read/write SLA can scale the Search service back up to 3 replicas in-place from the portal/CLI with no data loss; bringing existing v2.0.x deployments in line with the new default is a non-destructive in-place scale-down. No template parameter contract is changed.

### Fixed

- **ACR Task builds needing Microsoft Linux package feeds** ([#68](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/68)): `packages.microsoft.com` is now part of the default ACR Tasks OS package allow-list so Dockerfiles can install Microsoft-supported packages such as `msodbcsql18` under network isolation without manual firewall edits.

## [v2.0.4] - 2026-05-29

### Fixed

- **Preflight regional readiness aborts with `The term 'if' is not recognized`** (regression introduced in v2.0.3): `scripts/Invoke-PreflightChecks.ps1` `Test-RegionalReadiness` used the pattern `ConvertTo-Bool (if (...) { ... } else { $true })` to resolve nine default-on `deploy*` feature flags. PowerShell does not accept `if` as an expression inside `(...)` when used as a command/function argument — the parser tries to invoke `if` as a command and fails with `CommandNotFoundException`. Result: `azd provision` (and any standalone `pwsh Invoke-PreflightChecks.ps1`) terminated immediately after the "Parameters file" banner with a confusing stack trace, before any regional checks could run, blocking every consumer of v2.0.3 (including [Azure/gpt-rag](https://github.com/Azure/GPT-RAG)). **Fix**: wrap the conditional with the subexpression operator `$(if (...) { ... } else { $true })` for all nine flags (`deployAiFoundry`, `deployCosmosDb`, `deployContainerApps`, `deployContainerEnv`, `deployKeyVault`, `deployStorageAccount`, `deployAppConfig`, `deployLogAnalytics`; `deploySearchService` was already correctly written as a bare assignment). Behaviour of the checks is unchanged; only the parser path is corrected.

## [v2.0.3] - 2026-05-29

### Added

- **`scripts/Invoke-PreflightChecks.ps1` — regional readiness block** (issue [#72](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/72)): the existing preflight script now extends its read-only validation with a regional/subscription readiness pass, so any consumer of the landing zone (including [Azure/gpt-rag](https://github.com/Azure/GPT-RAG)) can delete its duplicated regional preflight wrapper. The new `Test-RegionalReadiness` function runs after the existing parameter/topology/Azure-resource checks and adds the following findings — driven entirely by the effective `main.parameters.json` so no consumer-specific logic lives in the script:
  - **Subscription drift (`AZ_SUB_DRIFT` / `AZ_LOGIN_REQUIRED`)** — when invoked from an `azd preprovision` hook (signal: `AZURE_SUBSCRIPTION_ID` present in the azd env), `FAIL` if the `az` CLI default subscription differs from the one recorded in the azd environment, or if `az` is not logged in at all. Skipped silently when run standalone (no azd env).
  - **Provider/location support per resource type (`<PREFIX>_NOT_IN_REGION` `FAIL`, `<PREFIX>_PROVIDER_UNREG` `FAIL`, `<PREFIX>_PROVIDER_LOOKUP` `WARN`)** — for every resource type the landing zone provisions: AI Search (`Microsoft.Search/searchServices`), Cosmos DB (`Microsoft.DocumentDB/databaseAccounts`), Container Apps environments (`Microsoft.App/managedEnvironments`), AI Foundry / Cognitive Services (`Microsoft.CognitiveServices/accounts`), Key Vault, Storage, App Configuration, Log Analytics, Application Insights. Each check is gated on the corresponding `deploy*` feature flag, with the same default-on semantics as `main.parameters.json` (so flags omitted from the file or env still trigger the check). Locations are resolved with the same `location → aiFoundryLocation → cosmosLocation` fallback chain used elsewhere in the templates.
  - **Transient regional capacity warnings (`SEARCH_CAPACITY`, `COSMOS_CAPACITY`, `ACA_WORKLOAD_PROFILE_CAPACITY`)** — `WARN` (non-blocking) for the resources known to occasionally fail at provision time even when the region lists them as supported: AI Search with `InsufficientResourcesAvailable`, Cosmos DB with `ServiceUnavailable`, Container Apps Environment workload-profile capacity in popular regions. The hint links to the companion docs page at <https://azure.github.io/AI-Landing-Zones/bicep/regional-considerations/>. These warnings exist because no reliable pre-create quota API is exposed for these signals — surfacing them as `WARN` gives operators clear context if provisioning later fails, rather than letting them interpret the failure as a template bug.
  - **Jumpbox VM SKU availability (`JUMPBOX_VM_NOT_FOUND` / `JUMPBOX_VM_RESTRICTED` `FAIL`, `JUMPBOX_VM_LOOKUP` `WARN`)** — when `deployJumpbox=true` (or the legacy umbrella `deployVM=true`), runs `az vm list-skus --location <region> --size <vmSize> --all` to confirm the requested `vmSize` is both offered and not restricted in the region for the current subscription.
  - **AI model quota (`MODEL_QUOTA_INSUFFICIENT` `FAIL`, `MODEL_QUOTA_OK` `PASS`, `MODEL_QUOTA_LOOKUP` `WARN`)** — when `deployAiFoundry=true`, iterates `modelDeploymentList` and calls `az cognitiveservices usage list --location <aiFoundryLocation>`. For every `format=OpenAI` entry, looks up `OpenAI.<sku.name>.<model.name>` in the usage response and verifies `(limit - currentValue) >= sku.capacity`. Aggregates all per-model failures into a single finding with the regional quota-increase URL in the hint.
  - **Skippability** — the new block honours the existing `PREFLIGHT_SKIP=true` emergency bypass and `-SkipAzureLookups` (offline/CI). Additionally, the new `-SkipRegional` switch and `LZ_PREFLIGHT_REGIONAL_SKIP=true` env var skip only this block while keeping the deterministic parameter/topology/CIDR/BYO checks running. WARN findings remain non-fatal unless `-Strict` is passed (unchanged exit-code contract: `0` pass, `1` fatal, `2` warnings-only under `-Strict`).
  - **Tests** — `tests/scripts/Invoke-PreflightChecks.Tests.ps1` extended with smoke coverage for `Get-NormalizedLocation`, the `LZ_PREFLIGHT_REGIONAL_SKIP` skip path, the `-SkipAzureLookups` suppression, and the empty-`location` early-return. 28 assertions total (up from 22), still ~1s and zero Azure calls.

## [v2.0.2] - 2026-05-19

### Fixed

- **AI Foundry-bundled sub-modules emit invalid Private Endpoints under `networkIsolation=false`** (regression introduced in v2.0.0): `main.bicep` passed `varPeSubnetId` unconditionally as `privateEndpointSubnetResourceId` to the top-level `aiFoundry` module. `varPeSubnetId` is derived as `'${virtualNetworkResourceId}/subnets/pe-subnet'` regardless of `_networkIsolation`; when `_networkIsolation=false` the spoke VNet is not deployed, `virtualNetworkResourceId` resolves to `''`, and `varPeSubnetId` collapses to the bogus literal string `'/subnets/pe-subnet'`. The four AI Foundry-bundled sub-modules (`modules/ai-foundry/foundry/modules/{keyVault,aiSearch,storageAccount,cosmosDb}.bicep`) each derive `var privateNetworkingEnabled = !empty(privateEndpointSubnetResourceId)` (truthy on the garbage string) and emit invalid `privateEndpoints` iterators whose `subnetResourceId` is the malformed string. ARM template validation fails with `InvalidTemplate: 'databaseAccount_privateEndpoints[0]' / 'keyVault_privateEndpoints[0]' ... 'reference' is not valid: all function arguments should be string literals.`. The failure is deterministic and surfaces **after** the AI Foundry account, all model deployments, the AI Foundry-bundled Search and Storage, all workload Container Apps, and the workload AI Search have already been created, leaving the resource group in a half-deployed state. **Fix**: `main.bicep` now mirrors the existing sibling pattern at the `aiFoundryStorageAccount` call site — `privateEndpointSubnetResourceId: _networkIsolation ? varPeSubnetId : ''`. When network isolation is off, all four bundled sub-modules see an empty subnet ID, `privateNetworkingEnabled` evaluates `false`, and no PE iterators are emitted. No behavior change for the `_networkIsolation=true` topology. Tracking issue: [#63](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/63).

## [v2.0.1] - 2026-05-19

### Fixed

- **Duplicate deployment-resource name in AI Foundry account private endpoint emission** (regression introduced in v2.0.0 PR #58): `modules/ai-foundry/foundry/main.bicep` declares two mutually-exclusive `module` symbolic resources for the AI Foundry account Private Endpoint (`foundryAccountPrivateEndpoint` with full DNS-zone wiring and `foundryAccountPrivateEndpointWithoutDns` for the policy-managed-DNS case) but both used the same compiled deployment name `take('module.account.pe.${resourcesName}', 64)`. While the `if`-conditions are mutually exclusive at deploy time, the Bicep compiler always emits both as `Microsoft.Resources/deployments` JSON resources in the compiled ARM template. ARM template validation treats two top-level resources with identical type+name as ambiguous, and downstream symbolic references resolve to "resource is not defined in the template", causing `azd provision` to fail mid-deployment with `InvalidTemplate: 'The resource 'Microsoft.Resources/deployments/module.account.pe.<resourcesName>' is not defined in the template'` after the AI Foundry-bundled Search service, storage account, and Container Apps have already been created. Reproduced in `swedencentral` with `networkIsolation=false`, `deployAiFoundry=true`, `deployAfProject=true`, default `aiFoundryConfiguration.networking=null` (so neither PE module is actually emitted at deploy time — the bug is pure template-validation, not deploy-time logic). **Fix**: the `WithoutDns` variant now uses a distinct name `'module.account.pe.nodns.${resourcesName}'`, eliminating the JSON-level collision while preserving the mutually-exclusive runtime gate. No behavior change for any topology; existing v2.0.0 deployments that succeeded are unaffected.

## [v2.0.0] - 2026-05-18

> v2.0.0 is a **major release** that introduces hub-and-spoke composability, granular reuse of platform resources, IP allow-lists, and a deployment-mode preset. The Zero Trust topology that v1.x operators already use keeps working. See [docs/v2-migration.md](docs/v2-migration.md) for the upgrade path, [docs/runbook-hub-spoke.md](docs/runbook-hub-spoke.md) for the hub-and-spoke walkthrough, and [docs/runbook-standalone.md](docs/runbook-standalone.md) for the simpler single-subscription scenario. Tracking issue: [#58](https://github.com/Azure/bicep-ptn-aiml-landing-zone/issues/58).

### Breaking Changes

- **`deployVM` is split into three independent flags** (Gap 4 in #58): the single `deployVM` boolean was overloaded — it gated the jumpbox VM, the Bastion host, and the NAT Gateway as one unit, blocking any topology where the spoke wants its own jumpbox but reuses a hub-managed Bastion (the canonical ALZ-integrated scenario). v2.0.0 introduces `deployJumpbox`, `deployBastion`, and `deployNatGateway` — each independently controllable — plus `existingJumpboxResourceId`, `existingBastionResourceId`, and `existingNatGatewayResourceId` for the BYO variants. The legacy `deployVM` parameter is retained as a **deprecated** umbrella that acts as the default for all three new flags when they're left unset (`null`), so v1.x deployments continue to behave identically without env-var changes. Slated for removal in v3.0.0. **Operator action**: search CI/CD pipelines for `DEPLOY_VM` and replace with the explicit triplet (see [docs/v2-migration.md §3.1](docs/v2-migration.md#31-deployvm-is-split-into-three-flags)).

### Added — Hub-and-Spoke composability

- **`allowedIpRanges` parameter for public-access IP allow-lists across 7 PaaS services** (Gap 1 in #58): production AI Landing Zones increasingly need a "Zero Trust + named developer IPs" hybrid — workloads talk through Private Endpoints, but a specific developer workstation (or CI runner) must be allowed to hit data planes directly without RDP'ing into a jumpbox. v1.x had no way to express this except editing the template. v2.0.0 introduces `allowedIpRanges` (default `[]`, surfaced as `${ALLOWED_IP_RANGES=}` in `main.parameters.json`), an array of CIDRs applied uniformly to Storage account network ACLs, Key Vault `networkAcls.ipRules`, App Configuration `publicNetworkAccess` ACL, Container Registry `networkRuleSet.ipRules`, Cosmos DB `ipRules`, AI Search `networkRuleSet.ipRules`, and the AI Foundry-owned storage account (via the new `modules/ai-foundry/storage-account.bicep` IP-rule plumbing). The allow-list is **orthogonal** to `networkIsolation`: `networkIsolation=false + allowedIpRanges=[CIDRs]` gives a "public restricted by IP" topology; `networkIsolation=true + allowedIpRanges=[CIDRs]` gives Zero Trust + an explicit egress exception list. When `allowedIpRanges` is empty, behavior is unchanged from v1.x. The default-deny rule (`defaultAction=Deny`) is automatically applied to every service whenever the list is non-empty.
- **Granular per-zone BYO Private DNS overrides — 15 parameters** (Gap 2 in #58): in ALZ topologies the Private DNS zones (`privatelink.openai.azure.com`, `privatelink.documents.azure.com`, etc.) typically live in a central platform subscription and are linked to all spoke VNets via Azure Policy or a DDI appliance. v1.x always created its own zones inside the spoke, conflicting with the platform-managed ones and causing duplicate VNet links. v2.0.0 introduces fifteen nullable `existingPrivateDnsZone<Service>ResourceId` parameters — one for each of the zones the AI LZ uses (CogSvcs, OpenAi, AiServices, Search, Cosmos, Blob, KeyVault, AppConfig, ContainerApps, Acr, AzureMonitor, OmsOpsInsights, OdsOpsInsights, AzureAutomation, AppInsights). Each is opt-in independently. The `privateDnsZones` AVM module call is now gated on `!empty(_dnsZonesList)`, so a fully BYO deployment skips zone creation entirely; partial BYO deployments only create zones the operator hasn't overridden. Downstream PE wiring reads each `_dnsZone<X>Id` derived local that coalesces BYO IDs with the locally-created zones, so the PE module always gets a valid zone ID regardless of the source.
- **`dnsZoneLinkSuffix` parameter for multi-spoke shared zones** (Gap 3 in #58): when multiple spokes share the same Private DNS zones (the common ALZ pattern), each VNet link on a zone must have a unique name. v1.x derived link names from the zone name + a fixed `'-byon'` suffix (when `useExistingVNet=true`), which collided across spokes that reused the same hub zones. v2.0.0 introduces `dnsZoneLinkSuffix` (default `''`); the derived `_dnsZonesLinkSuffix` is now `'${useExistingVNet ? '-byon' : ''}${empty(dnsZoneLinkSuffix) ? '' : '-${dnsZoneLinkSuffix}'}'`, allowing each spoke to set a unique suffix (`spoke01`, `spoke02`, …) without colliding on zone-link names. Empty default preserves v1.x naming.
- **Decoupled `deployJumpbox`, `deployBastion`, `deployNatGateway` + BYO equivalents** (Gap 4 in #58, breaking): see the Breaking Changes section above. The hub-and-spoke case where the spoke runs its own jumpbox but uses the hub's Bastion is now expressible as `DEPLOY_JUMPBOX=true DEPLOY_BASTION=false EXISTING_BASTION_RESOURCE_ID=<hub bastion id> DEPLOY_NAT_GATEWAY=true`. Each BYO `existing*ResourceId` is parsed at compile time to derive the subscription/RG/name for cross-subscription `existing` references, so the operator can point at any hub-side resource regardless of where the spoke is deploying.
- **Observability reuse — bring your own Log Analytics workspace and Application Insights** (Gap 5 in #58): v1.x always provisioned a fresh LAW and App Insights inside the spoke, doubling cost and fragmenting telemetry in customers who already had a hub-managed LAW. v2.0.0 introduces `existingLogAnalyticsWorkspaceResourceId`, `existingApplicationInsightsResourceId`, and `existingApplicationInsightsConnectionString` (all nullable; empty default preserves v1.x behavior). When set, the spoke skips LAW / App Insights creation, and the derived locals (`_lawResourceId`, `_appInsightsResourceId`, `_appInsightsConnectionString`, `_appInsightsInstrumentationKey`) coalesce to the BYO values. App Configuration's `APPLICATIONINSIGHTS_*` keys, the Container Apps Environment `appLogsConfiguration.logAnalyticsConfiguration.customerId/sharedKey`, and AMPLS `linkedResourceId` all read from these derived locals. A new module `modules/ai-foundry/connection-application-insights.bicep` accepts the full BYO App Insights resource ID, parses subscription/RG/name segments, and uses an `existing` reference at the appropriate `scope: resourceGroup(subId, rgName)` so AI Foundry's own App Insights connection works across subscriptions/RGs. An advisory parameter `allowMixedObservabilityWorkspaces` (default `false`) and matching output `OBSERVABILITY_MIXED_WORKSPACES_ALLOWED` are reserved for the v2.1.0 pre-flight script — they document operator intent in v2.0.0 but do not enforce anything yet.
- **External egress via hub firewall / NVA** (Gap 6 in #58): when the platform team operates the egress firewall (Azure Firewall, Palo Alto VM-Series, etc.) in the hub, the spoke must not deploy its own. v2.0.0 introduces `hubIntegrationEgressNextHopIp` (the private IP of the external firewall/NVA) and `hubIntegrationExistingRouteTableResourceId` (optional, for Azure-Policy-managed RTs). The derivation chain `_hasExistingRouteTable / _hasExternalEgress / _createRouteTable / _effectiveRouteTableId / _createDefaultRoute / _defaultRouteNextHopIp` cleanly composes the four combinations: (a) spoke deploys its own RT + FW (v1.x default), (b) spoke deploys its own RT routing to external FW, (c) spoke uses BYO RT (RT managed externally), (d) spoke has no UDR (default Azure Internet routing). The route-table resource block is now gated on `_createRouteTable` so the empty (d) case adds no resources. All six workload subnets (agent, pe, jumpbox, acaEnvironment, devopsBuildAgents, plus the AzureBastionSubnet which is intentionally **never** routed through a UDR per Azure platform requirements) now reference `_effectiveRouteTableId`.
- **Spoke→hub VNet peering created by `main.bicep`** (Gap 7 in #58): when `hubIntegrationHubVnetResourceId` is set, `main.bicep` creates a `spokeToHubPeering` resource directly on the spoke VNet (no AVM module — the AVM `virtual-network` module's nested peering API doesn't expose `allowForwardedTraffic` cleanly). The peering uses `allowForwardedTraffic=true` (required for hub firewall return-traffic), and `allowGatewayTransit`/`useRemoteGateways` are parameter-driven via `hubIntegrationPeeringAllowGatewayTransit` (default `false`) and `hubIntegrationPeeringUseRemoteGateways` (default `false`). The opt-out is `hubIntegrationCreateHubPeering=false`, for environments where peering is established out-of-band by a platform-team workflow. The hub VNet ID is parsed at compile time to derive the hub VNet name for the peering remote reference (cross-subscription supported). The **reverse direction** (hub→spoke) is intentionally not created from the spoke deployment — the spoke deployment typically lacks write access to the hub RG. A new helper script `tests/scripts/Add-HubSpokePeering.ps1` automates the reverse-peering step from a workstation/runner that does have hub-RG write access.
- **`deploymentMode` topology preset enum** (Gap 8 in #58): a new `@allowed(['standalone', 'ailz-integrated'])` parameter (default `'standalone'`) captures the operator's topology intent in the deployment itself. Surfaced as a deployment tag `deploymentMode=<value>` plus a permanent `ai-lz-version=v2.0.0` tag merged into `_tags` via the new `_modeTags` derived local. The preset is **advisory** in v2.0.0 — it does not auto-flip any other flag. A future v2.x release may make it drive defaults (e.g., `ailz-integrated` could default `deployAzureFirewall=false` + `deployBastion=false`). Adds visibility in deployment history, audit logs, and downstream automation that needs to discriminate between the two topologies.

### Added — Tests & developer ergonomics

- **`scripts/Invoke-PreflightChecks.ps1` pre-flight validation script** (Gap 9 in #58): a read-only PowerShell 7 script that resolves the effective parameter set (azd env values layered over `main.parameters.json` `${VAR=default}` substitutions) and validates it before `azd provision` reaches Azure Resource Manager. Catches the class of mistakes that otherwise surface as deep, late, hard-to-debug ARM errors — `policyManagedPrivateDns=true` colliding with BYO `existingPrivateDnsZone*ResourceId` overrides; `hubIntegrationEgressNextHopIp` set alongside `hubIntegrationExistingRouteTableResourceId` (mutually exclusive); `existingApplicationInsightsResourceId` set without a matching connection string or LAW (without `allowMixedObservabilityWorkspaces=true`); spoke subnet prefixes outside the VNet address space or overlapping each other; Bastion / Firewall / PE / ACA-environment subnets below their Azure-platform minimum sizes; spoke VNet prefixes overlapping the hub VNet's prefixes (peering would fail); malformed `allowedIpRanges` entries; BYO VNet missing the configured subnet names when `deploySubnets=false`; missing `Microsoft.App/environments` delegation on a BYO ACA subnet; BYO Private DNS zone IDs pointing at zones with the wrong name; unreachable BYO LAW / App Insights / route table / Bastion / NAT Gateway resource IDs. Wired into a `preprovision` hook in `azure.yaml` so every `azd provision` runs it automatically — defensively coded so transient Azure-lookup failures (cross-subscription Reader missing, transient CLI errors) emit WARN findings rather than blocking the deployment; only deterministic parameter contradictions emit FAIL findings. Bypass via `PREFLIGHT_SKIP=true`, `-Skip`, or `-SkipAzureLookups` (CI/offline mode). Exit code contract: `0` = pass, `1` = fatal, `2` = warnings-only under `-Strict`. Submodule-consumer pattern: the script is also documented as a copy-paste snippet in `docs/v2-migration.md` for consumers running their own `preprovision` hook from a parent `azure.yaml`. Smoke tests in `tests/scripts/Invoke-PreflightChecks.Tests.ps1` (22 assertions, ~1s) cover every deterministic branch — including the IPv4 / CIDR math (pure PowerShell, no external dependencies).
- **`tests/hub/main.bicep` hub-simulation fixture** with VNet (10.100.0.0/16), Azure Firewall + Policy, Bastion (Standard SKU, `enableTunneling: true`), and a central Log Analytics workspace. Lets contributors validate hub-and-spoke topology changes end-to-end without standing up a real ALZ. Outputs are written to `tests/hub/.outputs.json` for consumption by spoke deployments.
- **`tests/scripts/Deploy-Hub.ps1`** PowerShell helper that wraps the hub deployment, captures outputs, and prints next-step commands.
- **`tests/scripts/Add-HubSpokePeering.ps1`** PowerShell helper that creates the reverse hub→spoke peering after a spoke deployment completes. Reads spoke VNet ID from `azd env get-values` (or explicit `-SpokeVnetResourceId`) and hub VNet ID from `tests/hub/.outputs.json` (or explicit `-HubVnetResourceId`). Forces `allowForwardedTraffic=true` so the hub firewall can return spoke traffic.
- **`scripts/Measure-MainJsonSize.ps1`** size-ratchet enforcement (warn at 3.5 MB, fail at 4.7 MB, ARM ceiling at 5.0 MB) and a corresponding **GitHub Actions workflow** that runs on every PR to prevent the compiled `main.json` from drifting toward the 5 MB ARM template hard limit. Current `v2.0.0` baseline is 4.615 MB.
- **`docs/v2-migration.md`** — upgrade guide for existing v1.x deployments, organized by parameter and broken into "what changed", "what to do", and "what's still v1.x".
- **`docs/runbook-hub-spoke.md`** — developer-friendly end-to-end walkthrough of the hub-and-spoke topology, including the exact commands used by the v2.0.0 team to validate `v2.0.0-dev` against a real Azure subscription.
- **`docs/runbook-standalone.md`** — simpler single-subscription walkthrough for the default `deploymentMode=standalone` scenario.

### Fixed

- **`${VAR=null}` env-var defaults emitted the literal string `"null"` into string-typed parameters**, breaking every `!empty(...)` guard downstream. Symptom on a real `azd provision` of `v2.0.0-dev`: the AVM `virtual-network` subnet deployment failed with `LinkedInvalidPropertyId: Property id 'null' at path 'properties.routeTable.id' is invalid` because `routeTableResourceId` was the string `"null"` instead of an empty/JSON-null value. Root cause: `azd` correctly converts the string `"null"` to JSON null only when the target Bicep parameter is non-string (e.g., `bool?`); for `string?` parameters it passes the literal string through. **Fix**: replaced `${VAR=null}` with `${VAR=}` (empty-string default) for all nullable string parameters in `main.parameters.json` — `existingJumpboxResourceId`, `existingBastionResourceId`, `existingNatGatewayResourceId`, `existingLogAnalyticsWorkspaceResourceId`, `existingApplicationInsightsResourceId`, `existingApplicationInsightsConnectionString`, the three `hubIntegration*` IDs, and all 15 `existingPrivateDnsZone*ResourceId` overrides. The four `bool?` parameters (`deployJumpbox`, `deployBastion`, `deployNatGateway`, `deployVM`) keep `=null` because `azd` handles them correctly.
- **Hardcoded `deploySearchService`, `deployStorageAccount`, `deployKeyVault`, `deployLogAnalytics`, `deployMcp`, `deployGroundingWithBing`, `deploySoftware`, `deployPostgres`, `greenFieldDeployment`, `speechServiceSku` parameter values in `main.parameters.json` silently ignored `azd env set` overrides**: operators trying to opt out of optional services (e.g., `azd env set DEPLOY_SEARCH_SERVICE false`) found their setting had no effect because the parameter file pinned the value. **Fix**: switched each of them to `${ENV_VAR=default}` substitution so env vars take effect as documented. Defaults are unchanged so v1.x deployments behave identically.

### Internal

- Branch: all v2.0.0 work landed on `v2.0.0-dev` and merged to `main` for the release tag.
- Build status: `az bicep build --file main.bicep` clean; warnings unchanged from v1.1.10 (pre-existing BCP318 / BCP037 / hardcoded env URL warnings, all expected).
- Compiled size: `main.json` 4.615 MB (≈87 KB under the 4.7 MB ratchet).
- Compatibility with the downstream consumer pattern (submodule + overlay `main.parameters.json`/`manifest.json` + `preprovision` hook) is preserved unchanged.

## [v1.1.10] - 2026-05-18

### Fixed
- **Cosmos DB provisioning no longer fails when the target region/subscription rejects Analytical Storage on account creation** (fixes #57): the workload Cosmos DB account in `main.bicep` hardcoded `enableAnalyticalStorage: true`, but Microsoft has tightened restrictions on enabling Synapse Link / Analytical Store during account creation in several region+subscription combinations (verified by issue reporter in `swedencentral` with `NETWORK_ISOLATION=true` on a fresh install — `azd provision` failed at `Microsoft.DocumentDB/databaseAccounts` with no operator opt-out short of forking the template). Reference: https://learn.microsoft.com/en-us/answers/questions/5888858/cosmos-not-able-to-enable-synapse-link. Same regression class as #47/#48/#50/#53 — a previously-safe default became platform-incompatible in a subset of subscriptions, with no parameter to override. **Fix**: new opt-in parameter `enableCosmosAnalyticalStorage` (default `false`, surfaced as `${ENABLE_COSMOS_ANALYTICAL_STORAGE=false}` in `main.parameters.json`); the `cosmosDBAccount` AVM module call now passes the parameter through instead of forcing `true`. This aligns the workload Cosmos with the AI Foundry submodule (`modules/ai-foundry/foundry/modules/cosmosDb.bicep`) which already defaults Analytical Store off, and with the fact that the default landing-zone topology does not deploy any Synapse Link or Fabric Mirroring consumer. **Behavior change**: new deployments default to Analytical Store **off**. Operators who actively consume the analytical store can set `ENABLE_COSMOS_ANALYTICAL_STORAGE=true` (via `azd env set` or by editing `main.parameters.json`) to preserve previous behavior, **provided the target region/subscription allows enabling Analytical Storage at account creation time**. **No-op for re-deployments**: Azure does not permit toggling Analytical Storage on an existing Cosmos DB account, so re-provisioning an existing landing zone against the same Cosmos account silently ignores the new default. No new resources, no schema change, no role assignment change, no breaking change for the parameter file (`main.parameters.json` ships with the new entry and a `false` default).

## [v1.1.9] - 2026-05-10

### Fixed
- **Jumpbox win-acme bootstrap no longer depends on GitHub release discovery** (fixes #55): `install.ps1` now downloads a pinned `win-acme.v2.2.9.1701.x64.trimmed.zip` release asset directly instead of querying `https://api.github.com/repos/win-acme/win-acme/releases/latest` and searching the returned asset list. This avoids Custom Script Extension failures where the GitHub API response is missing or does not expose the expected asset shape in locked-down / rate-limited bootstrap contexts, while keeping the install deterministic and non-interactive.

## [v1.1.8] - 2026-05-10

### Fixed
- **Jumpbox certificate workflow now has first-class ACME support under network isolation** (fixes #53): `install.ps1` now installs win-acme non-interactively from the latest `win-acme.*.x64.trimmed.zip` release asset, validates installation with `wacs.exe --version`, and fails loudly on bootstrap errors instead of silently continuing.
- **Firewall least-privilege allow-list now explicitly covers ACME issuance path for jumpbox** (fixes #53): `main.bicep` adds a dedicated jumpbox-scoped ACME FQDN group (`api.github.com`, `acme-v02.api.letsencrypt.org`) and a dedicated `AllowJumpboxAcme` application rule gated by `extendFirewallForJumpboxBootstrap`.
- **Jumpbox MI now has certificate import RBAC by default** (fixes #53): `main.bicep` adds `Key Vault Certificates Officer` to jumpbox Key Vault role assignments so certificate import and certificate lifecycle operations no longer require manual RBAC patching.

### Changed
- **README runbook is now provider-agnostic and explicitly split by operational boundary** (fixes #53): DNS operations stay on workstation/provider side, while ACME issuance/import and Azure-side steps are documented on the jumpbox side using built-in win-acme tooling.

## [v1.1.7] - 2026-05-10

### Fixed
- **Hub & Spoke with policy-managed Private DNS no longer emits `privateDnsZoneGroup: null` to AVM private-endpoint modules** (PR #51 follow-up): `modules/networking/private-endpoint.bicep` now routes through two explicit AVM module paths — one with `privateDnsZoneGroup` and one without that property — so policy-managed DNS scenarios omit the property entirely instead of sending a literal null.
- **AI Foundry account DNS-zone gating now requires the full 3-zone set before emitting DNS configs** (PR #51 follow-up): `modules/ai-foundry/foundry/main.bicep` now guards `privateDnsZoneResourceIds` and the Foundry account private-endpoint DNS zone group with the same complete check (`cognitiveServices`, `openAi`, `aiServices`) to prevent partial-input non-null assertions from breaking deployment.
- **AI Foundry associated-resource modules now omit PE DNS-zone groups when IDs are not provided** (PR #51 follow-up): `modules/ai-foundry/storage-account.bicep` and the Foundry submodules for Search, Cosmos DB, Key Vault, and Storage now build private endpoint objects without `privateDnsZoneGroup` unless a DNS zone ID is present, aligning runtime behavior with the policy-managed DNS model.

## [v1.1.6] - 2026-05-06

### Fixed
- **`AcsMediaRuleCollectionGroup` uses non-existent service tag `AzureCommunicationServices`** (fixes #50, regression of #45): the ACS / WebRTC media egress allow-list shipped in v1.1.5 (`enableAcsMediaEgress=true`) was inert in practice — the destination service tag `AzureCommunicationServices` does not exist in the Azure service-tag namespace (verified via `az network list-service-tags` against 1465 known tags), so the rule resolved to an **empty IP set** and Azure Firewall continued to drop all real TURN / Speech-avatar media traffic from spoke subnets. The actual real-time TURN backends (`relay.communication.microsoft.com`, `a-tr-skysc-*.<region>.cloudapp.azure.com`) resolve into IP ranges that are members of the **`AzureCloud`** / `AzureCloud.<region>` service tag, not a (non-existent) ACS-specific one. Symptom on consumer reference workload `Azure/live-voice-practice` (env `rg-paulolacerda-0507260028`, v1.1.6 / 1222a63 in `swedencentral`): avatar overlay stayed at "Getting your avatar ready"; `RTCPeerConnection.iceConnectionState` went `checking → failed`; `AzureDiagnostics` showed `Deny` against the ACS subnet→TURN UDP/3478 path. Patching the rule collection group's `destinationAddresses` to `['AzureCloud']` (ports unchanged: UDP 3478-3481, TCP 443+3478-3481) makes the avatar render end-to-end. **Fix**: in `firewallPolicyAcsMediaRuleCollectionGroup` (both the UDP and TCP rules), changed `destinationAddresses: ['AzureCommunicationServices']` to `destinationAddresses: ['AzureCloud']`. Source addresses, protocols, and ports are unchanged — the v1.1.5 acceptance criteria (UDP 3478-3481 / TCP 443+3478-3481 from the three spoke subnets, conditional on `networkIsolation && deployAzureFirewall && enableAcsMediaEgress`) still hold. Operators who previously had `enableAcsMediaEgress=true` in `main.parameters.json` and built around the broken rule with a postProvision shim (e.g. `Azure/live-voice-practice`'s `postProvision.ps1` PUTting the rule collection group with `AzureCloud`) can drop that shim once their landing-zone deployment is re-provisioned with v1.1.6. No schema change, no parameter change, no new resources; pure correctness fix in the existing opt-in rule.

### Added
- **Optional public ingress (Application Gateway WAF v2) in front of internal Container Apps environment** (closes #49): under `networkIsolation=true`, the landing-zone Container Apps environment is provisioned in **internal** mode and is unreachable from the public Internet. Workloads that need a controlled public entry point — testers, partner integrations, public demos — previously had to either roll their own gateway out-of-band (drift, no Bicep source of truth, no NSG/WAF guarantees) or punch holes in the internal topology. Both options moved security-critical configuration outside the template. **Fix**: new opt-in aggregate parameter `publicIngress` (default `{ enabled: false }`) in `main.bicep`, exported as `publicIngressType`. When `enabled=true` AND `networkIsolation` AND `deployContainerEnv` AND `containerAppsList` is non-empty, the new `modules/networking/public-ingress.bicep` deploys: a Standard zone-redundant Public IP; a dedicated user-assigned identity for the gateway; an `ApplicationGatewayWebApplicationFirewallPolicies` resource (OWASP CRS 3.2, mode `Prevention` by default, `wafCustomRules` merged in); and the Application Gateway WAF_v2 itself (autoscale 0..2, zones `[1,2,3]` when `useZoneRedundancy=true`, attached to the existing dedicated `AppGatewaySubnet` at `192.168.3.0/27`, backend pool resolved from `containerAppsList[publicIngress.backendAppIndex ?? 0].outputs.fqdn` over HTTPS:443 with `pickHostNameFromBackendAddress=true`, default `/` health probe, diagnostic settings to the landing-zone Log Analytics workspace). A new `modules/networking/appgw-nsg.bicep` is declared in `main.bicep` (not inside the public-ingress module — the subnet declaration must reference the NSG resource ID at creation time, so creating it inside the module would form a circular dependency) and is associated with the AGW subnet via the existing `networkSecurityGroupResourceId` plumbing. The NSG is **deny-all inbound** except `GatewayManager` (65200-65535) and `AzureLoadBalancer`; it adds an `AllowHttpsFromAllowedSources` rule on TCP/443 only when `publicIngress.allowedSourceAddressPrefixes` is non-empty — **port 80 is never opened from the Internet by this NSG**. The module models two operational states explicitly so that the operator-completed configuration is fully managed by Bicep (and therefore not overwritten by subsequent `azd up` runs — addressing the portal-drift trap that an earlier "skeleton-only with operator portal edits" design would have created): **skeleton mode** when either `sslCertSecretId` or `frontendHostName` is empty (gateway has only an HTTP:80 listener routed to the backend, NSG fully closed, gateway is inert); **live mode** when both are set (HTTPS:443 listener using the Key Vault certificate referenced by the versionless `sslCertSecretId`, HTTP:80 becomes an HTTP→HTTPS permanent redirect, NSG opens TCP/443 only from `allowedSourceAddressPrefixes`). The AGW UAI is granted `Key Vault Secrets User` (`4633458b-17de-408a-b874-0445c86b69e6`) on the landing-zone Key Vault when `deployKeyVault=true` so it can read the bootstrap cert; external Key Vaults must be granted manually using the new `PUBLIC_INGRESS_IDENTITY_PRINCIPAL_ID` output. Eight new outputs surface the gateway for downstream automation (`PUBLIC_INGRESS_*`) plus six landing-zone outputs that the module — and external consumers — depend on (`APP_GATEWAY_SUBNET_RESOURCE_ID`, `VNET_RESOURCE_ID`, `KEY_VAULT_RESOURCE_ID`, `KEY_VAULT_NAME`, `LOG_ANALYTICS_RESOURCE_ID`, `CONTAINER_APP_INTERNAL_FQDN`). **Important caveat documented in README and parameter description**: WAF_v2 + Standard PIP incur hourly charges even when idle, AND `azd`/ARM incremental deployments will NOT delete these resources when `publicIngress.enabled` flips back to `false` after a previous deploy — teardown is via `azd down` or manual deletion. No behavior change for deployments that don't opt in (the default `{ enabled: false }` keeps the entire stack inert and produces zero new resources).

## [v1.1.5] - 2026-05-05

### Fixed
- **Jumpbox SAMI cannot enumerate ARM resources under network isolation** (fixes #47): the jumpbox VM's System-Assigned Managed Identity was granted only **data-plane** roles (`App Configuration Data Owner`, `Search Service Contributor` + `Search Index Data Contributor`, `Cosmos DB Built-in Data Contributor`, `AcrPull`, `Container Apps Contributor`, …) but **no ARM control-plane role**, so `az resource list`, `az cosmosdb list`, `az containerapp list` etc. all returned `[]` from inside the VNet — even though the SAMI already had the data-plane RBAC needed for the actual operations. This silently broke every consumer postProvision / data-seed script that resolves resource names by ARM discovery when env vars / App Config values are missing or the script is being run interactively for troubleshooting (verified end-to-end against `Azure/live-voice-practice` v1.1.4: `postProvision.ps1` Cosmos seed used `az cosmosdb list` as a fallback resolution path, got `[]`, fell through to a hardcoded default DB name that did not match the actual provisioned name, and skipped the seed entirely). Same class of "discovery path silently empty" bug as #43, but at the ARM list layer rather than the data-plane authorization layer. **Fix**: prepended a single Reader role assignment to `_testVmRoles` in `main.bicep`, scoped to the **resource group** (empty `resourceId` => deployment scope, which is RG since `targetScope = 'resourceGroup'`). Reader is sufficient because the jumpbox already has the data-plane roles needed for the actual operations; the only gap was ARM enumeration. No new params, no schema change, no behavior change when `deployVM=false` or `networkIsolation=false` (the entire `_testVmRoles` block remains conditional on `deployVM && _networkIsolation`). Removes the documented App-Config-only-resolution workaround for consumer postProvision scripts.

- **Jumpbox bootstrap Python 3.11 silent install produces a broken interpreter** (fixes #48): the `python311` Chocolatey package consistently produced an inert install on the Windows Server 2022 jumpbox image — only `python.exe` and `pythonw.exe` ended up under `C:\Python311`, while `Lib\encodings`, `python311.dll`, and the rest of the standard library were missing. Running `python --version` after provisioning errored out with `Fatal Python error: init_fs_encoding: failed to get the Python codec of the filesystem encoding`. Reinstalling via the same MSI returned exit `1603` because the broken install was still registered, and there was no clean uninstall path. This silently broke every consumer postProvision script that depends on Python on the jumpbox (the canonical Azure data-plane SDKs `azure-cosmos`, `azure-search-documents`, `azure-identity` are Python-first), forcing each consumer to either detect-and-self-heal or rewrite seeds in PowerShell + REST. **Fix**: removed `python311` from the Chocolatey install list and replaced it with the official **embeddable distribution** (`python-3.11.9-embed-amd64.zip` from `www.python.org`) extracted to `C:\Python311`. The embeddable zip is hermetic (no MSI state, no installer, just unzip), always ships the full standard library + `python311.dll`, and is reproducible across reboots. The `install.ps1` script then patches `python311._pth` to enable site-packages (uncomments `import site`) and bootstraps pip via `get-pip.py` from `bootstrap.pypa.io`, after which `pip install` writes into `Lib\site-packages` like a normal installation. Both `C:\Python311` and `C:\Python311\Scripts` are added to MACHINE PATH. The Azure Firewall application-rule allow-list `_firewallDevRuntimeFqdns` (consumed by `AllowJumpboxDevRuntimes`) was extended with `bootstrap.pypa.io` + `*.pypa.io` so the new install path works end-to-end under Zero Trust egress lockdown. The integrity check (`python --version` + `get-pip.py` exit-code assertion) runs inline in the bootstrap so the next CSE run surfaces a hard failure rather than a silently broken interpreter. Verified end-to-end on a fresh `swedencentral` deployment: `python --version`, `pip --version`, and `pip install azure-cosmos azure-identity` all succeed from a cold-start jumpbox.

### Added
- **Optional ACS / WebRTC media egress allow-list for Azure Firewall** (fixes #45): under `networkIsolation=true` + `deployAzureFirewall=true`, every workload that uses **Azure Speech real-time avatar**, **Azure Communication Services Calling/Audio/Video**, or **Microsoft Teams Media** (WebRTC peer connections, STUN/TURN ICE candidates) was blocked by Azure Firewall — the *control* plane is HTTPS (already covered by application rules) but the *media* plane uses **UDP 3478-3481** and **TCP 443/3478-3481** to the `AzureCommunicationServices` Service Tag, which is otherwise dropped under Zero Trust egress lockdown. Verified end-to-end against `Azure/live-voice-practice` v1.1.4 in `swedencentral`: WebRTC ICE handshake from the Container App to the avatar relay failed with consistent UDP 3478 timeouts; `AzureDiagnostics` showed `Deny` against destination `AzureCommunicationServices` ServiceTag from the ACA subnet. Same class of incomplete-allow-list issue as #39/#40/#42 but on the network-rule side rather than application-rule side. **Fix**: new opt-in parameter `enableAcsMediaEgress` (default `false`, surfaced as `${ENABLE_ACS_MEDIA_EGRESS=false}` in `main.parameters.json`). When `true` *and* `deployAzureFirewall=true` *and* `networkIsolation=true`, a new `AcsMediaRuleCollectionGroup` (priority 300, sequenced after the default group via explicit `dependsOn` to avoid CG-update races) is added to the Firewall Policy with a single `AllowAcsMedia` filter collection containing two NetworkRules: `AllowAcsMediaUdp` (UDP 3478-3481) and `AllowAcsMediaTcp` (TCP 443, 3478-3481). Source addresses are the three spoke subnets that can host workloads (`jumpboxSubnetPrefix`, `acaEnvironmentSubnetPrefix`, `agentSubnetPrefix`); destination is the `AzureCommunicationServices` Service Tag. Off by default to preserve least-privilege egress for consumers that don't use ACS/WebRTC. No change for deployments that don't opt in; no change when `deployAzureFirewall=false` or `networkIsolation=false` (the rule collection group is conditional). Restored avatar/ACS calls end-to-end on the verified repro.

- **Bastion SKU + native-client tunneling parameters** (fixes #46): the Bastion host was hard-coded to `Standard` SKU with no way to enable native-client tunneling, so consumers running `az network bastion rdp` / `az network bastion ssh` from outside the VNet (a documented operator path in the Zero Trust topology), or needing **RDP audio / clipboard / device redirection**, **SSH agent forwarding**, or the **Premium**-only features (shareable link, session recording, private-only Bastion) had to either edit the template, switch to portal-only Bastion (lose native client), or post-deploy `az network bastion update` (out-of-band drift). **Fix**: two new opt-in parameters surfaced as `${BASTION_SKU_NAME=Standard}` and `${BASTION_ENABLE_TUNNELING=false}` in `main.parameters.json`. `bastionSkuName` (allowed: `Basic`, `Standard`, `Premium`; default `Standard`) controls the Bastion SKU; `bastionEnableTunneling` (default `false`) enables native-client tunneling and is silently coerced to `false` when `bastionSkuName == 'Basic'` (Basic does not support tunneling) so the deployment never fails on an invalid SKU/feature combination — operators get a working Bastion either way. Implementation note: the AVM `bastion-host` module up to 0.8.2 does **not** expose `enableTunneling`, so the AVM module call was replaced with a behavior-equivalent raw `Microsoft.Network/bastionHosts@2024-07-01` resource (same `AzureBastionSubnet`, same Standard static PIP, same zone-redundancy behavior, same dependsOn graph) plus an explicit `Microsoft.Network/publicIPAddresses` for the Bastion PIP; this also keeps the door open for additional Bastion-side knobs without waiting on AVM. No behavior change for deployments that don't override the new parameters (default Standard SKU, tunneling off — matches v1.1.4 behavior). No new outputs, no consumer-side breaking change.

## [v1.1.4] - 2026-04-30

### Fixed
- **Cosmos DB Built-in Data Contributor scope too narrow (database vs account) for jumpbox + Container App** (fixes #43): all three `assignCosmosDBCosmosDbBuiltInDataContributor*` modules in `main.bicep` (TestVm at L1337, Executor at L2609, per-app Container App loop at L2795) hard-coded `scopePath` to a single database (`/databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}`). This worked only when consumers used the template-default `dbDatabaseName`; it broke the moment a consumer created an additional database on the same Cosmos account (multi-tenant scenarios, integration-test DBs, feature isolation), renamed `dbDatabaseName` after deployment, or wanted the jumpbox / Container App to administer multiple application DBs — every Cosmos SDK call against the non-default DB returned `403 Forbidden` even though the principal already had `Cosmos DB Built-in Data Contributor`. Inconsistent with the other built-in data-plane role assignments in the template (App Configuration Data Owner is scoped to the App Config store, Search Index Data Contributor is scoped to the Search service — both account/resource-level, not child-level), and inconsistent with the "jumpbox is an admin host inside the VNet" + "Container App is the data-plane owner" intent already encoded for App Config / Search. **Fix**: widened `scopePath` at all three call sites from `.../databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}` to `.../databaseAccounts/${dbAccountName}`, so `Cosmos DB Built-in Data Contributor` now applies to every database under the account. No new params, no schema change to the `sqlRoleAssignments`, and no behavior change when `deployCosmosDb=false` (the entire block remains conditional). Verified end-to-end against `Azure/live-voice-practice` v1.1.4: post-provision Cosmos seed runs cleanly from the jumpbox against a consumer-created database without manual RBAC top-up.

- **Firewall allow-list missing certificate revocation FQDNs (OCSP/CRL/CTL)— Schannel/curl on the jumpbox fails `CRYPT_E_REVOCATION_OFFLINE`** (fixes #42): the `AllowContainerAppsPlatform` rule (introduced in #39 and extended in #40) was still missing the **certificate revocation** FQDNs that Windows TLS clients (Bastion/jumpbox VMs, `az` CLI on Windows, `curl.exe` Schannel, `Invoke-WebRequest`, .NET `HttpClient` with `CheckCertificateRevocationList=true`) hit when validating Azure-managed TLS certificates served by Container Apps / App Service / etc. Under `flagEnableNetworkSecurity=true` + `enableEgressLockdown=true`, every HTTPS call from the jumpbox into the spoke failed with `schannel: CRYPT_E_REVOCATION_OFFLINE` / Schannel handshake errors — forcing every doc/sample that says "test the API from the jumpbox" to make users discover `--ssl-no-revoke` (curl) or disable `CheckCertificateRevocationList` (.NET) themselves, both of which are workarounds rather than fixes. Verified via `AzureDiagnostics` on a fresh `v1.1.4` deployment in `swedencentral`: top denied FQDNs in the `AzureFirewallApplicationRule` `Deny` log were `ctldl.windowsupdate.com` (Windows trusted root CTL auto-update), `oneocsp.microsoft.com` (Microsoft OCSP responder), `crl2.microsoft.com` (Microsoft CRL distribution point), `ocsp.digicert.com` (DigiCert OCSP responder), and `crl3.digicert.com` (DigiCert CRL distribution point). Same class of incomplete-allow-list issue as #39/#40. **Fix**: appended nine public Microsoft + DigiCert revocation endpoints to `_firewallEssentialPlatformFqdns` (consumed by the existing `AllowContainerAppsPlatform` rule introduced in #39, no schema change to the rule collection group): `oneocsp.microsoft.com`, `ocsp.digicert.com`, `crl.microsoft.com`, `crl2.microsoft.com`, `crl3.microsoft.com`, `crl.digicert.com`, `crl3.digicert.com`, `crl4.digicert.com`, `ctldl.windowsupdate.com`. These are implicit dependencies of any Azure-issued cert chain, so allowing them in an outbound rule does not weaken the Zero Trust posture. Removes the documented `--ssl-no-revoke` / `CheckCertificateRevocationList=false` workarounds for the Windows jumpbox runbook.

- **Container Apps managed identity still fails after the #39 fix — missing `*.identity.azure.net` in firewall allow-list** (fixes #40, follow-up to #39): #39 unblocked the Service Bus / Event Hub leg of the ACA per-pod IMDS path (`gsm*eh.servicebus.windows.net`), but the same flow also opens a direct connection from the workload subnet to `control-{region}.identity.azure.net` (the IMDS token endpoint). That FQDN was still not in the v1.1.4 allow-list, so under `flagEnableNetworkSecurity=true` + `enableEgressLockdown=true` the IMDS sidecar continued to return `HTTP 500` "An unexpected error occured while fetching the AAD Token" and every `DefaultAzureCredential` / `ManagedIdentityCredential` consumer (App Configuration, Cosmos DB, AI Search, Key Vault, Storage, Speech, …) still failed at runtime exactly as in #39 — verified end-to-end in `swedencentral` with `AzureDiagnostics` showing `Deny` against `control-swedencentral.identity.azure.net:443` from the workload subnet. Azure Firewall application-rule wildcards only match a single label, so the existing `*.azure.com` did **not** cover `control-swedencentral.identity.azure.net`. **Fix**: added `*.identity.azure.net` to `_firewallEssentialPlatformFqdns` (the same allow-list and `AllowContainerAppsPlatform` rule introduced in #39). Adding this single FQDN to the rule and bouncing the Container App revision restored MI token issuance immediately in the verified repro environment. Both legs (Service Bus broker + identity.azure.net token endpoint) of the ACA IMDS path are now in the platform allow-list.
- **`ReferencedResourceNotProvisioned` race on the shared `pe-subnet` during parallel Private Endpoint provisioning** (fixes #41): under `flagEnableNetworkSecurity=true`, three independent groups created Private Endpoints against the same `pe-subnet` in parallel — (a) the `privateEndpoints` aggregator (10 PEs for Storage / Cosmos / AI Search / Key Vault / App Configuration / Container Apps Environment / Container Registry / Speech, already serialized internally via `@batchSize(1)` in `modules/networking/private-endpoints.bicep`); (b) the inline blob PE created by `aiFoundryStorageAccount` via the AVM `storage-account` module's `privateEndpoints` parameter; (c) the AI Foundry AVM module's internal cog-svc PEs created via its `privateEndpointSubnetResourceId` parameter. With no `dependsOn` chain between the three groups, ARM scheduled their PE NIC operations concurrently and the second NIC arriving while the subnet was still reconciling for a sibling PE NIC failed with `Code: ReferencedResourceNotProvisioned, Message: Cannot proceed with operation because resource /subnets/pe-subnet used by resource <pe>-nic is not in Succeeded state. Resource is in Updating state…`. Reproduced ~1-in-3 cold deploys (e.g. `aiFoundryStorage-staifcl6kw7v4sid3w` failing on `pe-staifcl6kw7v4sid3w-blob`); re-running `azd provision` always succeeded because the failed PE retried against a now-stable subnet — confirming a pure scheduling race, not an authentic dependency problem. Same class of bug as #19 / #25 / #26 but on the shared `pe-subnet` for the rest of the data-plane services rather than AI Foundry-specific. **Fix**: explicit `dependsOn: [privateEndpoints]` (gated on `_networkIsolation`) added to both `aiFoundryStorageAccount` and `aiFoundry`, linearizing the three PE waves: aggregator (already `@batchSize(1)`) → AI Foundry storage's inline blob PE → AI Foundry's internal cog-svc PEs. Same pattern already used for `privateEndpointAmpls` ("Serialize PE operations to avoid conflicts"). No circular dependency: neither the aggregator's `_peList` entries nor any module it pulls outputs from reference `aiFoundryStorageAccount` or `aiFoundry`. Provision-time impact is negligible (PE creation is fast and the aggregator's PEs were already serial); cold-deploy first-time-success rate goes from ~67% to deterministic.

- **Container Apps `DefaultAzureCredential` / `ManagedIdentityCredential` fails at runtime under network isolation when egress is forced through Azure Firewall — missing platform FQDNs** (fixes #39): with `flagEnableNetworkSecurity=true` and `enableEgressLockdown=true`, every workload in the Container Apps Environment lost the ability to fetch managed-identity tokens. Calls to the per-pod IMDS endpoint (`http://localhost:42356/metadata/identity/oauth2/token`, exposed via `IDENTITY_ENDPOINT` / `IDENTITY_HEADER`) returned `HTTP 500` with `"An unexpected error occured while fetching the AAD Token"`, breaking every downstream call that uses `DefaultAzureCredential` / `ManagedIdentityCredential` (App Configuration, Cosmos DB, AI Search, Key Vault, Storage, Speech, …). The container itself could reach `login.microsoftonline.com` (already in `_firewallEssentialAuthFqdns`), so the failure was on the ACA platform's internal token-fetch path, not the AAD client side. **Root cause**: the per-pod IMDS sidecar does not call AAD directly — it proxies the request through a Microsoft-managed Service Bus / Event Hub namespace whose FQDN matches `gsm*eh.servicebus.windows.net`. With the workload subnet forced through Azure Firewall via UDR (the AAILZ default under network isolation), every IMDS request tried to open a TLS connection to that hostname and the `DefaultRuleCollectionGroup` did not allow `*.servicebus.windows.net`. Azure Firewall application-rule wildcards only match a single label, so the existing `*.windows.net` did **not** cover `gsm123eh.servicebus.windows.net`. The failure was silent end-to-end: `azd provision` exited 0 (firewall block manifested only at runtime), the IMDS sidecar swallowed the underlying error, and there was no log entry on the workload side indicating the firewall was the cause — debugging required `AzureDiagnostics` access and knowledge that ACA's IMDS uses Service Bus internally. **Fix**: introduced a new `_firewallEssentialPlatformFqdns` allow-list and a new `AllowContainerAppsPlatform` rule on the existing `DefaultRuleCollectionGroup` (sourceAddresses=`*`, same shape as `AllowEntraIdAuth`/`AllowMicrosoftContainerRegistry`), covering the ACA per-pod IMDS path (`*.servicebus.windows.net`), the ACA control plane / ingress (`*.azurecontainerapps.io`, `*.azurecontainerapps.dev`), and the Azure Monitor / Log Analytics / Application Insights ingestion endpoints used by the platform's diagnostics pipeline (`*.in.applicationinsights.azure.com`, `*.livediagnostics.monitor.azure.com`, `*.ingest.monitor.azure.com`, `*.monitor.azure.com`, `*.monitor.core.windows.net`, `*.opinsights.azure.com`, `*.loganalytics.io`). All additive on the existing rule collection group; no behavior change for `networkIsolation=false` (the entire group is conditional on `deployAzureFirewall && _networkIsolation`). Removes the need for the `postProvision`-hook RCG workaround.

- **Empty `AZURE_CLIENT_ID` env var breaks `DefaultAzureCredential` on Container Apps with SystemAssigned identity** (fixes #38): the Container App `containers[].env` block always emitted `AZURE_CLIENT_ID`, falling back to an **empty string** when the deployment used SystemAssigned managed identity (`_useUAI = false`). An empty `AZURE_CLIENT_ID` combined with a populated `AZURE_TENANT_ID` confused the Azure Identity SDKs (`azure-identity` Python, `Azure.Identity` .NET, etc.): `EnvironmentCredential` sees both vars and tries to authenticate, fails on the empty `client_id`; `ManagedIdentityCredential` then attempts to use the empty `client_id` against the Container Apps IMDS proxy, which responds with `HTTP 500 invalid_scope` ("App Service managed identity configuration not found in environment"). Net effect: `DefaultAzureCredential` failed completely at startup — App Configuration, Cosmos DB, AI Search, etc. were unreachable even though the SystemAssigned MI was correctly created and granted RBAC roles. The Container App appeared `Healthy` (process up) but every Azure SDK call failed, manifesting as silent feature degradation rather than a hard failure. **Fix**: `containers[].env` now uses `concat(...)` to inject `AZURE_CLIENT_ID` **only when `_useUAI=true`**. With the var omitted on the SystemAssigned path, `ManagedIdentityCredential` picks up the platform-injected `IDENTITY_ENDPOINT` / `IDENTITY_HEADER` and uses the SystemAssigned MI correctly. UAI path is unchanged: `AZURE_CLIENT_ID` is still emitted with `containerAppsUAI[index].properties.clientId`. Removes the documented workaround (`az containerapp update --remove-env-vars AZURE_CLIENT_ID AZURE_TENANT_ID`).
- **`AllowJumpboxBootstrap` firewall rule missing `downloads.bicep.azure.com` — `azd` cannot bootstrap on the jumpbox under network isolation** (fixes #36): with `networkIsolation=true` and the default `extendFirewallForJumpboxBootstrap=true`, the documented runbook is to RDP into the jumpbox via Bastion and run `azd env refresh` / `azd provision` / `azd deploy` from inside the VNet. On a fresh jumpbox `azd` always failed at the very first step with `(x) Failed: Downloading Bicep`, because `azd` auto-downloads the Bicep CLI binary from `https://downloads.bicep.azure.com/...` on first run and that FQDN was not in `_firewallVmBootstrapFqdns` — the existing entries only covered Chocolatey, NuGet, VS downloads, `aka.ms`, `go.microsoft.com`, `*.core.windows.net`, `*.azureedge.net`. Azure Firewall blocked the request and the bootstrap failed before any Bicep work could happen, biting every consumer that follows the documented "run azd from the jumpbox" pattern. **Fix**: added `downloads.bicep.azure.com` to `_firewallVmBootstrapFqdns`, plus the GitHub release-fallback hosts that are also commonly required by `azd`, the .NET installer, and AILZ-derived bootstrap scripts — `github.com`, `*.githubusercontent.com`, `objects.githubusercontent.com` (release asset CDN), and `codeload.github.com` (source-archive host). All additive on the existing opt-in `AllowJumpboxBootstrap` rule (sourceAddresses = jumpboxSubnetPrefix), so no new public network exposure when `extendFirewallForJumpboxBootstrap=false` or `networkIsolation=false`. Removes the need for the documented workarounds (`AZURE_DEV_USE_INSTALLED_BICEP=true` + manual `winget install Microsoft.Bicep`, or a custom `RuleCollectionGroup` via portal/CLI/script).

### Added
- **First-class Azure AI Speech support, gated by `deploySpeechService`** (closes #35): adds an optional `Microsoft.CognitiveServices/accounts` resource of `kind: 'SpeechServices'` to the landing zone, deployed via `br/public:avm/res/cognitive-services/account:0.13.2` (same module family already used by the AI Foundry account, so no new template dependency is introduced). Default is `false` — no behavior change for existing environments. New parameters: `deploySpeechService` (bool, default `false`), `speechServiceLocation` (string; falls back to `location` when empty), `speechServiceSku` (`'F0' | 'S0'`, default `'S0'`), and `speechServiceName` (defaults to `${abbrs.ai.speechService}${resourceToken}` → `spch-<token>`; the abbreviation already exists in `constants/abbreviations.json`). The account is created with system-assigned managed identity, `customSubDomainName == name` (required for AAD auth and PE-only access), `publicNetworkAccess: 'Disabled'` under network isolation, and AVM-shaped `diagnosticSettings` to the Log Analytics workspace when `deployLogAnalytics`.
- **Speech private endpoint reuses the existing `privatelink.cognitiveservices.azure.com` zone** (#35): the Speech account is wired into the central `_peList` aggregator with `groupIds: ['account']` (the canonical PE sub-resource for `Microsoft.CognitiveServices/accounts`, regardless of `kind`), and routed through the existing `_dnsZoneCogSvcsId` (the same private DNS zone already created and VNet-linked for the AI Foundry account). No new private DNS zone, no duplicate zone link, no extra deploymentScript — fully declarative and consistent with the v1.1.3 zero-script posture. The `privateEndpoints` aggregator's `dependsOn` was extended to include `speechService!` so PE creation is serialized after the cog-svc parent reaches `Succeeded` (same pattern that fixes #26/#29).
- **Speech RBAC: `containerAppsList[].roles` integration + executor + jumpbox VM** (#35): a new per-app role-assignment loop (`assignSpeechCognitiveServicesUser-${app.service_name}`) grants `Cognitive Services User` on the Speech account whenever a container app declares the existing `CognitiveServicesUser` role token AND `deploySpeechService=true`. Reuses the existing `roles.json` token instead of introducing a new `CognitiveServicesSpeechUser` token, so consuming repos that already grant Speech via `containerAppsList[].roles` need no parameter changes. The deployment principal (executor) is granted `Cognitive Services Contributor` + `Cognitive Services User`, and the test/jumpbox VM MSI is granted the same pair, so `azd provision` and post-provision smoke tests can call the Speech control plane and the data plane.
- **App Configuration runtime keys for Speech** (#35): when `deployAppConfig && !networkIsolation && deploySpeechService`, the following keys are populated for downstream apps to consume — `AZURE_SPEECH_RESOURCE_ID`, `AZURE_SPEECH_RESOURCE_NAME`, `AZURE_SPEECH_REGION`, `AZURE_SPEECH_ENDPOINT`. `DEPLOY_SPEECH_SERVICE` is always populated as `string(deploySpeechService)` for feature-detection. All values fall back to `''` when the feature is disabled, matching the existing AI Foundry / Search pattern.
- **Bicep outputs for Speech** (#35): `AZURE_SPEECH_RESOURCE_ID`, `AZURE_SPEECH_ENDPOINT`, `AZURE_SPEECH_REGION`, `AZURE_SPEECH_RESOURCE_NAME`, and `DEPLOY_SPEECH_SERVICE`. Empty strings when `deploySpeechService=false`. Allows derived accelerators consuming this repo as a submodule to wire Speech into their own templates without duplicating the AVM call.
- **Firewall: Speech FQDNs added to `AllowJumpboxBootstrap`** (#35): when `deploySpeechService` is true, `*.cognitiveservices.azure.com`, `*.tts.speech.microsoft.com`, and `*.stt.speech.microsoft.com` are concatenated into the `AllowJumpboxBootstrap` rule's `targetFqdns` (only if `extendFirewallForJumpboxBootstrap` is also true — opt-in remains opt-in). Lets the jumpbox / test VM reach the Speech control plane and TTS/STT regional endpoints under network isolation, mirroring how the existing PaaS endpoints are allow-listed.

## [v1.1.3] - 2026-04-28

### Fixed
- **`install.ps1`: `$env:GIT_CONFIG_VALUE_0 = ''` deletes the variable on Windows, breaking every clone** (fixes #34): the `Invoke-GitCloneWithTimeout` hardening from #33 attempted to disable Git Credential Manager via Git's `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n` env-var protocol. On Windows PowerShell, however, `$env:VAR = ''` is implemented by the `Environment:` provider as a **delete**, not as an empty-string assignment — `[Environment]::GetEnvironmentVariable('GIT_CONFIG_VALUE_0','Process')` returns `$null` after the assignment. So the `Start-Job` child handed git `COUNT=1` and `KEY_0=credential.helper` but no `VALUE_0` at all, and git aborted before any network I/O with `error: missing config value GIT_CONFIG_VALUE_0` and `LASTEXITCODE=128`. The bootstrap then threw `Failed to clone Bicep PTN AIML Landing Zone repo` and `azd provision` rolled back. Reproduced end-to-end on the NI cold-start path: 31 of 33 resources provisioned cleanly, only the jumpbox CSE failed, and it failed at the very first clone attempt. **Fix**: drop the `GIT_CONFIG_*` env-var protocol entirely and pass `-c credential.helper=` directly on the `git` command line — `git -c key=` semantically sets an empty value for the given key for that one invocation, is portable, and avoids the Windows `$env:VAR = ''` footgun. Removes three env vars and the platform-specific behavior from the helper.
- **`install.ps1`: `Invoke-GitCloneWithTimeout` regresses AILZ self-clone on NI cold start** (fixes #33): the `Invoke-GitCloneWithTimeout` helper introduced in v1.1.3 (#32) regressed the post-deploy CSE on cold-start network-isolated jumpboxes — `azd provision` would succeed for every Azure resource (KV, ACR, Cosmos, Search, AI Foundry account/project/model deployments/connections, CAE, container app, all PEs) and then fail in the jumpbox CSE on the AILZ self-clone, rolling back the deployment. Three combined defects: **(A)** `Start-Job` spawns a child `powershell.exe` with no console handle, but Git Credential Manager (shipped with `git for windows` via choco) is enabled by default and stalls on credential discovery prompts that never resolve without a TTY — wall-clock fires after 600 s and the helper throws. **(B)** `GIT_HTTP_LOW_SPEED_TIME=60` was too aggressive: libcurl's `CURLOPT_LOW_SPEED_TIME` starts before TLS handshake completes, and on a freshly booted Windows VM with Defender + AntiMalware initial scans concurrent with the post-choco cooldown, the first HTTPS-to-`github.com` (DNS + TCP + TLS + first byte) can plausibly exceed 60 s, causing `CURLE_OPERATION_TIMEDOUT` (curl 28) → git exit 128. **(C)** The helper read `$job.ChildJobs[0].JobStateInfo.Reason` for the exit code, but `JobStateInfo.Reason` is only populated when the job state is `Failed` (terminating exception in the script block). For `git clone; exit 128`, the script block ends normally and the state stays `Completed` — so the helper reported `LASTEXITCODE = 0` even when git itself failed, silently letting future genuine clone failures pass through. **Fix**: (1) inside the `Start-Job` child, set `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=Never`, and disable Git Credential Manager via `git -c credential.helper=` on the command line (originally via `GIT_CONFIG_*` env vars, replaced by the `-c` flag in #34); (2) loosen timeouts to `LOW_SPEED_TIME=180 s` and wall clock `900 s` so cold-start TLS isn't killed; (3) capture the real git exit code via a `__GIT_EXIT__:N` sentinel line in the job's output stream, with a `.git` directory existence fallback; (4) add **one** automatic retry with a 15 s back-off — covers single transient failures without becoming an infinite retry loop. Preserves #32's intent (bound git clones with a wall-clock timeout, no infinite retries).
- **`install.ps1`: extra-repo `git clone` has no timeout — can hang CSE indefinitely** (fixes #32): a plain `git clone` over HTTPS has no upper bound on idle/zombie connections, so a single hanging clone keeps CSE in `Transitioning` for hours. Because the Azure VM Guest Agent serializes Run-Command requests behind a busy CSE, the entire VM operation queue freezes — operators cannot remediate via `az vm run-command invoke` until the VM is restarted. Reproduced on `v1.1.3` (`f823a46`) Sweden Central where a public-repo clone (`live-voice-practice`) hung over 1 h on `Cloning into 'C:\github\live-voice-practice'...` while CSE remained `Transitioning`. **Fix**: introduced `Invoke-GitCloneWithTimeout` helper that wraps `git clone` in a `Start-Job` with a hard wall-clock cap (`Wait-Job -Timeout`) and aborts half-open HTTPS connections via `GIT_HTTP_LOW_SPEED_LIMIT` / `GIT_HTTP_LOW_SPEED_TIME` (the actual observed failure mode). Applied to all three clone sites: the main `bicep-ptn-aiml-landing-zone` clone (treated as fatal — bootstrap throws if it fails), the `manifest.json#components` clones, and the `ExtraRepoUrls` clones (both treated as warnings — a single bad URL never wedges the bootstrap; partial clone directories are cleaned up so a subsequent run is not confused by a half-baked working tree). Convention: timeout maps to `LASTEXITCODE = 124`. (Helper hardened in #33 — see entry above.)
- **`install.ps1`: parallel choco installs race on `chocolatey-compatibility.extension`** (fixes #31): the parallelization from #24 caused two distinct races. #30 fixed the MSI mutex contention with retry-on-1618. A second race remained — Chocolatey-internal file-locking on `C:\ProgramData\chocolatey\lib\chocolatey-compatibility.extension\.chocolateyPending` (and similarly `chocolatey-core.extension`) when two jobs concurrently auto-pull the same dependency package — surfaces as `Access to the path '...\.chocolateyPending' is denied.` with choco exiting **1**, not 1618, so the `Invoke-ChocoWithRetry` 1618 detection bypasses it and the affected package (e.g. `powershell-core`) is silently dropped. **Fix**: stop parallelizing `choco install`/`upgrade` altogether — Chocolatey is not designed for concurrent invocations on the same machine. The six installs now run in a sequential `foreach` loop, still through `Invoke-ChocoWithRetry` so genuine MSI 1618 contention from unrelated installers (e.g. Azure Update Manager running concurrently with CSE) remains handled. Wall-time cost vs parallel: ~30–60 s, dominated anyway by Defender, antimalware, AZD-MSI download and the post-CSE reboot. Removes an entire class of races without giving up the 1618 protection from #30.
- **`install.ps1`: MSI mutex contention from parallelized choco installs** (fixes #30; superseded by #31 fix above which serializes choco entirely): retry-on-1618 helper retained but its parallel-Start-Job harness was replaced by a sequential loop, so MSI mutex contention now only occurs against unrelated host processes (e.g. Azure Update Manager) rather than self-inflicted via parallel jobs.
- **AI Foundry private endpoint race — final declarative fix via cog-svc child-resource gate** (fixes #29, supersedes the v1.1.3 deploymentScript wait, fixes #26, supersedes #19/#25 workaround, tracks upstream [Azure/bicep-registry-modules#5957](https://github.com/Azure/bicep-registry-modules/issues/5957)): the initial v1.1.3 fix used a `Microsoft.Resources/deploymentScripts` (AzurePowerShell) to poll `Get-AzCognitiveServicesAccount` until `provisioningState == Succeeded`. Issue #29 reported that this is structurally incompatible with the built-in Azure Policy `Storage accounts should prevent shared key access` (`8c6a50c6-9ffd-4ae7-986f-5fa6111f9a54`) — `deploymentScripts` requires a backing storage account with `allowSharedKeyAccess: true` (used by the ACI sidecar to mount Azure Files via SMB), and the policy modifies any new storage account at creation to `allowSharedKeyAccess: false`, causing `KeyBasedAuthenticationNotPermitted` failures. Granting RBAC to the runner identity does not help; passing a user-supplied storage account does not help — the same policy applies. **Root cause (unchanged)**: `Microsoft.CognitiveServices/accounts` `PUT` returns HTTP 200 synchronously with `provisioningState: Accepted` and transitions to `Succeeded` asynchronously **without** a real LRO, so any dependent private endpoint runs while the parent is still in `Accepted`. **Final fix**: replaced the deploymentScript wait with a fully declarative gate on a cog-svc child resource. Empirical evidence from #29's repro confirms the cog-svc resource provider serializes child-resource creation against the parent `provisioningState` server-side — model deployments, projects and capability hosts all reached `Succeeded` in v1.1.3 even while the wait script failed. Therefore the private endpoint can `dependsOn` the existing `foundryProject` module (which creates `Microsoft.CognitiveServices/accounts/projects/{name}`); by the time `foundryProject` completes, the parent account is in `Succeeded` and the PE PUT is safe. The PE was moved out of `modules/ai-foundry/foundry/modules/account.bicep` and is now declared in `modules/ai-foundry/foundry/main.bicep` after `foundryProject`, with `dependsOn: [foundryProject]`. The user-assigned identity, `Reader` role assignment, and deploymentScript were removed entirely — no scripts, no extra storage account, no shared-key dependency, no policy exceptions required. Works in subscriptions enforcing `Storage accounts should prevent shared key access` and any equivalent corporate landing-zone policies. Gated on `privateNetworkingEnabled`, so non-isolated deploys are unchanged.

### Changed
- **Module reference for AI Foundry**: `modules/ai-foundry/main.bicep` references `./foundry/main.bicep` (the in-repo customized derivation) instead of the public AVM registry. The `foundry/` tree mirrors `avm/ptn/ai-ml/ai-foundry@0.6.0` at SHA `55178238674d0fc99dda39ac40d24bfebc4f5e0e` except for `modules/account.bicep` (slimmed — passes `privateEndpoints: []` to AVM cog-svc; PE moved to `foundry/main.bicep`) and `main.bicep` (declares the gated PE after `foundryProject`).

## [v1.1.2] - 2026-04-28

### Fixed
- **AI Foundry private endpoint race regression — pre-create diverged from AVM end-state on `networkInjections`** (fixes #25): PR #19 (v1.0.9) added a conditional `networkInjections` array (scenario `agent`, `useMicrosoftManagedNetwork: false`) to the pre-created `Microsoft.CognitiveServices/accounts` resource on the assumption that the AVM `avm/ptn/ai-ml/ai-foundry` module would set the same property on its account `PUT`, making the AVM PUT an idempotent no-op. Empirical evidence from a clean v1.1.2 deploy under `networkIsolation = true` + `deployAiFoundrySubnet = true` showed otherwise: the account converged to `networkInjections: null` (i.e. the AVM PUT body explicitly omits the property and ARM PUT replace-semantics wipes it), so AVM's PUT became a non-trivial mutation, the account moved back to `Accepted/Updating`, and the child PE `pep--account-0` then failed deterministically with `AccountProvisioningStateInvalid`. Dropped `networkInjections` (and the `union(...)` wrapper) from the pre-create — both PUTs now produce the same body and AVM's PUT is a true no-op, restoring the #19 contract. The agent subnet is wired by the AVM submodule via `aiFoundryConfiguration.networking.agentServiceSubnetResourceId` (set in `varAfNetworkingOverride`), not via a top-level `networkInjections` property on the account, so the agent service still gets the right subnet on first deploy.
- **`install.ps1` PowerShell 5.1 scalar-collapse on single extra repo, second pass** (fixes #23): the v1.1.1 fix from #22 wrapped the array in `@(...)` but did so **inside** an `if/else` expression — `$x = if (...) { @(...) } else { @(...) }`. PowerShell 5.1's pipeline output processor unwraps the single-element result of the `if` expression back to a scalar at assignment time, so the `@(...)` inside the branch did not survive. With exactly one component in `manifest.json#components`, `$extraTags` and `$extraNames` were still strings, and `$extraTags[0]` returned `'m'` (the first character of `'main'`), causing `git clone -b m --depth 1 h` to fail silently. Rewrote both as plain `if` statements with `@(...)` on the right-hand side of a direct assignment, which is unambiguous under PS 5.1. Verified under `powershell.exe` (PS 5.1) with `$ExtraRepoTags = 'main'`: `$extraTags.GetType().Name -eq 'Object[]'` and `$extraTags[0] -eq 'main'`. The same shape that already worked for `$extraUrls` (assignment RHS, no `if`-as-expression).

### Changed
- **`install.ps1`: parallelize independent `choco install` steps with `Start-Job`** (fixes #24): the six tool installs (`vscode`, `azure-cli`, `git`, `python311`, `powershell-core`, `azd`) have no inter-dependencies and were running serially, taking 30–40 minutes of CSE wall time on a clean network-isolated provision (the dominant cost of `azd up` once everything else is healthy). Now run concurrently as background jobs; CSE wall time becomes max(slowest-package), expected ~17–22 minutes — savings of roughly 10–15 minutes. After `Wait-Job`, output is replayed serially per job to keep the CSE transcript readable. Job state is asserted and a `Write-Warning` is emitted for any non-`Completed` job so failures are visible in `C:\WindowsAzure\Logs\`. PATH is refreshed once after all jobs complete instead of per install.
  - **Start-Job vs Start-ThreadJob**: `Start-Job` (built-in, spawns one child `powershell.exe` per job, ~1–2s each) was chosen over `Start-ThreadJob` because the latter is **not bundled with PowerShell 5.1** — it would require `Install-Module -Name ThreadJob` from PSGallery, forcing `*.powershellgallery.com` into the firewall allowlist and adding a new failure mode under network isolation. The ~6–12 s of process startup overhead is negligible against `choco install` steps that take minutes, and the parallelization works without any module dependency.
- **`install.ps1`: install AZD via Chocolatey** (fixes #24): switched from `Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression` to `choco install azd` so the AZD install can be parallelized with the other tools and uses the same package manager as the rest of the bootstrap. The existing AZD path-discovery block is preserved as a fallback in case the chocolatey package layout changes; `C:\ProgramData\chocolatey\bin\azd.exe` (the choco shim) and `C:\ProgramData\chocolatey\lib\azd\tools\azd.exe` were prepended to the candidate list.
- **`install.ps1`: drop `notepadplusplus`** (fixes #24): not used by any downstream automation. Operators who want it can install it on demand from the Bastion session.
- **`install.ps1`: add quiet flags to every `choco` invocation** (fixes #24): `--no-progress --limitoutput --no-color` cuts log/console overhead during parallel installs and keeps the CSE transcript scannable. `--ignoredetectedreboot --force` preserve existing behavior (the script ends with a delayed reboot).

## [v1.1.1] - 2026-04-26

### Added
- **`enablePrivateLogAnalytics` parameter** (PR #16): new `bool` parameter (default `true`) that controls whether the Azure Monitor Private Link Scope (AMPLS) and its five associated private DNS zones (`privatelink.monitor.azure.com`, `privatelink.oms.opinsights.azure.com`, `privatelink.ods.opinsights.azure.com`, `privatelink.agentsvc.azure.automation.net`, `privatelink.applicationinsights.io`) are deployed when `networkIsolation = true`. Gated through `_deployAmpls = networkIsolation && deployAppInsights && deployLogAnalytics && enablePrivateLogAnalytics`. Set to `false` (or `ENABLE_PRIVATE_LOG_ANALYTICS=false`) when these singleton zones are managed centrally (e.g. by a hub) to avoid DNS conflicts and link collisions with other private endpoints. Default preserves existing zero-trust behavior.
- **`aiFoundryStorageSku` parameter and helper module** (PR #17): new `string` parameter (default `Standard_LRS`, `@allowed` covers all standard/premium SKUs) plus new module `modules/ai-foundry/storage-account.bicep` that pre-creates the AI Foundry Storage Account via `avm/res/storage/storage-account` with the requested SKU and an optional blob private endpoint when `networkIsolation = true`. The pre-created account's resource ID is fed back to the AVM `ai-foundry` pattern via `storageAccountConfiguration.existingResourceId`, so the AVM skips its internal storage creation. Workaround for `avm/ptn/ai-ml/ai-foundry@<=0.6.0`, which does not expose `skuName` and hardcodes `Standard_GRS` — failing in regions that don't offer GRS (e.g. Poland Central, with `RedundancyConfigurationNotAvailableInRegion`). Existing deployments passing `aiFoundryStorageAccountResourceId` are unaffected.
- **`extendFirewallForAcrTaskBuilds` parameter and ACR Tasks build-egress firewall rules** (fixes #20): new `bool` parameter (default `true`) and two new application rules — `AllowAcrTaskDevRuntimes` and `AllowAcrTaskOsPackages` — scoped to `devopsBuildAgentsSubnetPrefix` so ACR Tasks builds running inside the build-agents subnet can reach language registries and OS package repos.
  - `AllowAcrTaskDevRuntimes` reuses the shared `_firewallDevRuntimeFqdns` set (`www.python.org`, `*.python.org`, `pypi.org`, `*.pypi.org`, `files.pythonhosted.org`, `*.pythonhosted.org`, `registry.npmjs.org`, `*.npmjs.org`) on `Https/443`.
  - `AllowAcrTaskOsPackages` opens a new `_firewallAcrTaskOsPackageFqdns` set (`deb.debian.org`, `security.debian.org`, `archive.ubuntu.com`, `security.ubuntu.com`, `dl.yarnpkg.com`) on `Https/443` and `Http/80` (apt-get `InRelease` is HTTP).
  - Both rules only carry FQDNs when `_deployAcrTaskAgentPool && extendFirewallForAcrTaskBuilds`. Disable the flag if egress is managed centrally or all build dependencies are pre-baked into the builder base image.
- **`extraRepoUrls` / `extraRepoTags` / `extraRepoNames` parameters and `install.ps1` extension point** (fixes #21, refined by #22): new `-ExtraRepoUrls` / `-ExtraRepoTags` / `-ExtraRepoNames` parameters on `install.ps1` that let downstream solution accelerators clone arbitrary Git repositories onto the jumpbox under `C:\github\<name>` during the CSE bootstrap, without forking `install.ps1` or repurposing the upstream `manifest.components` array (which is read **after** the upstream clone and therefore not reachable from a consumer's overlay). `main.bicep` derives the lists at compile time from `manifest.json#components` (the documented submodule overlay contract — see issue #22) and forwards them to `install.ps1` via the CSE `commandToExecute` as comma-separated strings using `join(...)`. Consumers therefore declare the repos to clone in their overlay `manifest.json`, never in Bicep params or `main.parameters.json`. Tags default to `main`; names default to the repo URL basename without `.git`. Existing `manifest.components` loop is preserved (purely additive). Unblocks the documented "single jumpbox entry point" pattern for private-network data-plane post-provisioning (e.g. Cosmos seeding, AI Search index creation, sample data loading) in consumers like GPT-RAG and `Azure/live-voice-practice`.

### Fixed
- **`install.ps1` PowerShell 5.1 scalar collapse on single extra repo** (fixes #22): when the consumer's overlay `manifest.json#components` contains exactly one entry, the comma-separated string forwarded by `main.bicep` (e.g. `-ExtraRepoUrls "https://github.com/Contoso/voice-app.git"`) collapses to a scalar after the `-split ',' | ForEach-Object | Where-Object` pipeline under PS 5.1 (the only PS version available out-of-the-box on Windows Server jumpboxes). `$extraUrls[0]` then returned the FIRST CHARACTER of the URL (`'h'`) and `git clone -b m --depth 1 h C:\github\h` failed silently. Wrapped each split pipeline in `@(...)` to force array context.
- **`install.ps1` swallowed `git clone` failures for extra repositories** (fixes #22): if a clone of an extra repo failed (auth, transient network, bad ref), the script proceeded to `copy-item` against a non-existent target, producing a misleading "Cannot find path" error and no clear root cause. Now checks `$LASTEXITCODE` (and target-path existence) and emits an explicit `Write-Warning` naming the repo, ref, URL, and exit code, then `continue`s to the next entry. The CSE itself remains successful so a single bad repo does not roll back the whole jumpbox bootstrap; failures are surfaced in `C:\WindowsAzure\Logs\` for the operator.
- **ACR Tasks agent pool hangs in `Queued` forever** (fixes #18): the `AllowAcrTasks` application rule on the Azure Firewall only allowed `*.azurecr.io` and `*.data.azurecr.io` from the build-agents subnet, but the ACR Tasks agent VM also needs egress to the Azure Storage queue/blob/table endpoints used by the ACR Tasks control plane to dispatch jobs. Without it, `az acr build --agent-pool <pool>` stayed in `Queued` indefinitely (no `startTime`), the agent pool eventually flipped to `Failed`, and any subsequent `update`/`scale` returned `RegistryStatusConflict`. Extended `_firewallAcrTaskFqdns` with `*.blob.${environment().suffixes.storage}`, `*.queue.${environment().suffixes.storage}`, and `*.table.${environment().suffixes.storage}` (sovereign-cloud safe via `environment().suffixes.storage`).
- **AI Foundry private endpoint race on first `azd up` in network-isolated mode** (PR #19): the pre-created `Microsoft.CognitiveServices/accounts` (AI Foundry) resource did not converge to the same end-state that the AVM `avm/ptn/ai-ml/ai-foundry` module subsequently `PUT`s. On a clean network-isolated deploy, the AVM mutated the account (enabling `allowProjectManagement`, attaching `networkInjections` scenario `agent`), moving it back to `Accepted/Updating`, and the child PE `PUT` then failed with `AccountProvisioningStateInvalid` (surfaced as "already exists or in a conflicting state"). A simple re-run succeeded once the account was stable. Aligned the pre-create to the AVM end-state so the AVM `PUT` becomes an idempotent no-op and the PE provisions on the first run:
  - Bumped the API version from `2024-10-01` to `2025-06-01` (matches the AVM submodule).
  - Added `allowProjectManagement: deployAfProject`.
  - Added conditional `networkInjections` (scenario `agent`, `useMicrosoftManagedNetwork: false`) when `networkIsolation && deployAiFoundrySubnet`, composed via `union()` so the property is omitted entirely when not applicable (avoids ARM type-validator rejecting a null array).
- **ACR Tasks builds fail at `npm install` / `pip install` / `apt-get install`** (fixes #20): under `networkIsolation + deployAcrTaskAgentPool`, the build-agents subnet only had egress for ACR + Storage, so realistic Dockerfiles failed to fetch language and OS packages (e.g. `npm error ECONNRESET` to `registry.npmjs.org`, TLS handshake failures to `dl.yarnpkg.com`, `apt-get` errors against `deb.debian.org`). Addressed by the new `AllowAcrTaskDevRuntimes` and `AllowAcrTaskOsPackages` application rules described above.

### Changed
- **Jumpbox extra repos now sourced exclusively from `manifest.json#components`** (fixes #22): removed the public Bicep parameters `extraRepoUrls` / `extraRepoTags` / `extraRepoNames` (added in #21) in favor of deriving the lists at compile time from `manifest.json#components`. Eliminates a duplicated source of truth — consumers of this landing zone (used as a Bicep module / git submodule) overlay their own `manifest.json` and so already control `components` for the upstream clone loop and `ailz_tag` for release pinning; they should not have to also re-declare the same repos in `main.parameters.json`. `install.ps1` continues to accept `-ExtraRepoUrls/-ExtraRepoTags/-ExtraRepoNames` as comma-separated strings (forwarded over the CSE `commandToExecute`) — the input contract on `install.ps1` is unchanged. **Breaking** for any consumer that adopted the #21 Bicep params during the v1.1.1 amendment window: move those entries into `manifest.json#components`. Built-in upstream `manifest.json` keeps `components: []`.
- **`aiFoundryStorageSku` default** (PR #17): for new deployments where `aiFoundryStorageAccountResourceId` is empty, the AI Foundry Storage Account SKU defaults to `Standard_LRS` instead of the AVM default `Standard_GRS`. Trades cross-region redundancy for guaranteed regional availability — appropriate for a workload-scoped AI Foundry storage account. Operators wanting GRS can set `aiFoundryStorageSku: 'Standard_GRS'`.

### Removed
- **`main.json` no longer versioned**: the compiled ARM template generated from `main.bicep` was removed from the repository and added to `.gitignore`. It was the source of recurring merge conflicts on PRs and is regenerated on demand by `azd` / `az bicep build` during deployment, so it does not need to be tracked.

## [v1.1.0] - 2026-04-24
### Added
- **Optional ACR Task agent pool for network-isolated image builds** (fixes #14): new `Microsoft.ContainerRegistry/registries/agentPools@2019-06-01-preview` child resource parented to the existing `containerRegistry`, attached to the existing `devops-build-agents-subnet` (`/27`, previously unused). Gated on `deployContainerRegistry && networkIsolation && deployAcrTaskAgentPool`. Lets `az acr build --agent-pool <name>` run builds inside the VNet and push to the private ACR over its private endpoint, removing the need for Docker on any jumpbox or client and avoiding the common workaround of re-enabling `publicNetworkAccess` for every build.
  - New parameters in `main.bicep`:
    - `deployAcrTaskAgentPool` (`bool`, default `true`)
    - `acrTaskAgentPoolName` (`string`, `@maxLength(20)`, default `'build-pool'`)
    - `acrTaskAgentPoolTier` (`@allowed(['S1','S2','S3'])`, default `'S1'`)
    - `acrTaskAgentPoolCount` (`int`, `@minValue(0)`, default `1`)
  - New output `ACR_TASK_AGENT_POOL`: the agent pool name when deployed, empty otherwise. Surfaced via `azd env get-values`.
  - New firewall application rule `AllowAcrTasks` scoped to `devopsBuildAgentsSubnetPrefix`, allowing `*.azurecr.io` and `*.data.azurecr.io`. `management.azure.com` for task orchestration and `mcr.microsoft.com` for the builder base image are covered by existing shared rules.
  - Cost note: `S1` at `count=1` is billed per hour whether idle or not. To pause billing between builds: `az acr agentpool update -r <acr> -n <pool> --count 0`.
- **Complete Firewall allow-list for the jumpbox CSE bootstrap under network isolation** (fixes #15): replaced the monolithic `_firewallVmSetupFqdns` with four purpose-labeled sets that cover every tool `install.ps1` actually runs. All jumpbox-specific rules are now scoped to `jumpboxSubnetPrefix` (previously `*`) so the ACA/agent subnets do not inherit developer-tooling egress.
  - New parameter `extendFirewallForJumpboxBootstrap` (`bool`, default `true`) — disable if egress is managed centrally.
  - Shared `_firewallEssentialAuthFqdns` extended with `login.windows.net`, `management.azure.com`, and `*.applicationinsights.azure.com` (previously missing, caused `az <anything>` and telemetry calls to fail from inside the VNet).
  - Shared `_firewallEssentialGitHubFqdns` extended with `codeload.github.com` and `objects.githubusercontent.com` (git clone blob fetches).
  - New `_firewallVmBootstrapFqdns` (Chocolatey + Windows prerequisites): adds `packages.chocolatey.org`, `api.nuget.org`, `www.nuget.org`, `dist.nuget.org`, `download.visualstudio.microsoft.com`, `*.visualstudio.microsoft.com`, `download.microsoft.com`, `*.download.microsoft.com`. Fixes `choco install python311` failing on the `vcredist140` dependency download.
  - New `_firewallDevRuntimeFqdns` (Python + Node): adds `www.python.org`, `pypi.org`, `files.pythonhosted.org`, `*.pythonhosted.org`, `registry.npmjs.org`, `*.npmjs.org`. Fixes `pip install` failing against `files.pythonhosted.org`.
  - New `_firewallEditorFqdns` (VS Code): preserves the existing VS Code update endpoints but scoped to the jumpbox subnet.
  - Three new application rules — `AllowJumpboxBootstrap`, `AllowJumpboxDevRuntimes`, `AllowJumpboxEditors` — replace the old `AllowVmSetup` rule. Sources are `[jumpboxSubnetPrefix]` instead of `*`.

### Removed
- **Jumpbox Docker / Moby install** (fixes #14): `install.ps1` no longer installs Moby Engine, `docker buildx`, Docker Desktop, WSL2 features, or the associated 6-step Docker status tracking and log file (`docker-setup-status.json`). Rationale (per issue #14): Windows Server's Moby engine cannot run privileged Linux containers required by BuildKit, so the jumpbox could never actually build Linux images; Docker Desktop is not supported on Windows Server and requires a paid subscription above ~250 employees / ~$10M revenue. Image builds move to the ACR Tasks agent pool. `install.ps1` now prints a short MOTD pointing users at `az acr build --agent-pool <pool>`.
- **Docker Hub FQDNs** removed from the Firewall Policy allow-list: `download.docker.com` and `desktop.docker.com` are no longer required because the jumpbox no longer installs Docker.

### Changed
- **`install.ps1` reboot reason** updated from "activate Windows Containers feature" to "finalize installed tooling" (Chocolatey-installed Git/Python/VS Code/PowerShell Core may flag a pending reboot). The 120 s delay before `shutdown /r` is preserved so the Custom Script Extension agent can still report `Succeeded` to ARM before the VM goes down.

### Fixed
- **`choco install python311` fails on fresh NI jumpbox**: blocked by firewall while fetching `vcredist140` from `download.visualstudio.microsoft.com`. Addressed by the new `_firewallVmBootstrapFqdns` set.
- **`git clone https://github.com/...` on jumpbox fails mid-fetch**: blob fetches to `codeload.github.com` / `objects.githubusercontent.com` were not matched by the prior narrow GitHub list. Addressed by extending `_firewallEssentialGitHubFqdns`.
- **`pip install ...` on jumpbox fails**: `files.pythonhosted.org` was not matched by `*.pypi.org`. Addressed by the new `_firewallDevRuntimeFqdns` set.
- **`az <anything>` against `management.azure.com` from jumpbox fails**: ARM endpoint was missing from `_firewallEssentialAuthFqdns`. Addressed by extending that set.

## [v1.0.9] - 2026-04-22
### Fixed (amended 2026-04-23, third amendment)
- **Rare race condition between `searchService` and `searchServiceAIFoundry`**: The two Azure AI Search services introduced in v1.0.9 had no dependency wiring, so ARM attempted to create them in parallel. In some regions (observed in Sweden Central) this occasionally caused the `Microsoft.Search` resource provider to leave the second service name "stuck" in its internal namespace cache, producing `ServiceNameUnavailable` on the first deployment and then `A service with the name '…' already exists` on retry — even though `checkNameAvailability` reports the name available and `az resource list` shows no such service. Added a `dependsOn: [searchService!]` to `searchServiceAIFoundry` in `main.bicep` to serialize their creation and eliminate the race. If a name is already stuck from a previous failed deployment, the backend cache typically clears within 4–24h; alternatively, override `aiFoundrySearchServiceName` or set `aiSearchResourceId` to reuse an existing Search account.

### Fixed (amended 2026-04-23)
- **CSE stuck in `Updating` provisioning state after jumpbox bootstrap**: `install.ps1` previously scheduled the post-install reboot via `schtasks` ~1 minute after the script ended, which caused the VM to reboot before the Custom Script Extension agent could report `Succeeded` back to ARM. As a result, `Microsoft.Compute/virtualMachines/extensions/cse` stayed permanently at `provisioningState=Updating`, blocking `az vm extension wait` and any downstream deployment gating on CSE completion. Replaced the `schtasks` approach with `shutdown /r /t 120`, giving the CSE agent ~30s to post its final status to ARM before the reboot happens. The reboot itself is preserved because it is required to activate the Windows `Containers` feature for Docker. **Validated on 2026-04-23**: clean redeploy of the jumpbox on env `ailz-ni-win-04231238` reported `provisioningState=Succeeded` with CSE exit code `0` (duration ~10 min, no stderr), and the overall `azd provision` completed in ~18 min.

### Added (amended 2026-04-23)
- **Hardened jumpbox Docker Engine (Moby) bootstrap in `install.ps1`**: Server branch rewritten with explicit step-by-step logging, per-step `try/catch` error capture, and post-install validation. Improvements:
  - Windows `Containers` feature enable is now performed **before** extracting Moby and registering `dockerd`, matching the documented install order for Moby on Windows Server.
  - `$env:ProgramFiles\docker` is **prepended** to MACHINE/Session `Path` (instead of appended) so `docker.exe` from Moby wins over any pre-existing Docker client binary on the VM image.
  - `Start-Service docker` is followed by a 60-second wait loop that confirms the service reaches `Running` before buildx bootstrap is attempted.
  - `docker-buildx` plugin install and `buildx create --driver docker-container` bootstrap are gated on the daemon actually being `Running`, avoiding silent bootstrap failures.
  - A machine-readable status file is written to `C:\WindowsAzure\Logs\docker-setup-status.json` capturing the outcome of each of the 6 setup steps (Containers feature, Moby download, Moby extract, service register, service running, buildx plugin, buildx bootstrap).
  - All output continues to be captured in the existing `Start-Transcript` log at `C:\WindowsAzure\Logs\CMFAI_CustomScriptExtension.txt`.
  - Motivation: prior deployments showed the Custom Script Extension reporting success while the Docker Engine was in fact not registered as a service (no `docker` Windows service, no `buildx` plugin, `Containers` feature not enabled). The new layout surfaces the exact failing step in the transcript and status file, and eliminates PATH precedence ambiguity when a pre-existing `docker.exe` is on the image.

### Added
- **`searchServiceLocation` parameter**: New optional parameter to override the Azure region for Azure AI Search services. Set via `AZURE_SEARCH_LOCATION` in azd env. Useful when the primary deployment region is out of capacity for AI Search (`InsufficientResourcesAvailable` error).
- **Default Bastion NSG** (fixes #8): Dedicated NSG on the `AzureBastionSubnet` that denies all internet inbound on port 443 by default. Operators add trusted source IPs via the new `bastionAllowedSourceIPs` parameter. All required Bastion control-plane rules (GatewayManager, AzureLoadBalancer, BastionHostCommunication) are included. New module `modules/networking/bastion-nsg.bicep`.
- **Default Azure Firewall + UDR** (fixes #9): Azure Firewall with a Standard firewall policy and a route table that forces `0.0.0.0/0` egress through the firewall for workload subnets. Includes essential outbound FQDN rules (MCR, Entra ID) and diagnostics wired to Log Analytics. Enabled by default when network isolation is active.
- **Standalone AI Services account resource**: Pre-creates the `Microsoft.CognitiveServices/accounts` resource before the AVM `ai-foundry` module runs, with `dependsOn` wiring on the `aiFoundry` module. This permanently eliminates the `AccountProvisioningStateInvalid` race condition where the AVM module would attempt to create the AI Services private endpoint while the account was still in `Accepted` provisioning state.
- **Dedicated Azure AI Search for AI Foundry**: New `searchServiceAIFoundry` module provisions a separate AI Search instance (name `aiFoundrySearchServiceName`, Basic/2 replicas/1 partition) used exclusively by AI Foundry. The application search (`searchService`) remains dedicated to workload use. A matching private endpoint `privateEndpointSearchAIFoundry` is created when network isolation is active. Consumers can still bring their own Foundry search via `aiSearchResourceId`.
- **Consolidated DNS zones module** (`modules/networking/private-dns-zones.bicep`): Single for-loop wrapper over the AVM `avm/res/network/private-dns-zone` module. Replaces 15 individual Private DNS Zone module invocations in `main.bicep`.
- **Consolidated private endpoints module** (`modules/networking/private-endpoints.bicep`): Single `@batchSize(1)` for-loop wrapper over the AVM `avm/res/network/private-endpoint` module. Replaces 8 individual PE module invocations while preserving serialization. The App Insights Private Link Scope PE remains a separate module invocation due to its unique four-DNS-zone configuration.

### Changed
- **Cost optimization — Azure AI Search defaults** (fixes #11): Search service defaults changed to `sku: 'basic'`, `replicaCount: 1`, `partitionCount: 1`. Reduced `replicaCount` from 2 to 1 to lower default cost and ease regional capacity pressure in constrained regions. SKU, replica, and partition settings remain overridable for larger workloads.
- **Cost optimization — Jumpbox VM default** (fixes #11): Default `vmSize` changed from `Standard_D8s_v5` (8 vCPU / 32 GiB) to `Standard_D2s_v5` (2 vCPU / 8 GiB). Same Dsv5 general-purpose family, right-sized for the jumpbox admin/bootstrap role. Override remains available for heavier use cases.
- Estimated combined cost reduction from the above: ~$1,359/month (~$16.3k/year) for default deployments.
- **Template size optimization**: Compiled `main.json` reduced from **7.94 MB to 3.98 MB**, bringing the template below the 4 MB Azure Resource Manager request limit and unblocking `azd provision` with the `RequestContentTooLarge` error. Changes:
  - Collapsed 11 TestVM role-assignment modules into a single array-driven `assignTestVmRoles` module call.
  - Collapsed 8 Executor role-assignment modules into a single array-driven `assignExecutorRoles` module call.
  - Replaced the following AVM module wrappers with direct ARM resource declarations to avoid full nested-template inlining: all 7 user-assigned identities (including the `containerAppsUAI` loop), `logAnalytics` (`Microsoft.OperationalInsights/workspaces@2023-09-01`), `appInsights` (`Microsoft.Insights/components@2020-02-02`), `containerRegistry` (`Microsoft.ContainerRegistry/registries@2023-11-01-preview`), `keyVault` (`Microsoft.KeyVault/vaults@2024-11-01`), `containerEnv` (`Microsoft.App/managedEnvironments@2025-01-01`), and `appConfig` (`Microsoft.AppConfiguration/configurationStores@2024-05-01` with an explicit `Microsoft.Authorization/roleAssignments` for AppConfigurationDataOwner).
  - Functional behavior, feature flags, role assignments, idempotent GUIDs, and network-isolation dependency ordering are preserved.

### Fixed
- **`RoleAssignmentExists` deployment failure**: Removed the custom `assignSearchSearchServiceContributorAIFoundryProject` module from `main.bicep`. The AVM `ai-foundry` module already creates this role assignment (Search Service Contributor on the Search service for the AI Foundry Project identity) internally with the same deterministic GUID, causing a conflict on deployment. Cleaned up the downstream `dependsOn` accordingly.
- **`RequestContentTooLarge` on `azd provision`**: Compiled template size now 3.98 MB, under the 4 MB ARM limit (see the template size optimization entry above).
- **Network-isolation provisioning failures**:
  - **App Configuration Forbidden on `keyValues` writes under NI**: `appConfigPopulate` and `cosmosConfigKeyVaultPopulate` are now gated with `!_networkIsolation` to avoid ARM data-plane writes against an App Configuration store with `publicNetworkAccess: 'Disabled'` (writes require an ARM private link path not provisioned by this template).
  - **App Configuration `dataPlaneProxy.privateLinkDelegation`** now set to `'Enabled'` when `_networkIsolation` is true (required by API `2024-05-01` when `publicNetworkAccess` is `Disabled`).
  - **`InvalidTemplate: bastionNsgDeployment requires an API version`** when `deployVM=false`: made the `networkSecurityGroupResourceId` reference in the VNet `baseSubnets` null-safe using `bastionNsg!.outputs.id` gated on `(deployVM && _networkIsolation && deployNsgs)`.
  - **Jumpbox VM `OSProvisioningTimedOut`**: default `vmSize` changed to `Standard_D2s_v3` (v5 family unavailable in several regions incl. East US 2) and `deployVM` is now controllable via the `DEPLOY_VM` azd env var (`${DEPLOY_VM=true}`) so operators can opt out in subscriptions where Azure Policy auto-installs the `AzurePolicyforWindows` extension and blocks OS provisioning.

## [v1.0.8] - 2026-04-16
### Added
- New parameter `policyManagedPrivateDns` (`bool`, default `false`) to skip Private DNS Zone and DNS zone group creation. Use this in environments where Azure Policy manages Private DNS Zone linking (e.g., CAF Enterprise-Scale Platform Landing Zone). (PR #4, fixes #2)
- New parameter `privateEndpointLocation` to override the Azure region for private endpoint creation. Supports scenarios where the VNet is in a different region than the deployed resources. (PR #6, fixes #1)
- New parameter `privateEndpointResourceGroupName` to specify a dedicated resource group for private endpoints. (PR #6, fixes #3)
- New variable `_deployPrivateDnsZones` that gates all Private DNS Zone module deployments based on `networkIsolation && !policyManagedPrivateDns`.
- New variables `_peLocation`, `_defaultPeResourceGroupName`, and `_peResourceGroupName` for resolving PE location and resource group overrides with backward-compatible fallbacks.

### Changed
- All Private DNS Zone modules now conditionally deploy based on `_deployPrivateDnsZones` instead of `_networkIsolation`, allowing policy-managed environments to opt out.
- All private endpoint `privateDnsZoneGroup` configurations are conditionally set to `{}` when `policyManagedPrivateDns` is `true`.
- All 8 private endpoint module invocations updated to use `_peLocation` and `_peResourceGroupName` instead of hardcoded `location` and inline ternary expressions.
- Updated `main.parameters.json` with `privateEndpointLocation` and `privateEndpointResourceGroupName` entries supporting `azd` env var substitution (`AZURE_PE_LOCATION`, `AZURE_PE_RESOURCE_GROUP_NAME`).

### Refactored
- Extracted default PE resource group resolution into a separate `_defaultPeResourceGroupName` variable for improved readability.

## [v1.0.7] - 2026-04-14
### Fixed
- Fixed Log Analytics provisioning failure in Sweden Central (and other regions enforcing CMK validation) by explicitly setting `forceCmkForQuery: false` in the `logAnalytics` module. The AVM module defaults this to `true`, which requires a fully configured Customer Managed Key setup that the landing zone does not provision.

## [v1.0.6] - 2026-04-08
### Changed
- Parametrized Container App CPU and memory in `containerAppsList`. Each app can now optionally define `cpu` and `memory`, falling back to `'0.5'` and `'1.0Gi'` respectively.
- Added `dataingest` container app entry to default parameters with `cpu: "1.0"` and `memory: "2.0Gi"`.

## [v1.0.5] - 2026-04-01
### Fixed
- Fixed jumpbox Custom Script Extension using incorrect release tag. Replaced `install_script` URL field in `manifest.json` with `ailz_tag` field. The install script URL is now constructed from the tag in `main.bicep`, and the correct landing zone tag is passed to the `-release` parameter instead of the consumer repo tag.

### Documentation
- Updated `AGENTS.md` to reflect the `ailz_tag` field replacing `install_script`.

## [v1.0.4] - 2026-03-29
### Changed
- Made Cosmos DB throughput fully optional at both database and container levels using nullable types and safe access operators.
- Added `dbDatabaseThroughput` parameter (`int?`) for optional database-level throughput configuration.
- Container-level throughput and indexing policy are now optional via safe access (`container.?throughput`, `container.?indexingPolicy`).
- Default parameters no longer set throughput, aligning with the serverless Cosmos DB account configuration.

## [v1.0.3] - 2026-03-24
### Changed
- Simplified the default workload in `main.parameters.json` to a single Hello World container app (`orchestrator`) by removing GPT-RAG-specific defaults (`frontend`, `dataingest`, and `mcp`).
- Reduced default data resources by keeping only the `documents` storage container and `conversations` Cosmos DB container.
- Updated default chat model deployment from `gpt-4.1-mini` to `gpt-5-nano` and aligned model API versions to `2025-12-01-preview`.

### Removed
- Removed GPT-RAG-specific App Configuration keys from template defaults (`PROMPT_SOURCE`, `AGENT_STRATEGY`, and `AGENT_ID`).
- Removed tracked generated build artifact `main.json` from source control.

### Documentation
- Updated README container app role assignments to match current default configuration (Hello World `orchestrator` only).

## [v1.0.2] - 2026-03-17
### Fixed
- Fixed provisioning failures caused by unguarded references to outputs from optional resources when feature flags are disabled.
- Aligned App Configuration population with resource deployment toggles for Search, Key Vault, Storage, Container Apps, and Container Environment values.
- Aligned role-assignment loop conditions with `deployContainerApps` to prevent unsafe indexed references when Container Apps are disabled.
- Aligned user-assigned identity creation conditions with owning resource flags to avoid orphan identities.

## [v1.0.1] - 2026-03-06
### Fixed
- Fixed conditional references to Log Analytics outputs when `deployLogAnalytics=false`.
- Aligned App Insights, Private Link Scope, and scoped resources conditions with the Log Analytics flag.
- Prevented App Configuration values from referencing non-deployed Log Analytics/App Insights resources.

### Removed
- Removed all API Management (APIM) mentions and related configuration from the landing zone templates and constants.

## [v1.0.0] - 2026-03-02
### Added
- Initial release of the Azure AI Landing Zone Bicep implementation.
