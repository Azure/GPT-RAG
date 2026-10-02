# Security and networking

- Prefer managed identity and least-privilege RBAC. Keep control-plane and
  Cosmos DB data-plane assignments in their established security modules.
- Never place credentials, access tokens, private keys, or environment-specific
  secrets in Bicep, parameters, logs, tests, or examples.
- Preserve private endpoint dependencies, DNS zone groups and links, policy-
  managed DNS behavior, subnet delegation and sizing, route tables, and hub/
  spoke peering responsibilities.
- Keep `Microsoft.App/environments` delegation casing canonical.
- Treat public network access and `allowedIpRanges` interactions as explicit
  security decisions; not every Azure service supports native IP rules.
- Validate standard and network-isolated paths when identity or networking
  changes.
- Security claims require Bicep evidence, deployment evidence, or current Azure
  documentation. Compilation alone does not prove effective isolation.
