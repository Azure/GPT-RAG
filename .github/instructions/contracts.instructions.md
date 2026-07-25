---
applyTo: "contracts/**"
---

# Shared contracts

- Treat schemas as cross-repository, versioned compatibility boundaries.
- Preserve existing consumers by default; use additive optional fields when
  appropriate.
- Update schema versions when interpretation changes.
- Keep logical and wire schemas aligned and regenerate integrity hashes from
  the exact committed bytes.
- Consumers must ignore unknown optional fields unless the contract explicitly
  says otherwise.
- Coordinate orchestrator, ingestion, and platform pins when a contract
  changes.
- Add or update contract tests and fixtures in every affected consumer.
- Do not claim legal or regulatory compliance from technical audit evidence.
