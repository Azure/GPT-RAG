# Data Model: Agent Landing Zone rebrand

**Feature**: `002-agent-landing-zone-rebrand` | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

This document defines the entities that the rebrand, the infra-only option, and
custom applications (FR-015, FR-016) introduce or change. Machine-readable
contracts live in [contracts/](contracts/).

---

## AppDefinition

The application deployed on top of the landing zone. One per `azd` environment
(FR-015g). Stored as `app-definition.json` at the root of the application folder.
The umbrella repo ships one for the default trio.

| Field | Type | Required | Rules |
|---|---|---|---|
| `schemaVersion` | integer | yes | Must equal `1`. |
| `id` | string | yes | Slug, `^[a-z][a-z0-9-]{2,39}$`. Stable across redeploys; bound to the environment. |
| `displayName` | string | no | Free text, max 80 chars. Used in logs only. |
| `components` | array of [Component](#component) | yes | `minItems: 1`. Component `name` values are unique. |
| `settings` | array of [SettingKey](#settingkey) | no | App-level App Configuration keys shared by all components. |

**Validation (FR-015d/e, R10)** — runs in `preprovision`, before any Azure change:

1. JSON Schema 2020-12 ([contracts/app-definition.schema.json](contracts/app-definition.schema.json)), `additionalProperties: false` at every level.
2. Semantic rules: every profile is known; every source is pinned; every `path` is
   relative and stays inside the application folder; the folder has an
   `azure.yaml` whose services match the component names; no `hooks`, no URLs, no
   role names or role IDs anywhere.
3. Failure stops the run with the JSON pointer of the offending field (FR-016).

**Relationships**: owns 1..n Component; bound to one [EnvironmentBinding](#environmentbinding).

---

## Component

One deployable unit of the application.

| Field | Type | Required | Rules |
|---|---|---|---|
| `name` | string | yes | Slug `^[a-z][a-z0-9-]{1,23}$`; equals the `azure.yaml` service name. |
| `kind` | enum | yes | `containerapp` or `azure.ai.agent`. |
| `path` | string | yes | Relative path to the component source inside the app folder. |
| `source` | object | yes | Exactly one of `{ "commit": "<40-hex sha>" }` or `{ "imageDigest": "sha256:<64-hex>" }`. Tags and branches are rejected (FR-015e). |
| `profiles` | array of enum | yes | Values from [CapabilityProfile](#capabilityprofile); `base` is implicit and must not be listed. May be empty. |
| `ingress` | enum | `containerapp` only | `external` or `internal`. Default `internal`. Ignored when network isolation forces internal. |
| `resources` | object | `containerapp` only | `cpu` in {0.25, 0.5, 0.75, 1.0, 1.5, 2.0}; `memory` in matching `Gi` values. Default 0.5 / 1.0Gi. |
| `settings` | array of SettingKey | no | Component-scoped App Configuration keys. |

**Rules**

- `azure.ai.agent` components cannot declare `ingress` or `resources`; their runtime
  is the Foundry hosted-agent runtime (FR-015c, R9).
- Mixed apps are allowed: 0..n `containerapp` plus 0..n `azure.ai.agent`, at least one in total.
- Placeholder images are created in `postprovision` for `containerapp` only.

**State transitions** (per deploy run)

```text
declared ──validate──▶ valid ──provision──▶ provisioned ──deploy──▶ deployed
    │                                │                        │
    └──invalid (stop)                └──failed (stop, rerun)  └──failed (stop, rerun)
```

Re-running the same command is idempotent (FR-016). No automatic rollback.

---

## SettingKey

An App Configuration key the application expects.

| Field | Type | Required | Rules |
|---|---|---|---|
| `key` | string | yes | `^[A-Z][A-Z0-9_]{1,63}$`. Must not start with `AGENTLZ_` (reserved for platform outputs). |
| `value` | string | no | Literal default. Mutually exclusive with `secret`. |
| `secret` | boolean | no | When `true`, the key is created as a Key Vault reference with an empty secret the operator fills. |

All keys are written with label `agent-lz`.

---

## CapabilityProfile

Fixed, versioned table in `config/appdefinition/profiles.py` (R12). An application
never names roles directly. The table is the only source of role assignments for
application identities.

| Profile | Azure roles granted | Scope | Trio usage |
|---|---|---|---|
| `base` *(implicit)* | App Configuration Data Reader, AcrPull, Key Vault Secrets User | App Config store, ACR, Key Vault | all |
| `model-user` | Cognitive Services User, Cognitive Services OpenAI User | Foundry account | orchestrator, ingestion |
| `retrieval-reader` | Search Index Data Reader, Storage Blob Data Reader | Search service, Storage account | orchestrator |
| `conversation-store` | Cosmos DB Built-in Data Contributor | Cosmos DB account | orchestrator, ingestion |
| `blob-delegator` | Storage Blob Data Reader, Storage Blob Delegator | Storage account | ui |
| `ingestion-writer` | Search Index Data Contributor, Storage Blob Data Contributor | Search service, Storage account | ingestion |

**Trio mapping** (must reproduce `main.parameters.json` `containerAppsList` exactly):

| Component | Profiles |
|---|---|
| `ui` (`FRONTEND_APP`) | `blob-delegator` |
| `orchestrator` (`ORCHESTRATOR_APP`) | `model-user`, `retrieval-reader`, `conversation-store` |
| `ingestion` (`DATA_INGEST_APP`) | `model-user`, `conversation-store`, `ingestion-writer` |

**Out of scope for profiles**: role assignments owned by platform features —
continuity (Foundry Agent Consumer, User Identity Impersonation, Key Vault Secrets
User for the agent identity), panel (Cosmos data roles), and hosted-agent access
(`config/deployment/hosted_access.py`). These remain in their feature modules and
are applied when the feature is enabled, unchanged by this feature.

**Invariant test**: `tests/test_capability_profiles.py` expands the trio's profiles
and asserts the resulting role set equals today's `containerAppsList` roles per app.

---

## PlatformOutputs

What the landing zone publishes for any application (FR-015f, R13). Written in
`postprovision` to App Configuration, label `agent-lz`, as a JSON document under
`AGENTLZ_PLATFORM_OUTPUTS` plus one flat key per field. Schema:
[contracts/platform-outputs.schema.json](contracts/platform-outputs.schema.json).

| Field | Flat key | Notes |
|---|---|---|
| `schemaVersion` | — | `1` |
| `foundry.projectEndpoint` | `AGENTLZ_FOUNDRY_PROJECT_ENDPOINT` | |
| `foundry.accountName` | `AGENTLZ_FOUNDRY_ACCOUNT_NAME` | |
| `registry.loginServer` | `AGENTLZ_ACR_LOGIN_SERVER` | |
| `appConfig.endpoint` | `AGENTLZ_APPCONFIG_ENDPOINT` | Same value as `APP_CONFIG_ENDPOINT`. |
| `search.endpoint` | `AGENTLZ_SEARCH_ENDPOINT` | Absent when Search is disabled. |
| `storage.blobEndpoint` | `AGENTLZ_STORAGE_BLOB_ENDPOINT` | |
| `cosmos.endpoint` | `AGENTLZ_COSMOS_ENDPOINT` | Absent when Cosmos is disabled. |
| `keyVault.uri` | `AGENTLZ_KEYVAULT_URI` | |
| `identities[]` | `AGENTLZ_IDENTITY_<COMPONENT>_CLIENT_ID` | One per `containerapp` component. |
| `network.isolated` | `AGENTLZ_NETWORK_ISOLATED` | `true` / `false`. |

Applications read `APP_CONFIG_ENDPOINT` (injected as an env var) and resolve the
rest from App Configuration. No secrets are published.

---

## ReleaseManifest

`manifest.json` at the repo root. Pins the validated release combination.

| Field | Change |
|---|---|
| `tag` | Umbrella version, e.g. `v4.0.0-preview.1`, `v4.0.0`. |
| `infra.source` | **New.** `{ "repo": "Azure/AI-Landing-Zones", "path": "bicep/infra", "tag": "v2.7.3", "commit": "<sha>" }` — provenance of the copied infra (R4). |
| `ailz_tag` | **Removed** (together with `.gitmodules`). |
| `components[]` | `name`, `repo`, `tag` updated to the renamed repos and new tags (R15). |

`app-definition.json` does **not** live here; the manifest pins versions, the app
definition describes the app.

---

## EnvironmentBinding

The link between an `azd` environment and one AppDefinition (FR-015g, R11).
Persisted with `azd env set`.

| Field | Env var |
|---|---|
| definition path | `AGENTLZ_APP_DEFINITION` (default: repo root `app-definition.json`) |
| bound app id | `AGENTLZ_APP_ID` |

```text
unbound ──first provision──▶ bound(id)
bound(id) ──provision/deploy with same id──▶ bound(id)
bound(id) ──provision/deploy with other id──▶ rejected ("create a new azd environment")
```

---

## DeploymentOption

How the user selects what to deploy (FR-018, R7). No new verbs.

| Option | Command | Result |
|---|---|---|
| Full stack | `azd up` | Infra + app from `AGENTLZ_APP_DEFINITION` (trio by default). |
| Infra only | `azd provision` | Landing zone, platform outputs, and placeholder Container Apps for declared `containerapp` components; zero application images (SC-005). Binds the environment. |
| App only | `azd deploy` | Deploys the bound app to an existing landing zone. |
| Custom app | `azd env set AGENTLZ_APP_DEFINITION <path>` then `azd up` | Infra + the custom app. |

---

## NamingInventoryEntry

One allowed occurrence of a legacy name, used by `tests/test_naming_inventory.py` (R17).

| Field | Rules |
|---|---|
| `path` | Glob, relative to repo root. |
| `pattern` | Legacy token (`gpt-rag`, `GPT_RAG`, `gptrag`, `GPT-RAG`). |
| `reason` | `changelog-history`, `migration-doc`, `dual-read-compat`, `external-reference`. |
| `phase` | `temporary` (Phase 2 runtime identifiers, deleted for v4.0.0) or `permanent`. |

There is a single test with no modes. It fails on any occurrence not covered by an entry.
For `v4.0.0`, the `temporary` entries are deleted, so the same test enforces SC-001.
