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
| `azure.github.io/GPT-RAG/` | 404 (GitHub Pages does not redirect; known item) |

## S5 — Validate an application definition (US5)

```powershell
python -m config.appdefinition --validate samples/custom-app/app-definition.json
```

```sh
python -m config.appdefinition --validate samples/custom-app/app-definition.json
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
azd env set AGENTLZ_APP_DEFINITION samples/custom-app
azd up
```

```sh
azd env new <env-name>
azd env set AGENTLZ_APP_DEFINITION samples/custom-app
azd up
```

Run this once with the sample's Container Apps variant and once with its
hosted-agent variant.

Expected outcome:

1. One `azd up` from a fresh clone deploys the sample. In hosted-agent mode
   this follows the hosted path in
   [azd-lifecycle.md](./contracts/azd-lifecycle.md), including the smoke test.
2. The sample receives only the capability profiles it declared (FR-015e).
3. The environment is bound to the sample definition.

Negative checks. Both must fail **before any Azure change**:

- Point `AGENTLZ_APP_DEFINITION` at an invalid definition and run `azd up`.
  The output includes the JSON pointer to the error.
- On the bound environment, change the definition (or point it at the trio)
  and run `azd up`. The output reports a binding mismatch and says to create a
  new azd environment (FR-015g).

Re-running `azd up` with the same definition is idempotent (FR-016).

## Fallback check (R16)

If the hosted-agent automation misses the 2026-10-09 deadline, S7's
hosted-agent run is replaced with the manual procedure described in
[research.md](./research.md) R16. The schema, the validator (S5), the platform
outputs (S2), and the sample must still ship.
