# Contract: naming map

**Feature**: 002-agent-landing-zone-rebrand | **Requirements**: FR-001–FR-008,
SC-001, SC-008 | **Research**: R1, R2, R14, R17

This is the single source of truth for every rename. Any other document that
lists old and new names links here instead of copying the table.

## Product and repositories

| Old | New | Version at rename |
|---|---|---|
| GPT-RAG (`Azure/GPT-RAG`) | Agent Landing Zone (`Azure/agent-landing-zone`) | v4.0.0 |
| `Azure/gpt-rag-ui` | `Azure/agent-app-ui` | v3.0.0 |
| `Azure/gpt-rag-orchestrator` | `Azure/agent-app-orchestrator` | v5.0.0 |
| `Azure/gpt-rag-ingestion` | `Azure/agent-app-ingestion` | v3.0.0 |

Repositories are renamed in place so GitHub redirects old URLs (R1). `aka.ms`
short links are retargeted rather than replaced (R2).

## Runtime identifiers

| Old | New |
|---|---|
| App Configuration label `gpt-rag` | `agent-lz` |
| `GPT_RAG_REPO_ROOT` | `AGENTLZ_REPO_ROOT` |
| Other `GPT_RAG_*` environment values | `AGENTLZ_*` |
| Temporary file and folder prefixes `gpt-rag-` / `gptrag` | `agentlz-` |
| `azure.yaml` project name `azure-gpt-rag` | `agent-landing-zone` |
| Telemetry event prefix | `agentlz.` |
| Repo-root detection by folder name | Detection by the presence of `manifest.json` plus `azure.yaml` |

**Rule:** never use the abbreviation `alz`; it collides with the Azure Landing
Zones brand. Use `agent-lz` (labels) or `agentlz` / `AGENTLZ_` (identifiers).

## Change order (R14)

1. Each component release dual-reads both labels (`agent-lz`, then `gpt-rag`)
   and both environment prefixes (`AGENTLZ_`, then `GPT_RAG_`) for one release.
2. The umbrella switches to writing only `agent-lz` / `AGENTLZ_`.
3. `manifest.json` moves its pins to the renamed component releases.

**Rollback** runs in reverse: restore the previous manifest pins, then the
previous umbrella writer, then the previous component releases. Because
components dual-read, steps 2 and 3 can roll back independently.

## Naming scan (R17)

`tests/test_naming_inventory.py` searches for the tokens `gpt-rag`, `GPT-RAG`,
`gptrag`, and `GPT_RAG` (case-insensitive). It has no modes or switches: it
fails on any match outside the allow-list below.

**Allow-list** (matches are permitted only here):

- `CHANGELOG.md` entries for releases before v4.0.0.
- Architecture decision records under `docs/adr/`.
- The transition statement ("Agent Landing Zone, formerly GPT-RAG").
- This naming map.
- Dual-read compatibility code from step 1 above, until it is removed.

**Temporary entries** (permitted in `v4.0.0-preview.1`; the Phase 2 work
removes them, so the same test enforces the full rename for `v4.0.0`):

- App Configuration label `gpt-rag`.
- `GPT_RAG_*` environment values, including `GPT_RAG_REPO_ROOT`.
- Temporary file and folder prefixes `gpt-rag-` / `gptrag`.
- `azure.yaml` project name `azure-gpt-rag`.
- Telemetry event prefix.
- Folder-name repo-root detection.

| Release | Allow-list in effect | Gate |
|---|---|---|
| `v4.0.0-preview.1` | Permanent + temporary entries | SC-008 |
| `v4.0.0` | Permanent entries only | SC-001 |
