# Contributing

Thank you for your interest in contributing to AI Landing Zones. We are actively consolidating and improving our contribution guidance to make it easier for you to propose changes, report issues, and collaborate across the related repositories in this project.

This repository follows the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, please see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any questions or comments.

Before contributing, you may also be asked to sign a Contributor License Agreement (CLA). You can find more details at [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

If you are unsure whether your change fits the current roadmap or release train, start by reviewing the contributing guide above and then open a GitHub issue or discussion in this repository to validate your proposal.

## Engineering guidance

Repository-wide engineering rules are in [AGENTS.md](AGENTS.md). GitHub Copilot
specialists, reusable skills, and file-scoped instructions live under
`.github/`.

For changes to these declarative engineering assets, install the pinned
PowerShell YAML parser and run:

```pwsh
Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser
pwsh ./.github/scripts/Validate-CopilotAssets.ps1
pwsh ./tests/scripts/Validate-CopilotAssets.Tests.ps1
```

Bicep changes must also pass:

```pwsh
az bicep build --file main.bicep
az bicep lint --file main.bicep
```