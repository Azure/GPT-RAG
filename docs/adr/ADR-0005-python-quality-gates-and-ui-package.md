# ADR-0005: Adopt Incremental Python Quality Gates and a Compatible UI Package

**Status:** Accepted for implementation via pull requests<br>
**Date:** 2026-09-06<br>
**Owners:** GPT-RAG platform and orchestrator, ingestion, and UI maintainers

## Context

[Issue #681](https://github.com/Azure/GPT-RAG/issues/681) requires enforced Python
quality/type/dependency/error rules in three runtime repositories and a UI
migration into `src/gpt_rag_ui`. Their engineering contracts already separate
responsibilities, preserve explicit contracts and require observable failures,
but inspected CI does not provide the requested quality gates.

Priorities are identity/contract compatibility, trustworthy merge evidence,
independently deployable changes, then contributor navigation and incremental
typing improvements. Avoid an orchestrator reorganization, an ingestion src
migration, a shared CI platform or new shared JWT/client/audit implementations.

Read-only source inspection found static cycles involving UI citation rendering,
orchestrator OBO acquisition and ingestion scheduler state. Local imports can
defer initialization but do not remove those dependency edges. UI startup also
depends on auth setup before Chainlit import, conditional hosted/panel clients,
cached state and writable assets outside installed package code.

The decision and evidence span the platform and three components; hence this
coordination ADR lives here. Component adoption should reference it and record
local public surfaces, rather than duplicate or replace existing ADRs.
The [research ledger](../../specs/001-python-module-boundaries/research.md)
contains exact source revisions and tool limitations.

## Alternatives considered

### Option A: Incremental local gates and single-owner UI adapters

- Benefits: preserves existing runners and code organization; makes debt growth,
  forbidden dependencies and hidden failures reviewable; UI moves are reversible.
- Costs and risks: a small graph/baseline adapter and compatibility modules need
  maintenance; module moves require identity-aware debt matching.
- Security and identity: no identity redesign; delegated/owner checks remain at
  existing boundaries; PR checks are unprivileged and policies require protected
  maintainer review.
- Operational consequences: development dependencies increase; runtime topology
  and storage do not. Installed code uses the existing deployment asset bundle.
- Component compatibility: staged runtime changes work with shipped peers.
- Reversibility: restore the previous component artifact without data migration.

### Option B: Big-bang standardization and fully strict typing

- Benefits: a uniform src/layer layout and zero tolerated type debt immediately.
- Costs and risks: extends beyond the issue into ingestion/orchestrator rewrites,
  increases review surface and blocks unrelated changes on inherited debt.
- Security and identity: broad movement of identity/error paths increases the
  chance of changing token, ownership or failure semantics without clear need.
- Operational consequences: simultaneous changes and harder recovery.
- Component compatibility: requires larger coupled evidence before adoption.
- Reversibility: expensive; rollback spans many unrelated module changes.

### Option C: Ruff plus a different all-in-one boundary tool

- Benefits: tools such as Tach support flat module declarations; Pyright provides
  another mature typing option.
- Costs and risks: still requires evidence for actual graph granularity, internal
  exports, broad-handler exemptions and source-move baselines. It does not remove
  compatibility or approval work.
- Security and identity: equivalent preservation obligations; no tool supplies
  repository review authority or public-failure correctness.
- Operational consequences: a different configuration model without established
  use in these components.
- Component compatibility: no inherent runtime gain.
- Reversibility: tool replacement is possible, but record/report identities need
  deliberate conversion.

### Do not change

- Benefits: no immediate tooling or compatibility-adapter maintenance.
- Costs and risks: fails the issue's enforced-quality outcome and leaves UI
  ownership and known static cycles dependent on manual review.

## Decision

Adopt Option A. Use Ruff, one type checker (mypy), Import Linter/Grimp for
package contracts and a focused repository-local adapter for flat modules,
whole-graph cycles, approved broad handlers and baseline integrity.

Keep typing scope explicit and monotonic. Allow only individually identified,
reviewed inherited debt; a move preserves module identity and cannot multiply
allowances. Classify/fix initial lint and architecture violations before
activation. Broad handler approval must include public-failure evidence even
when Ruff exempts a logged or re-raised exception.

Move UI code in dependency order into config/util, auth/clients, services and
API/composition. Keep `main.py`, `app.py` and inventoried public imports as thin
adapters. Split composition from reusable logic; preserve one owner for mutable
state. A setuptools src package installs code while existing deployment assets
remain in the application root. Keep the current Docker/Uvicorn command.

Preserve the authenticated BFF/managed-Conversations ownership and stateless
hosted-container invariant from
[ADR-0004](ADR-0004-hosted-panel-conversations-contract.md).
No new Azure resource, App Configuration key, RBAC grant, wire schema or
customer-data store is introduced.

The maintainer approved this design and authorized changes in all related
repositories through pull requests on 2026-09-06. This authorizes implementation
and PR preparation, not automatic merge, release, deployment or direct changes
to repository settings. Concrete public-surface and exception policies remain
reviewable in their component PRs. Administrators must separately activate
required checks and protected policy review; acceptance of this ADR does not
claim those controls are already active.

## Consequences

### Positive

- New violations and missing check execution cannot be silently treated as clean.
- Runtime identity and contracts remain testable across each deployable slice.
- UI contributors have a single ownership map without root business logic.
- Existing typed contracts and both backend layouts are reused.

### Negative or accepted

- Tooling adds CI duration/storage and development dependencies, not Azure
  infrastructure cost; measure duration and set timeouts in implementation.
- Explicit adapters and policy records impose maintenance until a separately
  approved compatibility retirement.
- Static analysis cannot infer arbitrary runtime import/type behavior; inventory
  dynamic loading and test it instead of claiming universal coverage.
- Initial cycle fixes and broad-handler classification are required work, not
  hidden exclusions. Escalate behavior-changing remedies before implementation.

## Adoption and migration

Start component feature branches from `develop`. First establish policy/tool
fixtures and behavior baselines. Remove confirmed cycles locally, classify
handlers, and activate required checks only after the reference PR and repository
rules prove blocking behavior. CI-only component changes can proceed independently.

Then migrate the UI package in independently deployable slices, each compatible
with shipped peers and preceding merged slices. Record exact candidate and
previous-compatible SHAs, public imports, scenario results and documentation
impact. The [plan](../../specs/001-python-module-boundaries/plan.md) provides
initial source refs and ordered stages.

No application data or configuration migration is required. Recover by
redeploying the prior compatible component artifact; after any future pin
change, restore the previous full manifest combination. Roll forward a checker
defect through reviewed policy repair rather than disabling required checks.
Release tags, manifest integration and publishing remain separately approved
release work after exact-ref integration evidence.

## Compliance verification

Use the existing pytest/unittest suites, targeted failure/authorization tests,
quality-policy mutation fixtures, full graph/public-surface checks, and UI
non-editable installation/container startup tests. Every inventoried compatibility
scenario must retain its before/after outcome, including disabled/not-ready states.

Verify administrative required-status and code-owner/latest-head review controls;
workflow YAML and approval strings alone are insufficient. A skipped check,
checker error, stale report or policy self-approval must not permit merge.
Do not add privileged PR execution to implement these controls.

The [quality contract](../../specs/001-python-module-boundaries/contracts/quality-gates.md)
and [UI contract](../../specs/001-python-module-boundaries/contracts/ui-compatibility.md)
define the fitness functions. This ADR records no runtime test/deployment pass.

## Documentation impact

Update component contributor instructions and `AGENTS.md` ownership maps with
their implementation. On the platform `docs` branch, update `docs/contributing.md`
and review deployment/auth/hosted-continuity examples for drift in the same
coordinated delivery. Keep product READMEs short and linked to the published site.
Planning alone does not change shipped product documentation.

## Review trigger

Revisit before accepting a change that requires a contract/identity redesign,
an additional repository or shared CI service, broader component restructuring,
removal of supported imports, bundled writable site-packages assets, or a
replacement checker/baseline format. Also revisit if tool fixtures cannot prove
the required graph/approval behavior or CI duration prevents practical mandatory
use. Such findings require a reviewed amendment, not a silent scope expansion.
