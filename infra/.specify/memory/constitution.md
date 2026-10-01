<!--
Sync Impact Report
- Version change: template scaffold -> 1.0.0
- Modified principles: none; initial constitution ratification
- Added principles:
  - I. Orchestrator and Module Boundaries
  - II. Compatibility and Parameterization
  - III. Deployment-Mode Integrity
  - IV. Managed Identity and Secure Networking
  - V. Evidence-Based, Authorized Change
- Added sections:
  - Automation and Release Constraints
  - Change Quality Gates
- Removed sections: none
- Follow-up TODOs: none
-->
# AI Landing Zone Constitution

## Core Principles

### I. Orchestrator and Module Boundaries
`main.bicep` MUST remain the resource-group-scoped orchestrator. Reusable
resource bodies MUST reside in focused AVM or local modules, and shared role
IDs, abbreviations, and types MUST come from `constants/`. Deployment shape
MUST be driven by typed data structures and feature flags rather than
workload-specific branches. Changes to module boundaries MUST include an
explicit compatibility and migration assessment.

### II. Compatibility and Parameterization
Parameter names, defaults, allowed values, nullable behavior, output names,
module interfaces, manifest fields, App Configuration keys, naming modes, and
explicit-name overrides are compatibility contracts. Changes MUST be additive
unless a breaking change is explicitly approved, documented with migration
guidance, and assigned the required semantic version. Values subject to azd
empty-string substitution MUST have a safe fallback before resource use.
Capabilities MUST remain consistently wired across the parameter surface,
modules, runtime configuration, and outputs wherever those surfaces apply.

### III. Deployment-Mode Integrity
Standard and Zero Trust or network-isolated deployments MUST retain their
distinct feature gating, topology, and security behavior. Optional resources
MUST remain conditional and preserve established disabled-state output
fallbacks. A change affecting shared identity, networking, ingress, DNS, or
service access MUST validate every affected deployment mode; success in one
mode MUST NOT be treated as evidence for another.

### IV. Managed Identity and Secure Networking
Azure access MUST use managed identity and least-privilege RBAC unless an
explicitly approved platform constraint requires otherwise. Role assignments
MUST remain explicit and centralized in the established security modules.
Credentials, tokens, private keys, tenant or subscription identifiers, and
environment-specific secrets MUST NOT be committed or logged. Private
endpoints, DNS links and zone groups, subnet delegation and sizing, route
tables, hub-and-spoke peering, dependency ordering, and public network access
MUST be treated as security-sensitive contracts and MUST NOT change without
mode-specific evidence and review.

### V. Evidence-Based, Authorized Change
Every change MUST be supported by the narrowest applicable repository
validation and broader evidence proportional to its risk. Reports MUST state
what ran, the result, meaningful warnings, skipped checks, and residual risk.
Compilation, lint, preflight, and What-If prove only their respective checks;
they MUST NOT be represented as proof of successful deployment. Provisioning,
production mutation, tagging, publishing, or release creation MUST require
explicit human authorization.

## Automation and Release Constraints

PowerShell 7 MUST remain the shared automation runtime across Windows and POSIX
azd hooks. Scripts MUST quote external input, avoid secret disclosure, fail
explicitly when prerequisites are unmet, and preserve idempotency. Changes to
`install.ps1` MUST preserve its fixed execution budget, bounded external
operations, and fatal-versus-optional step classification. Shared deployment
behavior MUST remain semantically aligned across PowerShell and Azure DevOps
automation.

The repository MUST use semantic versioning. Release versions in the manifest,
changelog, tag, GitHub Release title, and release commit MUST agree. Major or
minor product changes MUST include Portal and Terraform landing-zone parity
review. Releases MUST include an approved rollback or roll-forward path.

## Change Quality Gates

Changes MUST preserve existing deployment behavior unless the approved
requirement explicitly changes it. Validation MUST cover affected conditional,
compatibility, and deployment-mode paths. Security or isolation claims MUST be
supported by executable infrastructure evidence, approved deployment evidence,
or current authoritative Azure documentation.

Documentation describing parameters, defaults, outputs, topology, deployment
modes, operator steps, or release behavior MUST be updated in the same change
as the implementation. `README.md`, `CHANGELOG.md`, applicable runbooks,
pipeline guidance, and public AI Landing Zones documentation MUST remain
consistent with shipped behavior wherever each is affected.

## Governance

This constitution defines the repository's non-negotiable engineering rules.
More detailed procedures MAY exist in `AGENTS.md`, scoped instructions, and
skills, but they MUST NOT weaken or contradict this constitution. Pull requests
and reviews MUST verify applicable constitutional compliance, and deviations
MUST be documented with rationale, risk, approval, and a restoration or
migration plan.

Amendments MUST modify this file through review, describe their impact in the
Sync Impact Report, and update the version using semantic versioning:

- MAJOR for removal or incompatible redefinition of a principle or governance
  obligation.
- MINOR for a new principle or materially expanded mandatory guidance.
- PATCH for non-semantic clarification or correction.

The ratification date remains the original adoption date. The last-amended date
MUST change whenever normative content changes. Compliance review MUST occur
during specification, implementation review, validation, and release approval
at the level applicable to the change.

**Version**: 1.0.0 | **Ratified**: 2026-08-20 | **Last Amended**: 2026-08-20
