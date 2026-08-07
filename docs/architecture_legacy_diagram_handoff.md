# Legacy architecture diagram update handoff

Use this checklist to manually update `media/GPT-RAG.vsdx`, then export the
updated full reference view to `media/architecture_zero_trust.png`. The SVG
diagrams remain the editable source for the focused Basic, modular-layer, and
chat-runtime views.

!!! warning "Release status"
    Draw the hosted/no-panel path as the **target fresh-deployment default** and
    label it **Platform contracts merged; compatible pins and owner validation
    pending**. Do not label it shipped until the planned component and AI
    Landing Zone tags, final umbrella pins, owner-binding validation, integrated
    validation, and GPT-RAG release publish. Show hosted continuity as disabled.

## Shapes and labels

Add or update these shapes in the application/runtime area:

| Shape | Exact label | Placement |
| --- | --- | --- |
| Existing application host boundary | `Azure Container Apps` | Keep around the Web UI and ingestion services. |
| Existing UI shape | `Web UI / BFF` | Keep in Container Apps at the request-path entry and make it the exclusive owner of Foundry Conversation operations and capabilities. |
| Existing ingestion shape | `Ingestion` | Keep in Container Apps and connected to Storage / AI Search indexing. |
| New primary runtime shape | `Microsoft Foundry Hosted Agent` | Place to the right of Web UI, outside the Container Apps boundary and inside the Microsoft Foundry boundary. |
| New state shape | `Foundry managed Conversations` | Connect only to the UI BFF. Do not connect it to the hosted runtime. |
| New secret shape | `Dedicated UI BFF Key Vault` | Connect only to the UI BFF and label the connection `individual capability-secret scope`. |
| App Configuration annotation | `Key Vault reference only` | Place between App Configuration and the UI BFF. Do not show a plaintext capability key. |
| New tool boundary | `Toolbox / MCP tools` | Place to the right of the hosted agent. |
| New retrieval shape | `Authorization-trimmed retrieval` | Place below Toolbox and connect to Foundry IQ / Azure AI Search. |
| Fallback runtime shape | `Container Apps orchestrator - explicit fallback` | Place below the primary request path with a dashed border. Keep it inside Container Apps. |
| Mode annotation | `Fresh target default: hosted-no-panel` | Place above the hosted-agent lane. |
| Fallback annotation | `Explicit/sticky classic topology` | Place above the orchestrator fallback. |
| Panel annotation | `Administrative panel absent; DEPLOY_ADMINISTRATIVE_PANEL=false` | Place below the hosted lane. |
| Release annotation | `Platform contracts merged; continuity disabled; compatible pins and owner validation pending` | Place in an amber status banner below the diagram title. |

## Connections and labels

1. Connect `Signed-in user` to `Web UI / BFF`.
2. Connect `Web UI / BFF` to `Microsoft Foundry Hosted Agent` and label the connection
   `delegated user OBO`.
3. Connect `Web UI / BFF` to `Foundry managed Conversations` and label it
   `exclusive CRUD; owner-bound capability`.
4. Connect `Dedicated UI BFF Key Vault` to `Web UI / BFF` and label it
   `HMAC key; secret-scoped read`.
5. Connect App Configuration to `Web UI / BFF` and label it
   `Key Vault reference only`.
6. Connect `Microsoft Foundry Hosted Agent` to `Toolbox / MCP tools` and label
   the connection `opaque x-agent-foundry-call-id`.
7. Connect `Toolbox / MCP tools` to `Authorization-trimmed retrieval`.
8. Connect `Authorization-trimmed retrieval` to Foundry IQ / Azure AI Search
   and label it `native per-user document authorization`.
9. Keep the ingestion-to-Storage / AI Search indexing connections unchanged.
10. Draw a dashed connection from `Web UI / BFF` to
   `Container Apps orchestrator - explicit fallback`.
11. Place a red stop marker between the hosted and fallback lanes with the label
   `No request-time silent fallback`. Do not connect the lanes as an automatic
   failover path.
12. Add red stop markers from the hosted runtime to both the capability secret
   and managed Conversations with the labels `No key or raw oid` and
   `No Conversations RBAC`.

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
