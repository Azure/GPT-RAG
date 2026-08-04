# Azure Deployment and Validation Plan

> **Status:** Validated

Generated: 2026-08-04
Issues: Azure/GPT-RAG #591, #592, #597

## 1. Project overview

**Goal:** Validate classic, hosted/no-panel, and hosted/panel GPT-RAG modes in
one disposable, fully network-isolated Azure environment. Prove the corrected
hosted image supply chain through a dedicated VNet-connected ACR Tasks agent
pool, live Responses behavior, immutable rollback, telemetry, and
document-level authorization.

**Path:** Validate and transition an existing Azure Developer CLI project.
Infrastructure remains owned by the pinned AI Landing Zone submodule and will
not be edited manually.

## 2. Requirements

| Attribute | Value |
| --- | --- |
| Classification | Non-production validation |
| Scale | Single-user/synthetic test load |
| Budget | Cost-optimized, short-lived |
| Subscription | Authorized non-production subscription (name and ID redacted) |
| Location | Primary services: `eastus2`; Azure AI Search: `francecentral` |
| Network posture | `NETWORK_ISOLATION=true`; private endpoints remain closed |
| Build route | Dedicated VNet-connected ACR Tasks agent pool, S1, one instance |
| Cleanup | Delete the disposable resource group and all validation identities/content |

The user explicitly authorized this subscription and autonomous execution.
No environment name or resource-group name is recorded in this tracked plan.

## 3. Exact integrated pins

| Component | Tag | Commit |
| --- | --- | --- |
| gpt-rag-ui | `v2.5.0` | `5328ec7e222e47f56b50b077ccf8a51c30f61681` |
| gpt-rag-orchestrator | `v3.9.0` | `779b136d4da5d4bdcf9442dc1ec7a6115571f06a` |
| gpt-rag-ingestion | `v2.6.0` | `cb9f1a08a2e780c15ffd096f6e56c04b5e5bd4ca` |
| AI Landing Zone | `v2.4.1` | `fbc5d226543d0fb7a29ccd241c45df5c3caa82ee` |

The worktree commit equals `origin/develop` at planning time. The submodule is
initialized at the exact landing-zone commit, and shallow component checkouts
resolve to the exact manifest commits.

## 4. Recipe selection

**Selected:** Existing AZD + Bicep composition, with Azure CLI for quota,
resource inspection, private ACR builds, runtime evidence, and cleanup.

**Rationale:** `azure.yaml`, lifecycle hooks, `main.parameters.json`, and the
pinned landing-zone module are the repository's supported deployment path.
Direct Bicep edits or a public-network workaround would invalidate the gates.

## 5. Architecture and execution topology

### Core resources

| Component | Azure service / SKU | Planned quantity |
| --- | --- | ---: |
| Foundry account and project | Microsoft Foundry / AIServices S0 | 1 account, 1 project |
| Chat model | `gpt-5-nano` `2025-08-07`, GlobalStandard 100 | 1 deployment |
| Embedding model | `text-embedding-3-large` `1`, Standard 100 | 1 deployment |
| Search | Azure AI Search Standard | 2 services |
| Conversation/project data | Cosmos DB serverless | 2 accounts in classic/panel |
| Application and Foundry storage | StorageV2 Standard LRS | 2 accounts |
| Registry | ACR Premium, public access disabled | 1 |
| Private build compute | ACR Tasks dedicated VNet pool S1 | 1 instance / 2 vCPU |
| Application runtime | Container Apps consumption environment | 1 |
| Classic apps | frontend, orchestrator, dataingest | 3 |
| Hosted apps | frontend, dataingest; no orchestrator Container App | 2 |
| Private administration | Windows jumpbox, Bastion, NAT, Azure Firewall | 1 each |
| Networking | VNet, isolated subnets/NSGs, private DNS, private endpoints | 1 VNet, about 15 endpoints |
| Configuration/secrets | App Configuration + Key Vault | 1 app store, 2 vaults |
| Observability | Log Analytics + Application Insights + AMPLS | 1 each |

### Mode sequence

