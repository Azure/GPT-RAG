# Research: Agent Landing Zone Rebrand and Consolidation

**Feature**: `002-agent-landing-zone-rebrand` | **Plan**: [plan.md](plan.md) |
**Spec**: [spec.md](spec.md)

The Technical Context in `plan.md` has no open `NEEDS CLARIFICATION` items.
This document records the decisions behind it, in Decision / Rationale /
Alternatives format.

## R1. Repository renames and GitHub redirects

- **Decision**: Rename the repositories in place with the GitHub rename
  feature (`Azure/GPT-RAG` → `Azure/agent-landing-zone`, `gpt-rag-ui` →
  `agent-app-ui`, `gpt-rag-orchestrator` → `agent-app-orchestrator`,
  `gpt-rag-ingestion` → `agent-app-ingestion`). Never create a new repository
  with an old name, because that disables the redirect.
- **Rationale**: GitHub redirects web URLs, clone and fetch URLs, issues, PRs,
  and releases after a rename, which covers most of SC-003 for free. History,
  stars, forks, and tags are preserved.
- **Alternatives**: New repositories plus archived originals (loses history
  links and redirects); keeping old names with a new display name (fails
  FR-001 and SC-008).
- 2026-10-01 T057: Azure/agent-landing-zone, agent-app-ui, agent-app-orchestrator, agent-app-ingestion all return 404 (available); re-verify immediately before rename (FR-006).

## R2. Short links and GitHub Pages

- **Decision**: Repoint every `aka.ms` short link to its new destination
  before the preview. Accept that direct visits to the former GitHub Pages URL
  (`azure.github.io/GPT-RAG/`) break, because GitHub does not redirect Pages
  after a rename. Publish a moved-content notice where a page can still be
  served, and list the break in the release notes.
- **Rationale**: Short links are under Microsoft control; Pages redirects are
  not. The spec excludes direct Pages visits from SC-004 (Edge Cases).
- **Alternatives**: Keep a stub `GPT-RAG` Pages repository (would block the
  rename redirect for the main repository); delay the rename (misses SC-007).

## R3. Central documentation location

- **Decision**: Move user-facing docs from the `docs` branch into the central
  Agent Landing Zone documentation site agreed in the weekly sync, with the
  repository README reduced to a short landing page that links to it.
- **Rationale**: Matches the agreement with Bilal and Mate (centralized docs,
  simple landing page) and FR-018/US3.
- **Alternatives**: Keep MkDocs on the renamed repository's Pages (works, but
  keeps two sources of truth with the AI Landing Zones docs).

## R4. Infrastructure incorporation

- **Decision**: Copy the AI Landing Zone Bicep infrastructure at `v2.7.3` into
  `infra/` of the umbrella repository as a normal tracked folder, record its
  provenance (source repo, tag, commit) in `manifest.json` under
  `infra.source`, and remove `.gitmodules` and `ailz_tag` in the same change.
- **Rationale**: FR-002a requires the infra to be part of the Agent Landing
  Zone; a submodule keeps the dependency external and confuses operators who
  clone without `--recursive`. Provenance keeps the copy auditable.
- **Alternatives**: Keep the submodule (fails consolidation); git subtree
  (history noise, harder review); package registry module (no Bicep registry
  workflow in place).
- **Incorporated**: `v2.7.3` at commit
  `97e2375b89dcda4900d75aac9e7ffb7b20cce165` (tree identical to upstream).
