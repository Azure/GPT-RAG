---
name: iac-validation
description: Builds an evidence-based validation plan for AI Landing Zone Copilot assets, Bicep, parameters, scripts, and Azure deployment behavior. Use after implementation or during regression investigation.
---

# AI Landing Zone validation

1. Map each acceptance criterion to an observable result.
2. Identify changed declarative assets, Bicep contracts, scripts, and deployment
   paths.
3. Run Copilot asset validation and its fixture tests when `.github` engineering
   assets change.
4. Run targeted PowerShell tests for deterministic script logic.
5. Build and lint Bicep; run the size gate when compiled output can change.
6. Run preflight with the appropriate deterministic or Azure-aware scope.
7. Use What-If and approved test deployment evidence according to risk.
8. Report exact commands, results, warnings, skipped paths, and residual risk.

Do not treat successful YAML parsing, Bicep compilation, or What-If as proof of
runtime success. Do not mutate Azure merely to gather evidence without approval.
