# GPT-RAG issue 571 deployment preparation plan

## Status

Validated

## Mode

MODIFY

## Issue

- Azure/GPT-RAG#571: establish a practical governance baseline and auditable AI activity trail.
- The user has approved autonomous preparation and implementation.
- This plan changes the existing GPT-RAG AZD/Bicep deployment recipe in place.
- No Azure deployment, destructive resource operation, or resource-group deletion is authorized.

## Existing deployment recipe

- Azure Developer CLI orchestrates the existing deployment through `azure.yaml`.
- The root repository supplies `main.parameters.json`, `manifest.json`, lifecycle hooks, and post-provision configuration.
- `infra/` remains the pinned `Azure/bicep-ptn-aiml-landing-zone` submodule. It will not be edited in place.
- Post-provision configuration uses Azure CLI/SDK authentication, Azure App Configuration label `gpt-rag`, Azure Key Vault, Azure Container Apps, and Azure AI Search REST APIs.

## Architecture

- Pin `Azure/gpt-rag-orchestrator` v3.8.0 and `Azure/gpt-rag-ingestion` v2.5.0 in the umbrella manifest and future-minor release surfaces.
- Seed metadata-only audit and provenance settings in App Configuration with all feature gates disabled by default.
- Create `AUDIT_HMAC_KEY` once as a cryptographically random 256-bit Key Vault secret when Key Vault is deployed. Reuse the existing value on later runs so ordinary reprovisioning is stable; rotation is an explicit operator action that creates a new Key Vault version. If Key Vault is explicitly disabled, seed only the disabled feature gates and keep audit events off.
- Publish only an App Configuration Key Vault reference for `AUDIT_HMAC_KEY`; never persist or display the secret value in admin settings, files, outputs, or logs.
- Add the ten optional provenance/governance fields to the RAG Azure AI Search index.
- Replace unconditional index delete/recreate with an in-place `PUT` update for existing indexes. Azure AI Search receives the full desired schema while preserving documents for supported additive changes; incompatible changes fail instead of falling back to deletion.
- Preserve the existing creation path for missing indexes and leave unrelated datasource, skillset, and indexer behavior unchanged.
- Keep the orchestrator v3.8.0 logical contract hash `825db8ef40a81e2c19e5d80d37c565b6b47fc9a6540e9881d35cc12b8fde5aab` and wire hash `066c8f5408610ab839d5121d06ca5bc59e8797e551d5c47c875c5ba52f7e0588` aligned in tests and documentation.

## Configuration defaults

### Orchestrator

- `AUDIT_EVENTS_ENABLED=false`
- `AUDIT_SENSITIVE_CONTENT_ENABLED=false`
- `AUDIT_SENSITIVE_CONTENT_FIELDS=`
- `AUDIT_ACTOR_PSEUDONYM_ENABLED=false`
- `AUDIT_SOURCE_EVENT_LIMIT=25`
- `AUDIT_HMAC_KEY_ID=v1`
- `AUDIT_ADDITIONAL_REDACTED_KEYS=`

### Ingestion

- `INGESTION_PROVENANCE_ENABLED=false`
- `INGESTION_REQUIRE_GOVERNANCE_METADATA=false`
- `INGESTION_DEFAULT_CLASSIFICATION=unclassified`
- `INGESTION_DEFAULT_RIGHT_TO_USE=not_asserted`

## Azure AI Search schema

The RAG index receives these optional, retrievable fields:

| Field | Azure AI Search type | Attributes |
| --- | --- | --- |
| `provenance_id` | `Edm.String` | filterable |
| `source_uri_id` | `Edm.String` | filterable |
| `source_version_id` | `Edm.String` | filterable |
| `content_checksum_sha256` | `Edm.String` | filterable |
| `ingested_at` | `Edm.DateTimeOffset` | filterable, sortable |
| `ingest_run_id` | `Edm.String` | filterable |
| `data_classification` | `Edm.String` | filterable, facetable |
| `right_to_use` | `Edm.String` | filterable, facetable |
| `retention_class` | `Edm.String` | filterable, facetable |
| `delete_after` | `Edm.String` | filterable, sortable |

