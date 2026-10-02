---
applyTo: "AGENTS.md,.github/copilot-instructions.md,.github/agents/**,.github/skills/**,.github/instructions/**,.github/scripts/Validate-CopilotAssets.ps1"
---

# GitHub Copilot engineering assets

- Keep `AGENTS.md` concise and stable; move procedures to skills and file-scoped
  rules to instructions.
- Distinguish engineering agents from deployed Azure and Microsoft Foundry
  agents.
- Use lowercase kebab-case agent and skill names.
- Keep agent roles non-overlapping and include explicit handoffs.
- Keep skills reusable and load detailed references only when relevant.
- Ensure `applyTo` patterns are specific enough to avoid unrelated context.
- Validate YAML frontmatter, schemas, unique names, allowed tools, and local
  links with `.github/scripts/Validate-CopilotAssets.ps1`.
