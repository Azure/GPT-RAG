# ADR-0018: `v4.0.0` supports new deployments only

**Status:** Accepted<br>
**Date:** 2026-10-01<br>
**Owners:** Agent Landing Zone maintainers<br>
**Approver:** Paulo (maintainer)

## Context

Agent Landing Zone `v4.0.0` changes the App Configuration label, environment
variable prefixes, image names, and repository names (ADR-0014; spec FR-002,
FR-002a), incorporates the infrastructure (ADR-0015), and adds application
binding (ADR-0017). The preview `v4.0.0-preview.1` ships the public rebrand
before the runtime renames of Phase 2 (R14, R15). Releases are dated:
preview by 2026-10-02, `v4.0.0` by 2026-10-09 (SC-007).

Prioritized characteristics and measures:

1. Release date fixed (SC-007).
2. Existing GPT-RAG environments keep running on their tags (FR-004).
3. One short, unambiguous note in release notes and docs (FR-004, FR-009).

## Alternatives considered

- **In-place upgrade from GPT-RAG**: requires migrating labels, identifiers,
  resources, and bindings in live environments; not feasible by the release
  date. Rejected.
- **Upgrade from the preview to `v4.0.0`**: the preview predates the runtime
  renames, so in-place upgrade would need its own migration path. Rejected.

## Decision

- `v4.0.0` supports new deployments only. Release notes and documentation
  state in one short note that existing GPT-RAG environments are not upgraded
  and can keep running on their GPT-RAG release, whose tags stay available
  (FR-004, FR-009).
- `v4.0.0-preview.1` is a pre-release not recommended for production
  (FR-008). Operators who deploy the preview must redeploy with `v4.0.0`.
- No in-place upgrade path, migration tooling, or upgrade support is provided.

## Consequences

- Former GPT-RAG release tags and the source infra repository's tags remain
  available (FR-010d).
- Users moving to Agent Landing Zone create a new environment and redeploy
  their data and configuration.
- R14 dual-read exists for component rollout ordering, not for upgrading
  deployed environments.

## Adoption and migration

Add the note to the preview and `v4.0.0` release notes, the README landing
page, and the central documentation.

## Compliance verification

Release checklist confirms the note is present in the release notes and the
documentation, and that prior GPT-RAG tags are untouched.

## Documentation impact

Release notes, README landing page, and central deployment documentation.

## Review trigger

Reassess if there is significant demand for an upgrade path, or before a
future major release that could support in-place upgrade.
