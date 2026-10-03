---
name: documentation-consistency
description: Keeps AI Landing Zone contributor, user, and operator documentation aligned with shipped Bicep behavior. Use for parameters, defaults, outputs, topology, deployment flow, operations, or releases.
---

# AI Landing Zone documentation consistency

1. Identify the user, consumer, contributor, or operator behavior that changed.
2. Search `README.md`, `CHANGELOG.md`, `docs/`, `pipelines/README.md`, examples,
   and tests for the parameter, output, flag, topology, command, and old term.
3. Update every affected in-repository source in the same change.
4. When the public Bicep landing-zone narrative changes, update the MkDocs source
   on `Azure/AI-Landing-Zones` `main` and link the companion pull request.
5. Keep examples aligned with current defaults and both standard and network-
   isolated modes.
6. Classify semantic-version impact and record migration guidance for breaking
   behavior.
7. Report documentation status and any coordinated pull request in the handoff.

Generated `gh-pages` content is not an editable documentation source. A user-
visible change is incomplete until documentation is updated or a search proves
that no published page is affected.
