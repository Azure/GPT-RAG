---
name: documentation-consistency
description: Keeps GPT-RAG user and operator documentation aligned with shipped behavior. Use for features, configuration keys, deployment parameters, defaults, component pins, operations, or breaking changes.
---

# GPT-RAG documentation consistency

User-facing documentation lives on the `docs` branch of `Azure/GPT-RAG` and is
published at https://azure.github.io/GPT-RAG/.

1. Identify the user or operator behavior that changed.
2. Search the documentation source for the feature, configuration key,
   parameter, component, and previous terminology.
3. Update every affected page in the same coordinated change.
4. Register new pages in `mkdocs.yml`.
5. Keep repository and service READMEs concise; link to the published site
   instead of duplicating product guidance.
6. Ensure examples match current defaults, supported deployment modes, and
   shipped component versions.
7. Report the documentation branch or pull request in the implementation
   handoff.

A user-visible change is incomplete until documentation is updated or the
search demonstrates that no published page is affected.
