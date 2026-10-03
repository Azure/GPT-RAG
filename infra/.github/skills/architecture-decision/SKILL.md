---
name: architecture-decision
description: Conducts and records a verifiable AI Landing Zone architecture decision. Use when a choice alters module boundaries, contracts, identity, networking, deployment topology, or operation with meaningful reversal cost.
---

# AI Landing Zone architecture decision

1. Load the relevant `engineering-principles` references and current Azure
   best-practice guidance.
2. Define operator outcome, constraints, affected modules and contracts, and up
   to five prioritized characteristics with measures.
3. Compare at least two viable alternatives and the option of not changing.
4. Evaluate identity, RBAC, network isolation, parameter compatibility, Azure
   limits, cost, operation, migration, consumer impact, and reversibility.
5. Record the decision under `docs/adr/` using
   [the ADR template](references/adr-template.md).
6. Define fitness functions, adoption order, rollback or roll-forward, and a
   review trigger.

Do not turn a tool, service, or framework preference into an architecture
requirement. Record a bounded investigation when evidence is missing.