- **Proposed upstream README notice (T046, external repository, not pushed)**:
  to be placed at the top of `Azure/bicep-ptn-aiml-landing-zone` `README.md`:

  > [!IMPORTANT]
  > **This pattern now lives in [Azure/agent-landing-zone](https://github.com/Azure/agent-landing-zone).**
  > Starting after `v2.7.3`, the AI Landing Zone Bicep infrastructure is
  > maintained in the `infra/` folder of the Agent Landing Zone repository,
  > which incorporated this repository at `v2.7.3`
  > (`97e2375b89dcda4900d75aac9e7ffb7b20cce165`). Existing tags remain
  > available for current deployments, but new features and fixes land in
  > Agent Landing Zone. Please open new issues and pull requests there. The
  > Terraform module
  > ([terraform-azurerm-avm-ptn-aiml-landing-zone](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone))
  > is unchanged and continues to receive parity updates.

## R5. Bicep and Terraform synchronization

- **Decision**: Bicep remains the source of truth. A workflow
  (`infra-terraform-parity.yml`, moved from the infra repository) detects
  Bicep changes and opens a Terraform sync PR that requires human review.
  The Terraform module is not renamed in this feature.
- **Rationale**: Weekly-sync agreement: keep both languages with automated
  sync and human review.
- **Alternatives**: Bicep only (breaks Terraform users); fully automatic
  sync without review (risk of silent drift).

## R6. AVM resource modules

- **Decision**: Out of scope. Keep current module usage unchanged.
- **Rationale**: The hybrid AVM approach is still being evaluated (dependency
  and maintenance risk); the spec lists it as out of scope.
- **Alternatives**: Adopt AVM now (adds risk to a dated release).

## R7. Infrastructure-only deployment

- **Decision**: `azd provision` creates the foundation plus the application's
  declared Container Apps running a placeholder image, role assignments, and
  App Configuration keys, and stops. `azd deploy` builds and publishes the
  images. `azd up` does both. No new verb or flag is introduced.
- **Rationale**: Uses azd's native split (FR-002, US2) and matches SC-005.
- **Alternatives**: A `DEPLOY_APP=false` flag (non-standard, more docs);
  separate infra-only template (duplicates code).

## R8. Placeholder images and re-provision safety

- **Decision**: Reuse `config/deployment/existing_images.py` so a repeated
  `azd provision` keeps already-published images and only new Container Apps
  get the placeholder. Hosted-agent components get no placeholder; they are
  created at deploy time.
- **Rationale**: The logic and its tests already exist (SC-005: zero images
  reset).
- **Alternatives**: Always reset to the placeholder (breaks running apps).

## R9. Hosted-agent deployment path

- **Decision**: Generalize the current child azd project pattern
  (`hosted-agent/azure.yaml`, `prepareHostedDeployment.*`, image pinned by
  digest, `.azure` copy, `azd deploy <service>`, smoke test) so it runs once
  per component with `host: azure.ai.agent`, for the bundled orchestrator and
  for custom applications alike.
- **Rationale**: The path already passes security and network-isolation
  validation for the bundled orchestrator (FR-015c). Generalizing avoids a
  second hosted code path.
- **Alternatives**: Call the Foundry agent APIs directly from Python (new
  untested path); only support classic for custom apps (rejected by Paulo:
  users want hosted agents).

## R10. Application definition validation (preprovision)

- **Decision**: New package `config/appdefinition/` validates the selected
  definition against `contracts/app-definition-v1.schema.json` (JSON Schema
  2020-12) plus semantic rules (known profiles, pinned sources, local paths,
  no hooks, at least one component, folder has `azure.yaml`) in the
  `preprovision` hook, before any Azure call. It also runs standalone:
  `python -m config.appdefinition --validate <path>`.
- **Rationale**: FR-015d and FR-016 require fail-closed validation before any
  change; the standalone command is required by the FR-015 fallback.
- **Alternatives**: Validate in Bicep (too late, after deployment starts);
  validate only in `predeploy` (provision would already have changed state).

## R11. Environment binding

- **Decision**: At the first provision, write `AGENTLZ_APP_ID=<id>` and the
  resolved definition path to `.azure/<env>/.env` with `azd env set`. Later
  provisions and deploys compare the selected definition's `id` and fail with
  "create a new environment" on mismatch.
- **Rationale**: FR-015g; azd env values are the natural per-environment state
  and need no extra storage.
- **Alternatives**: Tag on the resource group (needs Azure call before
  validation); App Configuration key (same problem, and not available before
  the first provision).

## R12. Capability profiles and RBAC mapping

- **Decision**: A fixed table in `config/appdefinition/profiles.py` maps each
  profile to role definitions and target resources (see
  [data-model.md](data-model.md#capabilityprofile)). The table must cover the
  trio's current role assignments; a test compares the trio's effective roles
  before and after.
- **Rationale**: FR-015e forbids free-form roles; a fixed table keeps
  least-privilege review in one place.
- **Alternatives**: Free-form role lists (rejected by spec); Bicep-only
  mapping (harder to test and to share with validation).

## R13. Platform outputs contract

- **Decision**: `postprovision` publishes the platform outputs (Foundry
  project, ACR, App Configuration, Search, Storage, Cosmos DB, identities,
  network mode) as one JSON App Configuration key `AGENTLZ_PLATFORM_OUTPUTS`
  plus individual keys, label `agent-lz`, validated against
  `contracts/platform-outputs-v1.schema.json`.
- **Rationale**: FR-015f; apps already read App Configuration through
  `APP_CONFIG_ENDPOINT`.
- **Alternatives**: Environment variables only (not available to hosted
  agents uniformly); a file in storage (extra auth path).

## R14. Runtime rename order

- **Decision**: Rename runtime identifiers in Phase 2 in this order:
  1. Components accept both labels (`gpt-rag` and `agent-lz`) and both env
     prefixes for one release, preferring the new ones.
  2. Umbrella switches the App Configuration label to `agent-lz`,
     `GPT_RAG_REPO_ROOT` to `AGENTLZ_REPO_ROOT`, temp prefixes to `agentlz-`,
     and repository-root detection from the folder name `gpt-rag` to the
     presence of `manifest.json` + `azure.yaml`.
  3. The `manifest.json` pin moves to the new component tags.
  Rollback runs in reverse. Details in [contracts/naming-map.md](contracts/naming-map.md).
- **Rationale**: Folder-name detection breaks once the repository is renamed;
  dual reading avoids a flag day across repositories.
- **Alternatives**: Big-bang rename (any partial rollback breaks the stack).

## R15. Release sequencing and versions

- **Decision**: Publish `v4.0.0-preview.1` (Phase 1) by 2026-10-02 and
  `v4.0.0` by 2026-10-09. Components release first (UI `v3.0.0`, orchestrator
  `v5.0.0`, ingestion `v3.0.0`), then the manifest pin, then the umbrella.
- **Rationale**: Major bumps signal the breaking rename (label, env vars,
  repo names); the order follows the `multi-repo-release` skill.
- **Alternatives**: Minor bumps (hide breaking changes).

## R16. FR-015 fallback

- **Decision**: Track one-command custom deployment (FR-015b/c) as a
  release-gate item with a 2026-10-09 decision. If not validated, ship the
  schema, the standalone validator, platform outputs, the sample, and a
  manual procedure page, and list one-command orchestration as pending.
- **Rationale**: Keeps the release date fixed (SC-007).
- **Alternatives**: Slip the release (rejected).

## R17. Naming scan

- **Decision**: `tests/test_naming_inventory.py` scans tracked files for
  `gpt-rag`, `GPT-RAG`, `gptrag`, `GPT_RAG` (case-insensitive) outside an
  allow-list (CHANGELOG history, ADRs, transition statement, the naming map).
  One test, no modes. Identifiers that only change in Phase 2 (App
  Configuration label, `GPT_RAG_*` values) sit in the allow-list as
  temporary entries for `v4.0.0-preview.1`; the Phase 2 work deletes them,
  so the same test enforces SC-001 for `v4.0.0`.
- **Rationale**: Makes SC-001/SC-008 objective and repeatable without an
  internal switch to maintain.
- **Alternatives**: Manual review (not repeatable); a preview/release mode
  variable (rejected as unnecessary internal complexity).
