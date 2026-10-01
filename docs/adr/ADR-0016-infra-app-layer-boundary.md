# ADR-0016: Infrastructure and application layer boundary

**Status:** Accepted<br>
**Date:** 2026-10-01<br>
**Owners:** Agent Landing Zone maintainers<br>
**Approver:** Paulo (maintainer)

## Context

Operators need an infrastructure-only deployment, with the application added
later, without a new flag or entry point (spec FR-011 to FR-013). Applications
also need a stable, machine-readable way to discover the foundation they run
on (FR-015f). Repeated provisioning must never reset running application
images (FR-013, SC-005).

Prioritized characteristics and measures:

1. Native verbs: no new verb, flag, or template (FR-011, R7).
2. Re-provision safety: zero published images reset to the placeholder after
   `azd provision` (SC-005, R8).
3. Same security posture as the full deployment: network isolation, managed
   identity, Key Vault, least privilege (FR-012).
4. Fail closed before change; idempotent recovery, no automatic rollback
   (FR-016).

## Alternatives considered

### Option A: azd native split (selected)

- `azd provision` = foundation; `azd deploy` = application; `azd up` = both
  (R7).

### Option B: `DEPLOY_APP=false` flag

- Non-standard and needs more documentation (R7). Rejected.

### Option C: Separate infra-only template

- Duplicates code (R7). Rejected.

### Placeholder policy

- Always reset to the placeholder breaks running apps (R8). Rejected.

### Platform outputs transport

- Environment variables only: not uniformly available to hosted agents. A file
  in storage: extra authentication path (R13). Both rejected.

## Decision

- `azd provision` creates and configures all Azure resources, including one
  Container App per Container App component in the application definition
  running a placeholder image, plus role assignments and App Configuration
  keys, and stops. It publishes no application image (FR-012, R7).
- Hosted-agent components get no placeholder; they are created at
  `azd deploy` (FR-012, R8).
- `azd deploy` builds and publishes images and deploys the application;
  `azd up` does both and remains the documented default (FR-011).
- Reuse `config/deployment/existing_images.py` so a repeated provision keeps
  already-published images; only new Container Apps get the placeholder (R8).
- `postprovision` publishes the platform outputs (Foundry project, ACR, App
  Configuration, Search, Storage, Cosmos DB, identities, network mode) as one
  JSON key `AGENTLZ_PLATFORM_OUTPUTS` plus individual keys, label `agent-lz`,
  validated against `contracts/platform-outputs.schema.json` (v1). Apps read
  it through `APP_CONFIG_ENDPOINT` (R13, FR-015f).
- Removing the application layer requires explicit operator confirmation,
  lists affected resources, and never happens implicitly (FR-012).

## Consequences

- Infrastructure-only environments are ready for `azd deploy` without further
  changes (FR-012, FR-013).
- The platform outputs schema becomes a public contract; changes need a schema
  version bump.
- Under the R14 dual-read transition, components read both the old and the
  `agent-lz` labels for one release.

## Adoption and migration

Implemented in Phase 2 with the application definition (ADR-0017). Rollback
returns to the single `azd up` flow; the platform outputs keys can remain
without affecting components.

## Compliance verification

- Tests for `existing_images.py` prove a second provision resets zero images
  (SC-005).
- Platform outputs are validated against the v1 schema before publishing.
- Lifecycle behavior is checked against
  `specs/002-agent-landing-zone-rebrand/contracts/azd-lifecycle.md`.

## Documentation impact

Central documentation: deployment options (infra only, full), platform outputs
reference, and the "Build your own application" page (FR-019, FR-015h).

## Review trigger

Reassess on azd lifecycle changes, a new platform resource that apps must
discover, or hosted-agent support for pre-created placeholders.
