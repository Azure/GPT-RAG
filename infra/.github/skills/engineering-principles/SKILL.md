---
name: engineering-principles
description: AI Landing Zone architecture and implementation principles. Use before Azure or Bicep design, review, meaningful refactoring, security, validation, release, or operational work.
---

# AI Landing Zone engineering principles

Before generating Azure or Bicep guidance, obtain current Azure best-practice
guidance from the available Azure tooling. Then load only the references needed:

| When the task involves | Read |
| --- | --- |
| Repository purpose, module boundaries, or topology | [Architecture and boundaries](references/architecture-and-boundaries.md) |
| Bicep style, parameters, outputs, or compatibility | [Bicep style and contracts](references/bicep-style-and-contracts.md) |
| Identity, RBAC, secrets, networking, or private access | [Security and networking](references/security-and-networking.md) |
| Tests, lint, build, What-If, deployment, or evidence | [Validation and evidence](references/validation-and-evidence.md) |
| Operations, documentation, versioning, or release | [Operations and releases](references/operations-and-releases.md) |

Use these principles as design questions, not dogma. Task requirements,
executable configuration, current Azure contracts, and the implementation
remain the sources of truth.