1. **Classic:** provision and deploy all three exact component pins. Validate
   private health, real streaming, two-turn continuity, citations, and
   correlation.
2. **Hosted/no-panel:** obtain the exact classic orchestrator digest, compose
   hosted topology, build the corrected derivative with
   `az acr build --agent-pool`, deploy it by immutable digest, and prove the
   orchestrator Container App and panel-only Cosmos dependency are absent.
3. **Hosted/panel:** enable the panel without routing chat back through the
   orchestrator Container App; validate panel endpoints and feedback behavior.
4. **Version reversal:** deploy two functionally equivalent corrected hosted
   image digests, validate each live, then restore the first digest and validate
   it again.
5. **Classic fallback:** set hosted mode to false, reprovision/redeploy, and
   prove the classic orchestrator and runtime contract are restored.

Local provisioning may run from the workstation. Every private data-plane
operation, image build, component deployment, and private endpoint probe runs
inside the VNet through the jumpbox/managed identity. ACR public network access
must remain disabled throughout.

## 6. Region and provisioning-limit validation

Current official documentation shows that `eastus2` supports both Foundry
hosted agents and ACR Tasks dedicated agent pools. The exact model versions are
listed by Azure in `eastus2`; `Standard_D2s_v3` is listed with no restriction.

Eight regions in the hosted-agent/agent-pool intersection were checked with the
current Azure CLI quota extension. `eastus2` has the best combination of zero
DSv3 usage, zero application-network usage, full model quota, supported exact
models, and no existing Search service. No stale region evidence was used as
the decision.

| Resource/quota | Current | Deploy | Total | Limit | Source |
| --- | ---: | ---: | ---: | ---: | --- |
| Total regional vCPU | 0 | 2 | 2 | 100 | `az quota` (`Microsoft.Compute/cores`) |
| Standard DSv3 family vCPU | 0 | 2 | 2 | 100 | `az quota` (`standardDSv3Family`) |
| Virtual networks | 0 | 1 | 1 | 1,000 | `az quota` (`VirtualNetworks`) |
| Public IP addresses | 0 | 3 | 3 | 1,000 | `az quota` (`PublicIPAddresses`) |
| Private endpoints | 0 | 15 | 15 | 65,536 | `az quota` (`PrivateEndpoints`) |
| Container Apps environments | 1 | 1 | 2 | 50 | `az quota` (`ManagedEnvironmentCount`) |
| Storage accounts | 1 | 2 | 3 | 250 | `az quota` (`StorageAccounts`) |
| Search Standard services in region | 0 | 2 | 2 | 16 | Resource Graph + current Microsoft service limits |
| Cosmos DB accounts in subscription | 5 | 2 | 7 | 250 | Resource Graph + current Microsoft service limits |
| Registries in region | 1 | 1 | 2 | 100 | Resource Graph + current Microsoft service limits |
| ACR standard pool vCPU in new registry | 0 | 2 | 2 | 16 | `az quota` unsupported; current ACR pool documentation |
| `gpt-5-nano` GlobalStandard kTPM | 200 | 100 | 300 | 15,000 | `az cognitiveservices usage list` |
| `text-embedding-3-large` Standard kTPM | 0 | 100 | 100 | 350 | `az cognitiveservices usage list` |

`az quota list` was attempted first for Container Registry, Cosmos DB,
Cognitive Services, and Search as required. Container Registry, Cosmos DB, and
Cognitive Services returned `BadRequest`; Search returned an empty quota set.
The table therefore uses service-specific CLI/Resource Graph plus current
Microsoft documentation only for those unsupported providers.

**Provisioning-limit status:** All planned resources are within current quota.
Regional capacity remains a distinct Azure allocation decision and is checked
again by the pinned landing-zone preflight and a create-only deployment
preview before apply.

## 7. Security and evidence constraints

- Managed identity and least-privilege RBAC only; no credentials in source,
  App Configuration plaintext, prompts, logs, or issue comments.
- Never log or publish bearer tokens. Token checks record only presence/count
  and sanitized correlation evidence.
