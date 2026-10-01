# ADR-0014: Consolidate GPT-RAG into Agent Landing Zone

**Status:** Accepted<br>
**Date:** 2026-10-01<br>
**Owners:** Agent Landing Zone maintainers<br>
**Approver:** Paulo (maintainer)

## Context

GPT-RAG is delivered as an umbrella repository, three component repositories
(UI, orchestrator, ingestion), and a separately versioned Bicep infrastructure
submodule from `Azure/bicep-ptn-aiml-landing-zone`. The product has grown
beyond a RAG accelerator: it provides a secure foundation for agent
applications, with the bundled trio as the default application. The weekly
sync agreed to present it as one product with centralized documentation
(spec FR-001, FR-006, FR-022; research R1, R3).

The rename changes names that users and automation depend on: repository
names, App Configuration labels, environment variables, and image names
(spec FR-002, FR-008).

Prioritized characteristics and measures:

1. One product identity: zero GPT-RAG names outside historical records in the
   shipped `v4.0.0` (SC-001, measured by the naming scan of R17).
2. Continuity: 100% of former repository and clone URLs keep resolving
   through GitHub redirects (SC-003, R1).
3. No acronym collision: no identifier uses `alz`, which denotes Azure
   Landing Zones (FR-002a).
4. Fixed delivery dates: preview by 2026-10-02, `v4.0.0` by 2026-10-09
   (SC-007, R15).

## Alternatives considered

### Option A: Rename in place and consolidate (selected)

- Rename `Azure/GPT-RAG` → `Azure/agent-landing-zone`, `gpt-rag-ui` →
  `agent-app-ui`, `gpt-rag-orchestrator` → `agent-app-orchestrator`,
  `gpt-rag-ingestion` → `agent-app-ingestion` with the GitHub rename feature
  (R1). History, issues, PRs, releases, and tags are preserved, and redirects
  work as long as no repository is created with an old name.

### Option B: New repositories and archive the originals

- Clean start, but loses redirects and history links (R1). Rejected.

### Option C: Keep old repository names with a new display name

- Lowest effort, but fails FR-001 and SC-008. Rejected.

### Option D: Use the `alz` prefix for internal identifiers

- Short, but collides with the established Azure Landing Zones acronym
  (spec clarification, FR-002a). Rejected.

## Decision

The product is named **Agent Landing Zone**, presented with the exact
transition statement "GPT-RAG is now Agent Landing Zone" (FR-001). The
application repositories use the `agent-app-*` names so other application
patterns can be added later (FR-006).

Scope of the consolidation:

- The four repositories are renamed in place (R1). Paulo re-verifies name
  availability immediately before the rename and approves the reversal
  procedure beforehand (FR-006).
- The infrastructure becomes repo-owned source (ADR-0015).
- `azd provision` / `azd deploy` / `azd up` form the infra and app boundary
  (ADR-0016).
- Applications are described by `app-definition.json` (ADR-0017).
- The release supports new deployments only (ADR-0018).
- User-facing docs move to the central Agent Landing Zone documentation site;
  the README becomes a short landing page (R3).

Naming rule for renamed identifiers (FR-002a, `contracts/naming-map.md`):

| Context | Form |
| --- | --- |
| No separators | `agentlz` |
| Hyphenated (App Configuration label, index, images, temp prefixes) | `agent-lz` / `agentlz-` |
| Environment variables | `AGENTLZ_` |
| Event names | `agentlz.` |
| Human-readable (role names, titles) | "Agent Landing Zone" |

The acronym `alz` MUST NOT be used in any identifier.

Runtime identifiers change in Phase 2 with a one-release dual-read of the old
and new App Configuration label and environment prefixes, and repository-root
detection switches from the folder name to `manifest.json` + `azure.yaml`
(R14). Versions take a major bump: umbrella `v4.0.0`, UI `v3.0.0`,
orchestrator `v5.0.0`, ingestion `v3.0.0` (FR-008, R15).

## Consequences

- Former GitHub Pages URLs (`azure.github.io/GPT-RAG/`) break because GitHub
  does not redirect Pages; `aka.ms` short links are repointed and the break is
  listed in the release notes (R2).
- Automation that reads `gpt-rag` labels or `GPT_RAG_*` variables must move to
  the new names; dual-read covers one release only (R14).
- Historical records (CHANGELOG entries, ADRs, specs, migration history) keep
  the old name (FR-002).

## Adoption and migration

1. Accept ADR-0014 to ADR-0018 and amend the constitution (FR-022, FR-023).
2. Phase 1 (`v4.0.0-preview.1`): public rebrand, repository renames, landing
   page, blocking short-link retargeting.
3. Phase 2 and 3 (`v4.0.0`): runtime identifier rename in the R14 order,
   infra incorporation, app layer, documentation migration, final scan.

Rollback follows the approved reversal procedure (FR-006) and runs the R14
order in reverse.

## Compliance verification

- `tests/test_naming_inventory.py` scans tracked files for GPT-RAG variants
  outside the allow-list (R17); Phase 1 temporary entries are removed for
  `v4.0.0`.
- Release checklist verifies redirects for the former repository and clone
  URLs (SC-003) and short links (SC-004).
- Review rejects any new `alz` identifier.

## Documentation impact

README landing page, central documentation site, release notes with the
transition statement and component version table (FR-009), and the naming
map in `specs/002-agent-landing-zone-rebrand/contracts/naming-map.md`.

## Review trigger

Reassess if a target repository name is unavailable, GitHub redirect behavior
changes, or a second Microsoft-maintained application pattern is proposed.
