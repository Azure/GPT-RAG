# Validation and evidence

Use the smallest applicable evidence ladder:

1. Validate Copilot declarative assets and validator tests.
2. Run targeted PowerShell tests for changed deterministic logic.
3. Build and lint `main.bicep`.
4. Run the compiled-template size gate when Bicep or modules change.
5. Run preflight with deterministic checks, then Azure lookups when available.
6. Use `azd provision --preview` or the Azure DevOps preview template.
7. Provision only in an approved test scope when end-to-end evidence is needed.

For each result, record the command, exit code, meaningful warnings, and what it
proves. Test conditional and compatibility paths affected by the change. Do not
claim that build, lint, or What-If proves a successful deployment. If a check
cannot run, state the missing dependency or authorization and residual risk.