`delete_after` records policy intent only. This solution does not automatically purge documents based on that field.

## Security

- Generate key material with Python's operating-system-backed `secrets` module and require exactly 32 random bytes before encoding.
- Read existing secret metadata/value only to preserve idempotency; do not print or serialize the secret.
- Use the existing App Configuration Key Vault reference content type.
- Do not add the secret to the normal App Configuration plaintext import, AZD outputs, Bicep outputs, logs, changelog, or documentation examples.
- Keep sensitive-content capture disabled independently from metadata audit events.
- Preserve fail-closed component validation and prohibited-field redaction in the pinned runtime releases.
- No credentials, secrets, generated resource names, or personal validation
  environment names will be committed. Non-secret Azure scope and principal IDs
  may be recorded when required for exact validation proof.

## Migration and rollback

- Existing deployments receive disabled defaults, so runtime behavior remains unchanged until operators opt in.
- The Search schema update is additive and performed in place. Existing indexed documents remain valid. Ingestion v2.5.0 emits provenance in audit events but does not populate these index fields; they remain empty unless the indexing pipeline explicitly supplies them.
- No automatic or fallback index deletion is allowed. Unsupported schema mutations fail with an actionable error and leave the existing index intact.
- Upgrade sequence: deploy umbrella configuration with the v3.8.0/v2.5.0 pins, run post-provisioning, verify the Key Vault reference and additive index schema, then enable metadata audit/provenance in a non-production environment.
- Rollback sequence: set `AUDIT_EVENTS_ENABLED=false` and `INGESTION_PROVENANCE_ENABLED=false`, keep sensitive capture disabled, and redeploy the prior component tags if required.
- Additive Search fields are harmless to older component versions and do not need removal during rollback.
- Rotating `AUDIT_HMAC_KEY` is explicit: create a new Key Vault secret version and update `AUDIT_HMAC_KEY_ID` so evidence consumers can distinguish pseudonymization epochs.

## UX and documentation advisory

- Steve confirmed the main operator risk is the current unconditional index deletion. The implementation must use in-place updates and must not claim a safe additive migration until tests prove no delete call occurs.
- Provide one umbrella configuration table, link to component guidance, and state that ingestion settings contain no secrets.
- State that audit evidence supports adopter governance work but is not proof of legal or regulatory compliance.
- State that enabling audit events requires the Key Vault secret reference and that `delete_after` does not enforce retention.
- Update the GPT-RAG docs branch in a companion documentation PR.

## Validation

- [x] All validation checks pass
  - [x] AZD installation and authentication
  - [x] `azure.yaml` stable-schema validation
  - [x] Bicep compilation
  - [x] Bicep lint execution
  - [x] Python/config build verification
  - [x] Focused and full relevant tests
  - [x] Static RBAC verification
  - [x] AZD environment/subscription/location validation
  - [x] Required pre-provision hooks
  - [x] `azd provision --preview --no-prompt`
  - [x] AI Landing Zone compiled-template size gate
  - [x] AZD package validation
  - [x] Azure Policy validation

- Focused Python unit tests for App Configuration defaults, stable secret creation/reference behavior, contract pins, Search field types, and no-delete index updates.
- Full relevant GPT-RAG configuration test suite.
- Python compile and JSON/schema assertions.
- PowerShell parser and script validation; shell syntax validation when Bash is available.
- `az bicep build --file infra/main.bicep` and the repository template-size gate when applicable.
- Manifest/version/tag assertions against published v3.8.0 and v2.5.0 releases.
- Docker/config validation through existing repository scripts where applicable.
- `azd provision --preview` or the repository's non-deploy preflight only when the current authenticated AZD context is complete. Treat any empty environment resource group that AZD creates before what-if as a preview-tool side effect, not as workload provisioning.
- Never run `azd provision`, `azd up`, `azd deploy`, `terraform apply`, or any destructive Azure command.

## Role Assignment Verification

