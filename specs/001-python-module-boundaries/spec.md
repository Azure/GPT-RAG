# Feature Specification: Enforce Module Boundaries and Modularize the UI

**Feature Branch**: `feature/python-module-boundaries`

**Created**: 2026-09-06

**Status**: Draft

**Input**: [Issue #681](https://github.com/Azure/GPT-RAG/issues/681) - "[Improvement] Enforce Python module boundaries in CI and modularize gpt-rag-ui"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catch Quality Regressions Before Merge (Priority: P1)

As a contributor or reviewer, I want each affected component's pull requests to
report and block new code-quality and type-consistency problems, so existing
technical debt does not grow or require every reviewer to rediscover it.

**Why this priority**: Automatic feedback prevents new defects while allowing
useful work to continue without requiring an immediate rewrite of legacy code.

**Independent Test**: In each of the three component repositories, submit a clean
change and separate changes containing a new quality violation and a new type
violation in the declared blocking scope. Only the clean change is eligible to
merge, and each failed result identifies the finding and its location.

**Acceptance Scenarios**:

1. **Given** a pull request without new violations, **When** required checks run,
   **Then** quality and typing results are visible alongside existing test results.
2. **Given** a new quality violation or a type violation within blocking coverage,
   **When** checks complete, **Then** merge eligibility is blocked and the
   contributor can identify the rule, location, and reason.
3. **Given** recorded legacy type violations, **When** an unrelated compliant
   change is checked, **Then** unchanged debt does not block it, while an
   additional violation in blocking coverage does.
4. **Given** a proposed reduction in typing coverage or expansion of tolerated
   debt, **When** that change is reviewed, **Then** it cannot silently weaken the
   gate and requires explicit maintainer approval with a recorded rationale.
5. **Given** an agreed expansion of typing coverage, **When** it is adopted,
   **Then** newly covered modules receive the same regression protection and
   previously covered modules remain protected.

---

### User Story 2 - Enforce Existing Dependency and Error Rules (Priority: P1)

As a maintainer, I want documented package boundaries and error-handling rules
enforced on every pull request, so code cannot acquire forbidden dependencies or
hide a failed operation behind an apparently successful result.

**Why this priority**: These rules protect maintainability and trustworthy
operation, independently of the UI reorganization.

**Independent Test**: In each affected repository, introduce a dependency cycle,
a prohibited dependency, access to a private package member, and an unjustified
blind exception handler. Each must be rejected. For public failure boundaries,
simulate a dependency failure and verify the documented failure outcome.

**Acceptance Scenarios**:

1. **Given** the existing documented dependency rules, **When** a change adds a
   direct or indirect cycle, a forbidden dependency direction, or access to
   another package's internal modules, **Then** checks reject it and identify the
   dependency path and violated rule.
2. **Given** a dependency through an allowed public package boundary, **When**
   checks run, **Then** the dependency is accepted.
3. **Given** a blind or overly broad exception handler without an approved
   justification, **When** checks run, **Then** the handler is rejected.
4. **Given** an exceptional handler required at a public boundary, **When** its
   narrowly scoped justification and failure-behavior evidence are approved,
   **Then** only that documented exception is allowed; unrelated handlers remain
   subject to enforcement.
5. **Given** a public operation whose contract requires failure to be surfaced,
   **When** a dependency fails, **Then** callers receive the documented failure
   rather than a success-shaped fallback and operators receive diagnostics
   without secrets or unauthorized content.

---

### User Story 3 - Navigate a Modular UI Without Breaking Existing Use (Priority: P2)

As a UI contributor, I want runtime responsibilities grouped in one coherent
package, so I can locate and change a responsibility without navigating a flat
collection of root-level modules. As an operator or existing caller, I want the
reorganization to preserve the ways I start, configure, deploy, and use the UI.

**Why this priority**: The reorganization improves long-term maintenance but
must not disrupt users or operators while quality gates are introduced.

**Independent Test**: Compare the migrated UI with the pre-migration compatibility
inventory. Exercise every supported startup route and public import, run the
existing UI behavior checks, and verify the runtime responsibility inventory is
fully assigned to the package.

**Acceptance Scenarios**:

1. **Given** the inventory of UI runtime responsibilities, **When** migration
   finishes, **Then** every responsibility is owned by the structured package;
   root-level compatibility and startup entry points contain no business logic.
2. **Given** an existing supported startup command, public import, configuration,
   or deployment mode, **When** used after each migration step, **Then** it
   continues to work without a caller or operator change.
3. **Given** representative existing user flows, including authentication,
   conversation access, and failure reporting, **When** exercised after
   migration, **Then** observable results and authorization restrictions remain
   unchanged.
4. **Given** an installed or deployed UI outside a source checkout, **When** it
   starts through a supported entry point, **Then** it can locate its runtime
   package and required resources without relying on a developer's directory.

---

### User Story 4 - Adopt and Recover Incrementally (Priority: P2)

As a maintainer or operator, I want a sequence of independently deployable
changes with compatibility evidence and recovery instructions, so adoption can
stop or reverse after any step without requiring all repositories to change
simultaneously.

**Why this priority**: Incremental delivery limits operational risk and makes
cross-repository progress reviewable.

**Independent Test**: For each proposed delivery step, identify the compatible
component combination, exercise its deployment and regression evidence, and
demonstrate recovery to the preceding compatible combination.

**Acceptance Scenarios**:

1. **Given** an individual delivery step, **When** it is ready for review,
   **Then** its owning repositories, compatibility impact, required checks,
   integration order, and recovery procedure are recorded.
2. **Given** a failed migration step, **When** the documented recovery procedure
   is followed, **Then** the preceding supported combination remains usable
   without a data migration.
3. **Given** a change to documented contributor or operator procedures, **When**
   that step is delivered, **Then** affected documentation is updated with it
   or evidence records that no existing page is affected.

### Edge Cases

- Existing type debt must not be mistaken for newly introduced debt when a file
  moves; moves must not erase coverage or blanket-exempt new code.
- Dependency cycles involving three or more modules must be detected, not only
  pairs; legitimate public re-exports and startup adapters must remain usable.
- A changed rule configuration, suppression, or exception record must not
  silently disable enforcement or broaden an approved exception.
- Missing or failed check execution must not appear as a successful required
  check or make a pull request merge-eligible.
- Broad handlers needed for cleanup or boundary translation must retain explicit
  failure semantics; diagnostic messages must not disclose sensitive inputs.
- Moved UI resources, supported public imports, and startup entry points must
  work in installed and deployed use, not only from the repository root.
- Intermediate component combinations must remain supported even when another
  repository has not yet adopted its corresponding delivery step.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All three repositories, `gpt-rag-orchestrator`,
  `gpt-rag-ingestion`, and `gpt-rag-ui`, MUST require code-quality and static
  type-consistency checks before pull requests can merge (Story 1).
- **FR-002**: Check results MUST distinguish quality, typing, dependency, and
  behavioral-test failures and identify actionable finding locations and rules.
  Missing, skipped, or failed required execution MUST NOT count as success
  (Story 1 and Edge Cases).
- **FR-003**: Typing enforcement MUST start with an explicitly recorded set of
  currently typed modules and a reviewed legacy-debt baseline. It MUST reject
  additional violations in that scope without blocking solely on unchanged
  baseline debt (Story 1).
- **FR-004**: Blocking typing coverage MUST support incremental expansion.
  Coverage reductions, new suppressions, and baseline growth MUST require
  recorded maintainer approval and rationale; moving a module MUST retain its
  existing protection (Story 1 and Edge Cases).
- **FR-005**: Required dependency checks in all three repositories MUST reject
  direct and indirect import cycles (Story 2).
- **FR-006**: Required dependency checks MUST enforce each repository's documented
  allowed package relationships and reject access to another package's internal
  modules, while permitting its documented public surface (Story 2).
- **FR-007**: Required checks MUST reject blind or overly broad exception
  handling unless a scoped exception identifies the boundary, necessity,
  maintainer approval, and supporting failure-behavior evidence (Story 2).
- **FR-008**: Public boundaries whose contracts require failure propagation MUST
  have targeted regression coverage demonstrating that failures cannot become
  success-shaped fallbacks. Failure diagnostics MUST use established reporting
  paths and preserve confidentiality (Story 2).
- **FR-009**: UI runtime responsibilities MUST move into a structured application
  package with clear ownership of request handling, identity, service access,
  business operations, telemetry, and utility responsibilities (Story 3).
- **FR-010**: Existing UI startup and compatibility entry points MUST remain
  available as thin adapters; business logic MUST have a single owner inside
  the application package (Story 3).
- **FR-011**: The UI migration MUST preserve supported public interfaces and
  imports, configuration names and behavior, startup routes, packaged resources,
  and deployment behavior throughout the incremental transition (Story 3).
- **FR-012**: Authentication, document-level authorization, role-based access,
  delegated identity behavior, and existing audit and telemetry contracts MUST
  retain their pre-change semantics (Stories 2 and 3).
- **FR-013**: Delivery MUST use incremental, independently deployable pull
  requests, each identifying the compatible component combination, integration
  order, rollback order, and observable acceptance evidence (Story 4).
- **FR-014**: Existing orchestrator organization, typed contracts, shared audit
  contracts, architectural decisions, and documented repository boundaries MUST
  be reused rather than replaced (Stories 2 and 4).
- **FR-015**: Affected contributor guidance MUST explain the required checks,
  blocking typing scope, approved exceptions, and UI responsibility map.
  User/operator documentation MUST remain aligned with shipped behavior in the
  same delivery step (Stories 3 and 4).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In all three component repositories, a clean reference change is
  merge-eligible and each deliberately introduced quality or in-scope type
  regression is blocked with an identifiable rule and location.
- **SC-002**: In all three repositories, all agreed negative dependency cases
  (direct cycle, indirect cycle, forbidden direction, private-module access)
  are rejected and all agreed allowed public-dependency cases pass.
- **SC-003**: All introduced unjustified blind or overly broad handlers are
  rejected; every accepted exception has a scoped rationale, approval, and
  failure-behavior evidence. Every inventoried public failure boundary preserves
  its documented failure outcome in the targeted regression cases.
- **SC-004**: After UI migration, 100% of inventoried runtime responsibilities
  have a package owner, and no business logic remains in root-level startup or
  compatibility adapters.
- **SC-005**: Every item in the reviewed compatibility inventory passes before
  and after each delivery step, with zero required changes to supported caller
  behavior, configuration, or operator startup and deployment procedures.
- **SC-006**: Every delivery step has an independently usable component
  combination, a demonstrated recovery path, and an explicit documentation
  impact assessment; no step depends on an unmerged companion change.
- **SC-007**: During maintainer review, each of the six UI responsibility areas
  can be mapped to one documented owning location, with no unresolved ownership
  ambiguity or duplicated business logic reported.

## Assumptions

- This specification covers the mandatory scope of issue #681 only. It specifies
  outcomes; it does not implement changes or claim current component compliance.
- The issue's explicit delivery constraints are retained for planning: Ruff for
  quality checks, UI runtime packaging under `src/gpt_rag_ui/`, and preservation
  of `main.py` and `app.py` as thin entry points. The illustrated subpackage names
  are examples rather than a newly mandated dependency design.
- The static type checker, exact rule configuration, initial typed-module list,
  and dependency enforcement mechanism will be selected during planning using
  existing component evidence, not invented by this specification.
- An incremental baseline protects its declared scope; it does not imply that
  all legacy untyped code becomes strictly typed in the first delivery step.
  Planning must document uncovered areas and the expansion sequence.
- "Supported imports" means documented public imports and those used by existing
  supported entry points or integrations. Planning must inventory these before
  changing them; ambiguous external dependencies require a maintainer decision
  rather than silently declaring them private.
- Existing documented boundaries and architectural decisions are authoritative.
  Planning must inventory the component `AGENTS.md` rules and public surfaces;
  any ambiguous or conflicting rule must be resolved before enforcing it.
- Required dependencies are access to the three component repositories, their
  existing checks and tests, maintainer authority for required merge checks, and
  access to supported deployment validation environments.
- Runtime code and its quality gates belong to their respective component
  repositories. `Azure/GPT-RAG` owns this coordinated specification and any
  later manifest integration. Compatible commits or tags must be established
  during delivery; this specification changes no pins.
- No new customer-data collection, storage, or migration is required. Existing
  CI evidence is sufficient for this feature's reporting needs.
- No new identity or trust boundary is intended. A newly discovered need to
  change contracts, identity, or other costly-to-reverse boundaries requires a
  recorded architectural decision before implementation.
- Stretch goals are excluded: generated UI models from the conversations-panel
  contract, ingestion layout migration, and shared cross-repository CI
  configuration. They require a separate scope decision.
- Also excluded are replacing audit/telemetry contracts, another orchestrator
  reorganization, a shared JWT implementation, a shared Azure client repository,
  and changes to the multi-repository topology.
- Product documentation remains on the `docs` branch and published site;
  contributor guidance remains with the owning repository. This specification
  alone changes no shipped behavior and requires no product documentation edit.