- Protected test content is synthetic and is never copied into issue comments.
- Published evidence contains region, resource types, counts, states, image
  digests, status codes, timings, and correlation identifiers, but never the
  validation environment or resource-group name.
- Hosted authorization must fail closed. Missing caller identity, failed native
  trimming, or any silent managed-identity/public-document fallback fails #591.
- Existing unrelated subscription resources are out of scope and must not be
  changed.

The Microsoft 365 and repository search found no authoritative record naming an
approved pair of reusable #591 user accounts. Before #591 execution, the
identity gate therefore accepts only synthetic identities created for this
validation or explicitly approved existing test identities with usable
authentication. It will not select an unrelated directory user.

### Role assignment verification

- **Status:** Verified for provisioning.
- The classic orchestrator has resource-scoped App Configuration Data Reader,
  Cognitive Services User/OpenAI User, ACR Pull, Cosmos DB Built-in Data
  Contributor, Search Index Data Reader, Storage Blob Data Reader, and Key Vault
  Secrets User roles.
- The frontend has resource-scoped App Configuration Data Reader, ACR Pull,
  Storage Blob Data Reader/Delegator, and Key Vault Secrets User roles.
- Ingestion has resource-scoped App Configuration Data Reader, Cognitive
  Services User/OpenAI User, Cosmos DB Built-in Data Contributor, ACR Pull,
  Search Index Data Contributor, Storage Blob Data Contributor, and Key Vault
  Secrets User roles.
- AILZ grants the Foundry project identity Search Index Data Reader, Storage
  Blob Data Reader, and a registry-mode-compatible pull role when hosted mode
  is enabled. The deployer receives Azure AI Project Manager only in hosted
  mode.
- The AILZ hosted-agent contract and ACR agent-pool firewall contract tests
  passed. No subscription-wide role was added by this branch.
- Static RBAC does not satisfy #591: the live gate still requires caller/group
  identity to reach retrieval.

## 8. Gate checklists

### #597 — private hosted image supply chain

- [x] Dedicated VNet-connected pool reaches `Succeeded`.
- [x] Firewall rule collection includes all five documented service-tag paths.
- [x] `az acr build --agent-pool` builds and pushes the corrected derivative.
- [x] ACR remains Premium with public network access disabled.
- [x] Tag resolves to a manifest digest and digest pull/inspection succeeds.
- [ ] Foundry deploys and serves the immutable digest.
- [ ] A second corrected digest serves live, then rollback to the first digest serves live.

### #592 — three runtime modes

- [x] Exact pin evidence captured.
- [ ] Classic: three apps, streaming, two turns, persistence, telemetry.
- [ ] Hosted/no-panel: two apps, no orchestrator app, hosted Responses stream,
      managed conversation continuity, no panel.
- [ ] Hosted/panel: hosted chat plus working administrative panel behavior.
- [ ] Classic → hosted/no-panel → hosted/panel transition succeeds.
- [ ] Hosted false fallback recreates and serves classic topology.

### #591 — authorization isolation

- [ ] Two approved synthetic/existing identities belong to different Entra groups.
- [ ] Restricted synthetic content is indexed with the authorized group ACL.
- [ ] Authorized identity retrieves/cites it through the hosted path.
- [ ] Unauthorized identity cannot retrieve or infer it in answers, citations,
      tools, direct retrieval, or telemetry.
- [ ] Hosted/tool logs contain no bearer token or protected content.
- [ ] Missing identity and failed downstream authorization fail closed without fallback.

## 9. Validation proof