- Status: Verified for this change.
- Orchestrator identity: `AppConfigurationDataReader`,
  `KeyVaultSecretsUser`, `SearchIndexDataReader`, and the existing model,
  Cosmos, ACR, and Storage data-plane roles remain scoped through the landing
  zone's per-resource role modules.
- Ingestion identity: `AppConfigurationDataReader` and
  `SearchIndexDataContributor` remain present for provenance configuration and
  indexed-document writes.
- No new management-plane role, resource-group role, subscription role, or
  role-assignment resource was added by this branch.

## Section 7: Validation Proof

| Check | Command / proof | Result |
| --- | --- | --- |
| Exact source | `git rev-parse HEAD`; compare local and remote PR branch | Passed at requested and remote PR head `5ea5f7c983660db0c2ece99b9eb4fd6cd1688485` |
| CLI versions | `azd version`; `az version --output json` | Passed, AZD v1.27.1 and Azure CLI v2.79.0 |
| Authentication | `azd auth login --check-status`; `az account show`; `az account get-access-token --resource https://management.azure.com/` | Passed for `paulolacerda@microsoft.com`; default subscription `mcaps-paulolacerda` (`9788a92c-2f71-4629-8173-7ad449cb50e1`), tenant `16b3c013-d300-468d-ac64-7eda0820b6d3`; token tenant matched |
| Deploying principal | `az role assignment list --assignee-object-id 88e31ae8-65b8-46a2-8b26-fad4e6c305f3 --scope /subscriptions/9788a92c-2f71-4629-8173-7ad449cb50e1 --include-inherited` | Passed; principal has inherited `Owner` at subscription scope, sufficient for previewing resource-scoped role assignments |
| AZD schema | Azure AZD `validate_azure_yaml` on root `azure.yaml` | Passed against the official stable schema |
| AZD environment | `azd env new <unique-local-env> --subscription 9788a92c-2f71-4629-8173-7ad449cb50e1 --location eastus2 --no-prompt`; `azd env set ...`; `azd env get-values` | Passed; isolated local environment used `eastus2`, deploying principal `88e31ae8-65b8-46a2-8b26-fad4e6c305f3`, type `User`, and Standard-mode safe preview values: `NETWORK_ISOLATION=false`, `USE_UAI=false`, `USE_CAPP_API_KEY=false`, `ENABLE_AGENTIC_RETRIEVAL=false`, `RETRIEVAL_BACKEND=foundry_iq`, `DEPLOYMENT_MODE=standalone`, and VM/Bastion/NAT/Firewall deployment flags disabled |
| Required hook | Load `azd env get-values`; `pwsh -NoProfile -File scripts/preProvision.ps1` | Passed. GPT-RAG regional preflight: 0 failures, 2 capacity warnings; required providers and eastus2 locations passed, Container Apps quota passed, both model deployments and quotas passed. Landing-zone preflight: 0 failures, 3 warnings, 1 information item |
| Bicep compile | `az bicep build --file infra/main.bicep` | Passed with existing pinned-submodule warnings only |
| Bicep lint | `az bicep lint --file infra/main.bicep` | Passed with existing pinned-submodule warnings only |
| Template size | `pwsh infra/scripts/Measure-MainJsonSize.ps1 -SkipBuild -WorkingBudgetMB 3.5 -FailThresholdMB 4.7 -ArmHardCeilingMB 5.0` | Passed authoritative gate: 4,872,869 bytes (4.647 MB). Warning above 3.5 MB working budget, below 4.7 MB fail threshold and 5.0 MB ARM ceiling |
| Relevant tests | `python -m unittest config.governance.tests.test_setup config.search.tests.test_governance_schema config.search.tests.test_foundry_iq_templates` | Passed, 131 tests |
| Static checks | `python -m ruff check ...`; `python -m compileall -q ...`; PowerShell AST parse; Git Bash `-n scripts/preProvision.sh scripts/postProvision.sh` | Passed |
| Package | `azd package --no-prompt` | Passed; umbrella package completed successfully |
| Docker | Repository scan | Not applicable: no umbrella Dockerfile or AZD service package |
| Azure Policy | Azure Policy `policy_assignment_list` at subscription scope, followed by ARM what-if | Passed; assignments, including inherited MCAPSGov deny/audit/deploy initiatives, were reviewed and did not block the preview |
| Static RBAC | Review `main.parameters.json`, `infra/main.bicep:3153-3525`, and `infra/constants/roles.json`; assert required role keys and Bicep mappings | Passed. Orchestrator has resource-scoped App Configuration Data Reader, Key Vault Secrets User, and Search Index Data Reader. Ingestion has resource-scoped App Configuration Data Reader, Key Vault Secrets User, and Search Index Data Contributor. The deploying principal receives resource-scoped Key Vault Contributor/Secrets Officer, App Configuration Data Owner, Search Service Contributor, and Search data roles needed by post-provision setup. This PR changes neither `infra/` nor `main.parameters.json` and adds no RBAC assignment |
| Provision preview | `azd provision --preview --no-prompt` | Passed in 1 minute 6 seconds. ARM what-if returned a create-only workload plan with no modify/delete operations and applied no workload resources |
| Preview side effect | `az group show`; `az resource list`; Azure activity log | AZD v1.27.1 created the empty, tagged environment resource group before running what-if at `2026-07-21T12:12:15Z`. The group contains 0 resources. It was not deleted because this validation explicitly prohibited Azure resource or resource-group deletion |

