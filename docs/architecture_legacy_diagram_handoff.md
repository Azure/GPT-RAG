# Legacy architecture diagram update handoff

Use this checklist to manually update `media/GPT-RAG.vsdx`, then export the
updated full reference view to `media/architecture_zero_trust.png`. The SVG
diagrams remain the editable source for the focused Basic, modular-layer, and
chat-runtime views.

!!! warning "Release status"
    Draw the hosted/no-panel path as the **supported fresh-deployment default**
    and label it **shipped in v3.8.2; continuity off/503 pending evidence**.
    Label hosted-panel as **supported only when explicitly selected; history and
    operator APIs off/503 pending evidence**. UI `v2.6.2`, orchestrator
    `v4.1.1`, ingestion `v2.7.2`, and AILZ `v2.5.1` are pinned by
    [GPT-RAG `v3.8.2`](https://github.com/Azure/GPT-RAG/releases/tag/v3.8.2).

## Shapes and labels

Add or update these shapes in the application/runtime area:

| Shape | Exact label | Placement |
| --- | --- | --- |
| Existing application host boundary | `Azure Container Apps` | Keep around the Web UI and ingestion services. |
| Existing UI shape | `Trusted Web UI / BFF` | Keep in Container Apps at the request-path entry and make it the only source of the delegated owner header. |
| Existing ingestion shape | `Ingestion` | Keep in Container Apps and connected to Storage / AI Search indexing. |
| New primary runtime shape | `Microsoft Foundry Hosted Agent` | Place to the right of Web UI, outside the Container Apps boundary and inside the Microsoft Foundry boundary. |
| New owner-binding annotation | `x-ms-user-identity; Responses 2.0.0` | Place on the UI BFF to hosted-agent connection and distinguish it from OBO retrieval. |
| New role annotation | `Direct agent scope: Foundry Agent Consumer eed3b665-ab3a-47b6-8f48-c9382fb1dad6 + GPT-RAG Hosted Agent User Identity Impersonation bef66abe-a495-530a-be1d-5d882fecff03` | Attach to the UI BFF identity and individual hosted agent only; the custom role contains only `Microsoft.CognitiveServices/accounts/AIServices/agents/endpoints/UserIdentityImpersonation/action`. |
| New state shape | `Foundry managed Conversations` | Place in the Foundry boundary. Mark the hosted runtime as having no Conversation or impersonation RBAC. |
| New tool boundary | `Toolbox / MCP tools` | Place to the right of the hosted agent. |
| New retrieval shape | `Authorization-trimmed retrieval` | Place below Toolbox and connect to Foundry IQ / Azure AI Search. |
| Fallback runtime shape | `Container Apps orchestrator - explicit fallback` | Place below the primary request path with a dashed border. Keep it inside Container Apps. |
| Mode annotation | `Fresh target default: hosted-no-panel` | Place above the hosted-agent lane. |
| Fallback annotation | `Explicit/sticky classic topology` | Place above the orchestrator fallback. |
| Panel annotation | `Fresh default: panel absent. Explicit hosted-panel: metadata Cosmos only; user/operator routes off/503 pending evidence.` | Place below the hosted lane. |
| Release annotation | `Exact matrix pinned; continuity and panel evidence gates off/503` | Place in an amber status banner below the diagram title. |

## Connections and labels

1. Connect `Signed-in user` to `Trusted Web UI / BFF`.
2. Connect `Trusted Web UI / BFF` to `Microsoft Foundry Hosted Agent` and label
   the connection `x-ms-user-identity; Responses 2.0.0`.
3. Add a separate UI BFF-to-retrieval annotation for `OBO bearer token` and
   state that it is not the Conversation owner header.
4. Attach the two exact direct individual-agent-scope role labels to the UI BFF,
   not the hosted runtime.
5. Connect `Microsoft Foundry Hosted Agent` to `Toolbox / MCP tools` and label
   the connection `opaque x-agent-foundry-call-id`.
6. Connect `Toolbox / MCP tools` to `Authorization-trimmed retrieval`.
7. Connect `Authorization-trimmed retrieval` to Foundry IQ / Azure AI Search
   and label it `native per-user document authorization`.
8. Keep the ingestion-to-Storage / AI Search indexing connections unchanged.
9. Draw a dashed connection from `Trusted Web UI / BFF` to
   `Container Apps orchestrator - explicit fallback`.
10. Place a red stop marker between the hosted and fallback lanes with the label
   `No request-time silent fallback`. Do not connect the lanes as an automatic
   failover path.
11. Add red stop markers from the hosted runtime to the identity-header source,
   Conversation/impersonation RBAC, and Cosmos DB.
12. Do not draw a capability key or continuity Key Vault on the primary path.
   If capability/HMAC appears, place it in a disabled fallback inset only.

## Hosted image preparation inset

Add a small deployment inset near Container Registry with this left-to-right
flow:

`azd provision (prerequisites)` -> `ACR build` -> `immutable sha256 digest` ->
`azd provision (hosted handoff)` -> `azd deploy`

Split `ACR build` into two labeled alternatives:

- `Public: shared ACR Tasks`
- `Private: dedicated VNet ACR Tasks agent pool`

The two alternatives converge on the same `immutable sha256 digest` shape.

## Legend and visual treatment

- Green solid border/fill: target hosted request path.
- Blue solid border/fill: shared UI and ingestion services in Container Apps.
- Gray dashed border: explicit Container Apps fallback.
- Purple solid border/fill: Toolbox and MCP tools.
- Orange solid border/fill: build and immutable-image lifecycle.
- Red stop marker: prohibited request-time cross-backend fallback.
- Amber banner: unpublished release, final-pin, or validation dependency.
- Use black text throughout and preserve the existing typeface, spacing, icon
  family, title, and accessibility contrast.

## Remove or relabel

- Remove any direct `Web UI -> Orchestrator` connection presented as the fresh
  default.
- Remove any label that classifies hosted agents as an optional AI capability.
- Remove the orchestrator Container App from the primary hosted lane.
- Remove the administrative panel and panel-only Cosmos DB from hosted/no-panel.
- Relabel generic `Orchestrator` shapes so the hosted shape and explicit
  Container Apps fallback cannot be confused.
- Remove any automatic or request-time failover arrow between hosted and
  classic modes.

After editing the Visio source, export the full page to
`architecture_zero_trust.png` at the existing canvas size and verify that all
labels remain readable at the published documentation width.
