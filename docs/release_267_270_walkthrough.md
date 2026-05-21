# Release walkthrough: file uploads and AI Landing Zone v2

Use this page as a guided walkthrough for the latest GPT-RAG updates around per-conversation file uploads, deployment hardening, and the Azure AI Landing Zone v2 foundation.

## 1. Executive summary

GPT-RAG now has two important improvements for real deployments:

1. **Per-conversation file uploads**: users can upload documents directly in the chat and ask questions over those files in the current conversation.
2. **Deployment reliability improvements**: GPT-RAG now uses the Azure AI Landing Zone v2 foundation, adds preflight validation, clarifies the Network Isolation flow, and supports Docker-free remote builds with Azure Container Registry.

The user-facing result is simple: users get a richer chat experience, while operators get a clearer and safer deployment path.

## 2. What to show first

Start on the **What's New** page and point out:

- **Release 2.6.7 — Per-conversation file uploads**
- **Release 2.7.0 — AI Landing Zone v2.0 bump and deployment hardening**

Then move to this walkthrough to explain the story end-to-end.

## 3. Per-conversation file uploads

### What changed

Users can upload files directly through the chat UI. GPT-RAG ingests the uploaded file, indexes its chunks in Azure AI Search, and scopes those chunks to the active conversation.

### Why it matters

- Users can ask questions about a file without making it part of the global corpus.
- Uploaded content is isolated by `conversationId`.
- The orchestrator retrieves both conversation-private chunks and shared/global chunks when answering.
- Citations can point back to the uploaded file content.

### Architecture talking points

| Layer | What to explain |
| --- | --- |
| UI | The chat interface exposes file upload when the user is authenticated or the configured access mode allows it. |
| Ingestion | Uploaded files are persisted and chunked, then written to Azure AI Search with a `conversationId`. |
| Orchestrator | Retrieval filters include the current conversation plus shared/global content. |
| Storage/Search | Original files and indexed chunks remain separate from the global ingestion flow. |

### Demo script

1. Open GPT-RAG.
2. Start a new conversation.
3. Upload a small document.
4. Ask a question whose answer is only in that document.
5. Point out that the answer is grounded in the uploaded file.
6. Start or switch to another conversation and explain that private uploaded chunks are scoped by conversation.

## 4. AI Landing Zone v2 foundation

### What changed

GPT-RAG now consumes the newer Azure AI Landing Zone Bicep foundation. This brings a more robust infrastructure baseline and a clearer path for enterprise scenarios.

### What to highlight

- **IP allow-listing** through `allowedIpRanges`.
- **Bring-your-own Private DNS zones** for hub-and-spoke or enterprise landing zone integration.
- **Bring-your-own observability** with existing Log Analytics and Application Insights.
- **Deployment mode** parameterization for standalone versus landing-zone-integrated topologies.
- **Preflight validation** before ARM deployment reaches late failures.

### Operator value

The upgrade reduces the chance of failing late in provisioning and gives platform teams more control over networking, DNS, and observability integration.

## 5. Regional preflight checks

### What changed

Before provisioning, GPT-RAG now validates whether the selected region can support the important deployment prerequisites.

### Checks to mention

- Azure CLI subscription matches the `azd` environment.
- Region is supported by required resource providers.
- Jumpbox VM SKU is available.
- Azure AI Search, Cosmos DB, Container Apps, and AI Foundry/Cognitive Services are supported in the selected region.
- Azure OpenAI deployment quota is sufficient for the configured models.

### Important limitation

Some Azure capacity issues are transient and are not exposed by a reliable pre-create API. Cosmos DB high-demand `ServiceUnavailable` is the main example. The preflight is explicit about that limitation.

## 6. Basic deployment path

Use this path for a simple environment without Network Isolation.

```bash
azd init -t azure/gpt-rag
az login
azd auth login
azd env set NETWORK_ISOLATION false
azd provision
azd deploy
```

### What to explain

- The workstation can run the full flow.
- `postProvision` runs locally after `azd provision`.
- Component images can be built locally with Docker or remotely with ACR when configured.

## 7. Network Isolation deployment path

Network Isolation uses a two-host flow.

| Phase | Where it runs | Why |
| --- | --- | --- |
| `azd provision` | Workstation | Creates the private infrastructure. |
| `scripts/postProvision.ps1` | Jumpbox or VNet-connected host | Data-plane resources are private. |
| `azd deploy` | Jumpbox or VNet-connected host | Private ACR and private Container Apps are reachable only inside the VNet. |

### Workstation

```powershell
azd env set NETWORK_ISOLATION true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING true
azd provision
```

### Jumpbox

```powershell
cd C:\github\GPT-RAG
az login --identity
azd auth login --managed-identity
azd env set RUN_FROM_JUMPBOX true
.\scripts\postProvision.ps1
azd env set ACR_TASK_AGENT_POOL build-pool
azd deploy
```

### What not to do

Do not run `azd deploy` from the workstation when `NETWORK_ISOLATION=true`. The deployment hook blocks this intentionally.

`BUILD_MODE` normally does not need to be set. When `NETWORK_ISOLATION=true` or `ACR_TASK_AGENT_POOL` is set, component scripts infer ACR remote build.

## 8. Docker-free deployment

### What changed

Component deployment can use Azure Container Registry remote builds, so Docker does not need to be installed on the jumpbox for network-isolated deployments.

### Why it matters

- Easier jumpbox setup.
- Fewer local dependencies.
- Builds run inside the private ACR build path.
- The same deploy command works for the operator.

## 9. Validation status

The current flow was validated in both modes:

| Mode | Result |
| --- | --- |
| Basic deployment | Provision, post-provision, deploy, and smoke checks completed successfully. |
| Network Isolation | Workstation provision, jumpbox post-provision, private ACR Tasks deploy, and smoke checks completed successfully. |

Smoke checks included:

- Frontend returns HTTP 200.
- Data ingestion returns HTTP 200.
- Orchestrator root returns the expected HTTP 404.
- Container Apps are `Succeeded` and `Running`.

## 10. Recommended walkthrough order

1. Start with **What's New** to show the two release themes.
2. Open this walkthrough page.
3. Explain file upload from a user perspective.
4. Explain the architecture path: UI → ingestion → storage/search → orchestrator.
5. Explain the AI Landing Zone v2 operator value.
6. Show the **Deployment Guide** and compare Basic versus Network Isolation.
7. Emphasize the new regional preflight checks and Docker-free ACR remote build flow.
8. Close with validation: both Basic and Network Isolation paths were tested end-to-end.