| Check | Command/evidence | Result | Timestamp |
| --- | --- | --- | --- |
| Worktree base | `HEAD == origin/develop` | Pass | 2026-08-04 |
| Manifest pins | `manifest.json`, submodule, exact component checkouts | Pass | 2026-08-04 |
| Region quota scan | Current `az quota`, service usage, Resource Graph | Pass | 2026-08-04 |
| Official region support | Hosted agents + ACR Tasks agent-pool documentation | Pass | 2026-08-04 |
| Azure authentication | `azd auth login --check-status`; scoped `az account show` | Pass | 2026-08-04 |
| AZD environment | Unique local environment; authorized subscription; East US 2; isolation and dedicated pool enabled | Pass | 2026-08-04 |
| JSON/YAML contracts | Parse manifest, parameters, rollback, root and hosted AZD manifests | Pass | 2026-08-04 |
| Python suites | `pytest tests config/search/tests config/governance/tests -q` | 166 tests and 80 subtests passed | 2026-08-04 |
| Hook syntax | PowerShell AST parse and Git Bash `-n` for all lifecycle hooks | Pass | 2026-08-04 |
| Bicep build/lint | Exact AILZ v2.4.1 `main.bicep` | Pass with pre-existing warnings only | 2026-08-04 |
| Template size | Compiled template size ratchet | 4,887,679 bytes / 4.661 MiB; below 4.7 MiB fail and 5.0 MiB ceiling | 2026-08-04 |
| Hosted contract | `Test-HostedAgentContract.ps1` | 10 checks passed | 2026-08-04 |
| Private ACR pool contract | `Test-AcrTaskAgentPoolFirewallContract.ps1` | 8 checks passed | 2026-08-04 |
| AILZ deterministic preflight tests | `Invoke-PreflightChecks.Tests.ps1` | 43 checks passed | 2026-08-04 |
| Live regional preflight | GPT-RAG + AILZ checks against configured environment | 0 failures; two expected capacity/security warnings and one billing info | 2026-08-04 |
| Package validation | `azd package --no-prompt` | Pass | 2026-08-04 |
| Azure Policy | MCP attempted first; CLI fallback reviewed effective readable assignments | Pass; isolated topology complies with known modify policies | 2026-08-04 |
| Provision preview | `azd provision --preview --no-prompt` | Pass in 42 seconds; create-only summary | 2026-08-04 |
| Preview side effect | Resource count in preview-created environment group | 0 workload resources | 2026-08-04 |
| Hosted azd extension | `azd ai agent --help` | v1.0.0-beta.8 started successfully | 2026-08-04 |
| Private ACR pool | AILZ v2.4.1 live state | S1/count 1/VNet-connected/Succeeded | 2026-08-04 |
| Private registry posture | Management-plane state during builds | Premium; public network access disabled | 2026-08-04 |
| Exact orchestrator build | `az acr build --agent-pool` at commit `779b136d...` | Succeeded; base digest `sha256:04f4d947bc7703902c2a7360551ac940d3aa903cc19b82eb3b99198840283a85` | 2026-08-04 |
| Hosted derivative A | Immutable base digest pull + hosted `CMD` build/push | Succeeded; digest `sha256:972993a914a1c841dd06f83f9721b99a6fc45c90187e15e6bf374640d618dadc` | 2026-08-04 |
| Hosted derivative B | Second immutable rollback candidate | Succeeded; digest `sha256:eb10ee05a6541c5e452c4c88c7d8cf73846550e0c695a69419c559a80afc45a9` | 2026-08-04 |
| Exact UI build | `az acr build --agent-pool` at commit `5328ec7e...` | Succeeded; digest `sha256:74fed3b24e6c0b8705ce3e7f26be89a8d08e78ddd3272e24a40140e2167d311a` | 2026-08-04 |
| Exact ingestion build | `az acr build --agent-pool` at commit `cb9f1a08...` | Succeeded; digest `sha256:49b3f79a59d1ef71be742a3e75576f9b10580af90ee368e7612004767171c81f` | 2026-08-04 |
| Azure hosted/runtime deploy | Foundry serve/rollback and mode matrix | Blocked before execution by external resource-group deletion | 2026-08-04 |

**Validated by:** `azure-validate`

Validation found and fixed two repository regressions before deployment:

1. `util.prereqs` failed to resolve the Windows `az.cmd` shim and emitted
   non-ASCII console output incompatible with the default Windows code page.
2. A governance test incorrectly required the live candidate manifest to remain
   on v3.7.0 instead of validating the preserved governance combination in the
   explicit rollback contract.