Validation status is **Validated**. All required formal checks passed at exact PR
head `5ea5f7c983660db0c2ece99b9eb4fd6cd1688485`. The change is ready for the
`azure-deploy` workflow, but deployment remains explicitly out of scope for this
validation.

## Handoff proof required

- Feature branch `feature/governance-audit-umbrella-571` was created from
  `origin/develop` commit `e6ba89f3f609d900c0dd32c26999cf7fe4e8dca0`.
- Focused and full relevant configuration suites passed: 131 tests.
- Ruff passed for all changed Python implementation and test files.
- Python compilation, JSON/schema parsing, contract SHA-256 assertions, and
  PowerShell AST parsing passed.
- Tests prove all ten Search fields and their types/attributes, preservation of
  operator-added fields, update-before-cleanup ordering, no index DELETE,
  ETag-guarded updates, and `If-None-Match: *` guarded creation.
- Tests prove 32-byte OS-random key generation, stable secret reuse, plaintext
  key migration without rotation, preservation of operator-managed Key Vault
  references, no plaintext deployment parameter, and fail-closed behavior when
  audit is enabled without Key Vault.
- The full documentation site passed `mkdocs build --strict`.
- `az bicep build --file infra/main.bicep` succeeded with existing submodule
  warnings. The existing AI Landing Zone v2.3.0 template is 4.647 MB and passed
  the authoritative 4.7 MB fail threshold and 5.0 MB ARM ceiling, with a warning
  above the 3.5 MB working budget.
- `azd provision --preview --no-prompt` succeeded at exact PR head in eastus2
  and returned a create-only ARM what-if plan with no modify/delete operations.
  AZD v1.27.1 created an empty environment resource group before what-if; it has
  0 resources and was left untouched because resource-group deletion was
  prohibited.
- Git Bash syntax validation passed for both lifecycle hooks. PowerShell AST
  parsing and the Python module invoked by both hooks also passed.
- Docker validation is not applicable because the umbrella repository has no
  Dockerfile; the pinned component releases were verified as published,
  non-draft, non-prerelease tags.
- No workload resources were deployed, modified, or deleted. AZD preview itself
  created one empty tagged environment resource group before ARM what-if; no
  deletion was attempted.
- Implementation commits:
  `11d65b294cc7a2270e579deddf42c770dc9e1761` and
  `5ea5f7c`.
- Implementation PR, unmerged:
  `https://github.com/Azure/GPT-RAG/pull/573`.
- Documentation commits:
  `2cca8c68f16e0f2ade8fdf4939cf8e9b6335fc5d` and
  `8f00c16`.
- Documentation PR, unmerged:
  `https://github.com/Azure/GPT-RAG/pull/574`.
