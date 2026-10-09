# Quickstart: Agent Landing Zone validation

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

This guide lists runnable scenarios that prove the feature works end to end.
It references the contracts and data model instead of repeating them:

- Deployment verbs, steps, binding states, and failure messages:
  [contracts/azd-lifecycle.md](./contracts/azd-lifecycle.md)
- Application definition format:
  [contracts/app-definition.schema.json](./contracts/app-definition.schema.json)
- Platform outputs published to App Configuration:
  [contracts/platform-outputs.schema.json](./contracts/platform-outputs.schema.json)
- Names, renames, and the naming scan:
  [contracts/naming-map.md](./contracts/naming-map.md)
- Entities and deployment options: [data-model.md](./data-model.md)

## Prerequisites

- An Azure subscription where you can create resource groups and assign roles.
- Azure Developer CLI (`azd`), Azure CLI (`az`), Python 3.12+, and Git.
- `azd auth login` and `az login` against the same tenant.
- A **fresh clone** of `Azure/agent-landing-zone` (the renamed umbrella repo).
  Before the rename lands, use this feature branch.
- A **new** `azd` environment for every scenario. The release supports new
  deployments only (FR-004).

Each scenario shows PowerShell first and sh second. Use one validation
environment per scenario and delete it afterwards with `azd down --purge`.

## Acceptance by release

| Release | Scenarios that must pass |
| --- | --- |
| `v4.0.0-preview.1` | S1 (steps 1, 2, 4), S3 (step 1), S4 (steps 1–3), S6; SC-007, SC-008 |
| `v4.0.0` | All scenarios S1–S7; SC-001–SC-007, SC-009 |

## S1 — Full stack with the default trio (US1)

```powershell
git clone https://github.com/Azure/agent-landing-zone.git; cd agent-landing-zone
azd env new <env-name>
azd up
```

```sh
git clone https://github.com/Azure/agent-landing-zone.git && cd agent-landing-zone
azd env new <env-name>
azd up
```

Expected outcome:

1. Provisioning and deployment finish without manual steps.
2. The UI, orchestrator, and ingestion apps run, and a test question returns a
   grounded answer with citations.
3. *(v4.0.0 only)* No resource, App Configuration key, label, container image,
   or UI text contains "gpt-rag" in any spelling (see
   [naming-map.md](./contracts/naming-map.md)).
4. The UI shows the "Agent Landing Zone" name and visual identity.

Repeat S1 with the orchestrator in hosted-agent mode, using the parameter
documented in [azd-lifecycle.md](./contracts/azd-lifecycle.md) (FR-024).

## S2 — Infrastructure only, then the application (US2)

```powershell
azd env new <env-name>
azd provision
azd deploy
```

```sh
azd env new <env-name>
azd provision
azd deploy
```

Expected outcome:

1. `azd provision` creates the foundation and placeholder Container Apps and
   pushes zero application images (SC-005).
2. App Configuration (label `agent-lz`) contains `AGENTLZ_PLATFORM_OUTPUTS`
   and its flat keys. The JSON value validates against
   [platform-outputs.schema.json](./contracts/platform-outputs.schema.json).
3. The environment is bound to the trio.
4. `azd deploy` then deploys the apps, and S1's expected outcomes hold.

Negative check: in a new environment, run `azd deploy` before
`azd provision`. It must fail before any change, with the "run azd provision
first" message from [azd-lifecycle.md](./contracts/azd-lifecycle.md).

Evidence (preview.2, a fresh Basic deployment in uksouth,
`NETWORK_ISOLATION=false`, ACR remote build):

- `azd provision` succeeded. The Container Apps ran placeholder images and
  no application image was pushed before `azd deploy`.
- App Configuration label `agent-lz` holds the platform outputs. Components
  read `agent-lz` first and fall back to `gpt-rag` (R14 dual-read,
  preview.2 tags).
- `azd deploy --no-prompt` built and deployed the trio at the manifest pins
  (ui `v3.0.0-preview.2`, orchestrator `v5.0.0-preview.2`, ingestion
  `v3.0.0-preview.2`). Smoke test: UI `/` 200, ingestion `/healthz` 200,
  orchestrator `/docs` 200. The orchestrator has no health route.