Exact-pin source review also found a release-gate gap that validation does not
waive: the hosted UI calls the agent with its service identity, the hosted
entrypoint builds `user_context={}`, and no caller token/group context reaches
retrieval. #591 therefore cannot pass at these pins through the native path or
an unapproved fallback.

## 10. Documentation consistency

Documentation PR #607 (AILZ v2.4.1 pin) and PR #608 (private hosted build
guidance) are merged into the `docs` branch. If live validation reveals a
user-visible defect requiring code/configuration changes, every affected docs
page will be updated in the same coordinated change.

## 11. Execution and cleanup

- [x] Analyze workspace and exact pins.
- [x] Confirm authorized subscription.
- [x] Compare supported regions with current quotas.
- [x] Select AZD/Bicep recipe and isolated architecture.
- [x] Record user authorization of this plan from the task prompt.
- [x] Mark plan ready for `azure-validate`.
- [x] Complete static validation.
- [ ] Provision and execute remaining #597 hosted serve/rollback gates.
- [ ] Execute #592 mode matrix.
- [ ] Execute #591 positive and negative identity tests.
- [x] Post sanitized evidence and close only passing issues.
- [ ] Delete the disposable resource group.
- [x] Remove synthetic identities/groups/content created solely for validation
      (none were created because #591 failed before identity setup).
- [x] Confirm no billable validation resource remains.
- [ ] If Azure retains a platform-owned zero-cost orphan, record exact sanitized
      proof of the provider-owned deletion blocker.

No release, tag, package publication, or umbrella release preparation is in
scope.

### Deployment blocker

Two independently named, actively provisioning East US 2 validation groups
were deleted by a concurrent process authenticated as the delegated user. The
second deletion is proven by Azure Activity Log as an explicit resource-group
delete request at `2026-08-04T20:22:08Z` (correlation
`502c1e98-470f-4c9c-8dda-674a734e4a75`), not an ARM capacity failure or an azd
rollback. Azure resource-group deletion cannot be canceled.

The first environment completed the AILZ v2.4.1 private build path before it was
deleted, so the #597 pool/build/push/pull-by-digest evidence above is valid.
Foundry hosted deployment, live digest rollback, the #592 runtime matrix, and
telemetry could not run before the registry, project, and Container Apps were
removed. A third paid deployment is prohibited until the concurrent cleanup
actor is positively stopped.

The environment remained a single East US 2 deployment. Live East US 2 Search
allocation returned `InsufficientResourcesAvailable`, so the supported
`AZURE_SEARCH_LOCATION=francecentral` parameter placed both Search services in
France Central while their private endpoints and all other resources remained
in the East US 2 environment/VNet. This was a capacity fallback inside the same
resource group, not a second environment.

A later full apply exposed a separate deterministic AILZ v2.4.1 defect after
both France Central Search services reached `Succeeded`: generated
`Microsoft.Search/searchServices/sharedPrivateLinkResources` names exceed
Azure's 60-character limit for ordinary CAF/azd names (61 characters for the
`foundry_account` variant and 71 for `cognitiveservices_account`). A <=7
character azd environment name is the exact-pin operational workaround. The
correct fix is a bounded, collision-safe upstream naming contract with compiled
template tests; no submodule hand-edit, AILZ tag, or umbrella pin is authorized
in this validation.

The source-level release blockers remain independent of this Azure deletion:

- #591 cannot pass at the exact pins because caller identity does not reach
  Toolbox/retrieval. Coordinated UI and orchestrator feature branches are
  implementing the fail-closed native contract without tags or releases.
- Hosted/panel at the exact ingestion pin exposes the same job dashboard in
  both hosted modes and does not implement the frozen history/feedback panel
  boundary. A coordinated ingestion feature branch is addressing that contract.

Cleanup removed all billable resources from both interrupted attempts and the
previously leaked validation environment. The final cross-group count is zero
for ACR pools/registries, Search, Cosmos DB, Container Apps environments, VMs,
Firewalls, Bastion, NAT Gateways, and Public IPs. Azure is asynchronously
deleting the remaining zero-cost shells.
