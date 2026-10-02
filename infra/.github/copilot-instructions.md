# AI Landing Zone engineering core

Follow the repository-wide contract in `AGENTS.md`.

Use progressive disclosure:

- Load only `.github/instructions/*.instructions.md` files whose `applyTo`
  patterns match the files being changed.
- Load a procedure from `.github/skills/` when its description matches the task.
- Use a specialist from `.github/agents/` when its role and exit condition match
  the work.

Before Azure or Bicep design or implementation, load the
`engineering-principles` skill and obtain current Azure best-practice guidance
from the available Azure tooling.

These are GitHub Copilot engineering assets for maintaining this repository.
They are not deployed Microsoft Foundry agents or Azure resources.

Preserve existing deployment behavior by default. Do not change Bicep
parameters, outputs, resources, scripts, or runtime contracts merely to support
the engineering-agent framework.