- The negative check is covered by `tests/test_provision_only.py` (T037).
- Pin rules found during validation: `app-definition.json` `source.commit`
  must equal the manifest pin, and each sibling component checkout's HEAD
  must equal its pin, or preDeploy stops before any change.
- Known environment issue: subscriptions whose policy disables Key Vault
  public access return 403 to postProvision secret writes when
  `NETWORK_ISOLATION=false`. Run from an allowed network, or use
  network isolation.

## S3 — Documentation and landing page (US3)

1. Open the repository README. It is a short landing page that links to the
   central documentation and lists the deployment options (FR-018). The preview
   lists only the options that ship in the preview.
2. *(v4.0.0)* The central documentation covers every deployment option, both
   orchestrator modes, and custom applications (FR-019).

## S4 — Short links (US4)

1. Every product short link listed in the documentation resolves to an Agent
   Landing Zone page.
2. Legacy GPT-RAG short links redirect or show a clear move notice.
3. A link that is not yet migrated is recorded as a known item in the release
   notes. It does not block the release (FR-020).

Evidence after the repository rename (`curl -sI`):

| Legacy URL | Result |
| --- | --- |
| `github.com/Azure/GPT-RAG` | 301 → `Azure/agent-landing-zone` |
| `github.com/Azure/gpt-rag-ui` | 301 → `Azure/agent-app-ui` |
| `github.com/Azure/gpt-rag-orchestrator` | 301 → `Azure/agent-app-orchestrator` |
| `github.com/Azure/gpt-rag-ingestion` | 301 → `Azure/agent-app-ingestion` |
| `azure.github.io/agent-landing-zone/` | 200 |
| `azure.github.io/GPT-RAG/` | 404 (GitHub Pages does not redirect; `Azure/azure.github.io` is archived, so a redirect page needs an org admin to unarchive it, or use an aka.ms link) |
| `aka.ms/gpt-rag` | 200, redirects to `github.com/Azure/agent-landing-zone` |
| `azure.github.io/AI-Landing-Zones/agent-landing-zone/` | 200 (central docs section, 11 pages, Azure/AI-Landing-Zones#141) |
| Legacy `docs` branch pages | All 44 pages carry a moved notice pointing to the central section (#756) |
## S5 — Validate an application definition (US5)

```powershell
python -m config.appdefinition --validate samples/custom-app/containerapp
python -m config.appdefinition --validate samples/custom-app/hosted
```

```sh
python -m config.appdefinition --validate samples/custom-app/containerapp
python -m config.appdefinition --validate samples/custom-app/hosted
```

Expected outcome:

- A valid definition prints a success message and exits with code 0.
- In a copy of the sample, remove a required field or request a capability
  profile that does not exist. The command exits with a non-zero code and
  prints the JSON pointer to the bad field (FR-015d, FR-016).

## S6 — Naming scan (FR-002, FR-003)

```powershell
python -m pytest tests/test_naming_inventory.py -q
```

```sh
python -m pytest tests/test_naming_inventory.py -q
```

Expected outcome: the test passes with no `gpt-rag` matches outside the
allow-list in [naming-map.md](./contracts/naming-map.md). In
`v4.0.0-preview.1` the allow-list still holds the temporary Phase 2 entries;
in `v4.0.0` they are gone, so the same command proves the full rename.

## S7 — Custom application, both hosting modes (US5, SC-009)

```powershell
azd env new <env-name>
azd env set AGENTLZ_APP_DEFINITION samples/custom-app/containerapp
azd up
```

```sh
azd env new <env-name>
azd env set AGENTLZ_APP_DEFINITION samples/custom-app/containerapp
azd up
```

Replace the all-zero component source pin with the actual checkout HEAD before
deployment. Run this once with `samples/custom-app/containerapp` and once in a
separate environment with `samples/custom-app/hosted`. The definition folder
contains `azure.yaml`; `components[].path` selects its service source folder.

Expected outcome:

1. One `azd up` from a fresh clone deploys the sample. In hosted-agent mode
   this follows the hosted path in
   [azd-lifecycle.md](./contracts/azd-lifecycle.md), including the smoke test.
2. The sample receives only the capability profiles it declared (FR-015e).
3. The environment is bound to the sample definition.

Negative checks. Both must fail **before any Azure change**:

- Point `AGENTLZ_APP_DEFINITION` at an invalid definition and run `azd up`.
  The output includes the JSON pointer to the error.
- On the bound environment, select a definition with a different application
  `id` (for example, point it at the trio)
  and run `azd up`. The output reports a binding mismatch and says to create a
  new azd environment (FR-015g).

Re-running `azd up` with the same definition is idempotent (FR-016).

## Acceptance status (2026-10-09)

UI `v3.2.1` and umbrella `v4.2.2` were published. Their publication does not
close the outstanding runtime acceptance scenarios:

- Classic foundation resources were provisioned, but post-provision governance
  failed with Key Vault `ForbiddenByConnection`: public access was disabled
  and the validation vault had no private endpoint. Governance subsequently
  passed from the jumpbox over approved recovery private endpoints, using
  the exact release source and managed identity. Continuity, Container Apps
  and Search setup also passed. Application deployment completed, but the
  latest frontend revision is unhealthy with the same vault connection denial.
  An HTTP 200 came from the old placeholder, not a healthy application.
  Authenticated grounded answers and ingestion startup remain unverified.
- Hosted-panel foundation, private governance recovery, continuity, Container
  Apps and Search setup passed. The pinned hosted image was built and resolved
  to an immutable digest. The release's quota preflight treats an existing
  allocation as a new request. Its corrective branch now passes both real
  preflight gates, crediting only verified matching deployments and checking
  incremental capacity. That does not prove the hosted deploy handoff.
  The separate network-isolated foundation and full post-provision hook
  completed from the jumpbox. Owner recovery reconciled the already-declared
  native Cosmos grants; the temporary management permission was then revoked.
  The private pinned image also built successfully after firewall denies
  identified the frontend lockfile's Azure Artifacts feeds. The existing
  application-specific build allow-list now includes those four feeds and their
  verified blob CDN, restricted to build-subnet HTTPS. The immutable image
  provenance was synchronized without credentials, and the actual hosted
  handoff preview passed.
  The private Owner ARM handoff and full managed post-provision hook passed.
  Project-scoped Foundry User resolved the runner's agent-authoring denial after
  propagation. Owner reconciled the three discovered runtime grants without
  granting the runner role-management permissions. Normal root deployment then
  completed, and a separate managed-identity greeting passed the strict terminal
  Responses validator. These are corrective-source results, not pristine release
  acceptance or delegated-user retrieval evidence.
  Initial UI and ingestion startup failed because OAuth configuration was
  absent. A dedicated single-tenant evaluation registration now exposes the UI's
  own API scope. Its short-lived credential was delivered encrypted to the
  private runner, stored only in Key Vault, and referenced in App Configuration
  with label `agent-lz`; tenant credential-lifetime policy was preserved.
  A persistent Key Vault-backed Chainlit signing key was also configured.
  Both intended pinned revisions are now Healthy/RunningAtMaxScale, match
  latestReadyRevisionName, and receive 100% of traffic; placeholders no longer
  serve the application. Private probes verified the real UI, enabled Entra
  provider, correct login redirect, ingestion health, and HTTP 401 on
  unauthenticated panel data access. Authentication has not been bypassed.
  Actual user login/consent, user-delegated OBO, grounded answers, citations,
  and positive document authorization remain unverified. An OAuth resource
  token diagnostic did not invoke the agent and is not OBO acceptance.
  A subsequent negative runtime test acquired a valid Foundry resource token
  for the dedicated evaluation service principal, which has no project role.
  The actual hosted invocation returned a structured HTTP 403 authorization
  rejection. The project endpoint resolved entirely inside the evaluation
  spoke. All private foundation endpoint connections were Approved/Succeeded;
  Foundry, ACR, and Key Vault public access remained Disabled, ACR admin
  authentication remained disabled, and Key Vault RBAC remained enabled.
  Runtime grants were rechecked at their exact scopes: App Configuration
  Data Reader on the store, OpenAI User on the model account, and Secrets
  User only on AUDIT-HMAC-KEY. This is hosted-principal isolation evidence,
  not delegated-user or document-authorization acceptance, and does not
  replace deploying the custom hosted sample.
- The evaluation VPN Gateway was provisioned and protected with `keep=true`
  and a deletion lock. Hub/spoke peerings are Connected with gateway transit.
  Private DNS and managed-identity governance calls succeeded from the actual
  jumpbox. Client VPN authentication and full delegated-user hosted runtime
  acceptance remain unverified.
- Classic runtime connectivity cannot be repaired by adding an endpoint to its
  current Container Apps environment: its `vnetConfiguration` is null and the
  classic resource group has no virtual network. The existing recovery
  endpoints make services reachable from the private jumpbox, not from apps
  in the Azure-managed network. Azure does not support changing that
  environment's network type after creation
  ([Azure Container Apps networking](https://learn.microsoft.com/azure/container-apps/networking)).
  Recovery requires a separate
  VNet-integrated environment; public Key Vault access was not enabled and
  existing apps/resources were not deleted or silently replaced.
- A fresh S7 foundation cannot use the current default Standard embedding
  allocation unchanged: live westus3 usage is 300 of 350, leaving 50 while
  the default new deployment requests 100. Existing-allocation credit is
  valid only for an actual matching deployment, not a fresh account. Both
  sample definitions validate, and the focused schema, roles, binding,
  composition, and custom-hook suite passed 43 tests and 28 subtests.
  Those checks do not constitute a successful one-command S7 deployment.
- Separate Container App and hosted sample evaluations now use 20 new
  Standard embedding units each in evaluation-only parameter copies. Published
  defaults are unchanged. Both real preProvision gates and composed previews
  passed with distinct nonoverlapping spokes and independent application
  bindings. Initial provisioning failed on each Container Apps private endpoint
  with provider `InternalServerError`, not a proven naming conflict. Retrying
  only the exact failed endpoint module, with unchanged exported parameters and
  a no-deletion what-if, recovered both endpoints to Succeeded/Approved.
  Reverse VPN gateway-transit peerings and direct runner-to-spoke peerings are
  Connected. Normal root provisioning has been resumed; full configuration,
  private DNS resolution, custom image builds, application responses, and
  repeat deployment are not yet verified.
- Validation found directory-selection, custom-project working-directory,
  and hosted greeting-protocol defects. The corrective change passes
  598 tests and 591 subtests (4 skipped), but those offline results do not
  establish a successful S7 Azure deployment or retroactively validate
  the published release.
- Read-only checks against the actual private environment binding accepted
  the exact-release default definition, rejected a valid different application
  ID with exit 2, and rejected an unsupported capability with exit 1. The
  environment-file hash was unchanged. These negatives do not establish
  a successful custom-application deployment or repeated live provisioning.
- Validation also found false-success logging when an Entra-only Foundry
  account rejects evaluation API keys, and a missing Cosmos database-name
  handoff for the administrative panel. The corrective branch respects disabled
  local authentication and reads published database settings before assigning
  the unchanged container-scoped roles. Its live panel recovery created four
  narrow grants; these fixes are not in the published release.
- The pinned orchestrator still exposes the legacy `GPT-RAG Orchestrator`
  OpenAPI title. No branding acceptance or new component release is claimed.

T035, T085, T098, and T093 remain open until their actual runtime outcomes
are captured. No network policy was disabled to obtain a passing result.

## Fallback check (R16)

If the hosted-agent automation misses the 2026-10-09 deadline, S7's
hosted-agent run is replaced with the manual procedure described in
[research.md](./research.md) R16. The schema, the validator (S5), the platform
outputs (S2), and the sample must still ship.
