---
applyTo: "config/**/*.py,util/**/*.py"
---

# Python configuration modules

- Keep modules focused on one Azure configuration responsibility.
- Add new behavior under the appropriate `config/<area>/` package rather than
  expanding an unrelated setup module.
- Reuse existing credential, App Configuration, Key Vault, logging, rendering,
  and request helpers.
- Use type hints and explicit boundary contracts.
- Keep Search and Foundry IQ resources template-driven. Extend templates and
  inputs instead of hardcoding full resource payloads in Python.
- Fail with actionable errors. Do not swallow exceptions, silently skip
  requested configuration, or use `print` for diagnostics.
- Use mocked Azure boundaries in tests. Never require live credentials for a
  unit test.
- Load `engineering-principles` for changes to Azure boundaries, identity,
  security, or shared configuration contracts.
