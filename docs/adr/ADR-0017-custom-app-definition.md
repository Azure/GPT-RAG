# ADR-0017: Application definition (`app-definition.json` v1)

**Status:** Accepted<br>
**Date:** 2026-10-01<br>
**Owners:** Agent Landing Zone maintainers<br>
**Approver:** Paulo (maintainer)

## Context

The application layer must be a pluggable unit on top of the foundation
(ADR-0016). The bundled trio (UI, orchestrator, ingestion) is the default
application, and operators may deploy a custom application, as Container Apps,
Foundry hosted agents, or both (spec FR-014, FR-015, FR-015a to FR-015h).
Free-form permissions or remote code in a definition would weaken the
least-privilege posture.

Prioritized characteristics and measures:

1. One schema and one flow for bundled and custom applications (FR-015).
2. Fail closed before any Azure call on invalid input (FR-015d, FR-016).
3. Least privilege through a fixed profile table; zero free-form roles
   (FR-015e, R12).
4. One application per environment (FR-015g, R11).
5. Hosted-agent path keeps the bundled orchestrator's security and
   network-isolation posture (FR-015c, R9).

## Alternatives considered

- **Merge the definition into `manifest.json`**: mixes release pins with the
  application contract. Rejected; the files are separate, and the trio's
  definition resolves versions from `manifest.json` (spec clarification).
- **Free-form role lists**: rejected by FR-015e (R12).
- **Bicep-only profile mapping**: harder to test and share with validation
  (R12). Rejected.
- **Validate in Bicep or only in `predeploy`**: too late; state may already
  have changed (R10). Rejected.
- **Bind via resource-group tag or App Configuration key**: needs an Azure
  call before validation or does not exist before the first provision (R11).
  Rejected.
- **Call Foundry agent APIs directly, or classic only for custom apps**: new
  untested path, or rejected by Paulo because users want hosted agents (R9).
  Rejected.

## Decision

- `app-definition.json` v1, schema in
  `contracts/app-definition.schema.json` (JSON Schema 2020-12), declares a
  stable lowercase `id`, one or more components (kind `containerapp` or
  `hosted`), capability profiles, and App Configuration keys (FR-015a).
- A custom application is a local folder with its `app-definition.json` and
  its own `azure.yaml`. The trio's definition and `azure.yaml` live at the
  repository root (FR-015a).
- Selection: `azd env set AGENTLZ_APP_DEFINITION <local path>` before the
  first provision; unset means the bundled trio (FR-015b).
- Validation: `config/appdefinition/` validates schema and semantic rules
  (known profiles, pinned sources by commit or image digest, local paths, no
  hooks, at least one component, folder has `azure.yaml`) in `preprovision`
  before any Azure call, and standalone via
  `python -m config.appdefinition --validate <path>` (R10, FR-015d).
- Capability profiles: fixed table in `config/appdefinition/profiles.py` with
  `base` (implicit), `model-user`, `retrieval-reader`, `conversation-store`,
  `blob-delegator`, `ingestion-writer`. It must reproduce the trio's current
  roles exactly. Feature-owned roles (continuity, panel, hosted access) stay
  in their modules (R12, data-model CapabilityProfile).
- Environment binding: the first provision writes `AGENTLZ_APP_ID` and the
  resolved definition path with `azd env set`; a later provision or deploy
  with a different `id` fails with "create a new environment". Redeploying
  the same application is allowed (R11, FR-015g).
- Hosted components reuse the child azd project pattern
  (`hosted-agent/azure.yaml`, `prepareHostedDeployment.*`, digest-pinned
  image, `azd deploy <service>`, smoke test) once per `host: azure.ai.agent`
  component (R9, FR-015c).
- Fallback: if one-command custom deployment (FR-015b/c) is not validated by
  2026-10-09, `v4.0.0` ships the schema, standalone validator, platform
  outputs, sample, and a manual procedure, listing orchestration as pending
  (R16).

## Consequences

- Definitions cannot request new roles; adding one requires a profile table
  change and review.
- The v1 schema is preview-level in `v4.0.0` and may change in a later
  release (spec assumptions).
- Switching or combining applications in one environment is out of scope.

## Adoption and migration

Phase 2: ship the trio's `app-definition.json`, the validator, profiles, the
binding, and the sample custom application (FR-015h). Rollback removes the
validator hook and returns to `containerAppsList` in `main.parameters.json`.

## Compliance verification

- `tests/test_capability_profiles.py` asserts the trio's expanded profiles
  equal today's `containerAppsList` roles.
- Validator tests cover unknown profiles, unpinned sources, remote URLs, hooks,
  empty component lists, and missing `azure.yaml`, all failing closed.
- Binding tests cover the mismatch message and same-`id` redeploy.
- Sample application deploys in both hosting modes (SC-009).

## Documentation impact

"Build your own application" page, application definition reference, and
capability profile table in the central documentation.

## Review trigger

Reassess on schema v2, a request for a new profile, or a second
Microsoft-maintained application pattern.
