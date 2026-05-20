> 📌 [Check out what's coming next](https://github.com/orgs/Azure/projects/536/views/6)  (Azure org only)

### May 2026

**[Release 2.7.0](https://github.com/Azure/GPT-RAG/tree/v2.7.0) - AI Landing Zone v2.0 bump**

The underlying Azure AI Landing Zone Bicep module has been upgraded from v1.0.7 to v2.0.2 — a major-version baseline update. Default behavior is unchanged for existing operators; all new capabilities are opt-in via `azd env set`.

Highlights of what v2 brings to GPT-RAG operators:

- **IP allow-listing** (`allowedIpRanges`): uniform CIDR allow-list applied across Storage, Key Vault, App Configuration, Container Registry, Cosmos DB, AI Search, and the AI Foundry storage account.
- **BYO Private DNS zones / observability / hub-and-spoke** parameters for integration with an existing Azure Landing Zone hub.
- **Pre-flight validation hooks** that catch parameter contradictions before reaching ARM and fail fast when the selected GPT-RAG region lacks required VM SKU support, provider/location support, or Azure OpenAI model quota. The preflight is explicit about limits Azure does not expose reliably before creation, such as transient Cosmos DB high-demand capacity.
- **Cosmos `enableAnalyticalStorage` fix** — the implicit `true` default that caused intermittent provisioning failures is gone; now an explicit opt-in via `enableCosmosAnalyticalStorage`.
- **Network-isolated deployment procedure clarified** — workstations run only `azd provision`; `postProvision` and `azd deploy` run from the jumpbox/VNet with `RUN_FROM_JUMPBOX=true`, using ACR remote builds so Docker is not required on the VM.

See the [v2-migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.0/docs/v2-migration.md) and the [parameterization reference](https://azure.github.io/AI-Landing-Zones/bicep/parameterization) for the full v2 surface. No GPT-RAG component bumps in this release.

**[Release 2.6.7](https://github.com/Azure/GPT-RAG/tree/v2.6.7) - Per-conversation file uploads**

Users can now upload files directly through the chat interface. Documents are persisted to a per-conversation storage container, chunked and indexed into Azure AI Search with a `conversationId` field, and retrieved by the orchestrator with a filter that mixes conversation-private content with shared/global content. Implemented across coordinated component releases: `gpt-rag-ingestion` v2.3.4, `gpt-rag-orchestrator` v2.6.3, `gpt-rag-ui` v2.3.2.

---

### April 2026

**[Release 2.6.4](https://github.com/Azure/GPT-RAG/tree/v2.6.4) - Ingestion Enhancements, Ingestion Admin Dashboard, and Cost Optimization**

**Ingestion Admin Dashboard**

A new React-based admin dashboard is available at `/dashboard` for monitoring and managing ingestion jobs. It provides paginated job and file tables, search, filters, and the ability to unblock stuck files. Processing timings are displayed as stacked color bars showing each phase (download, analysis, chunking, index upload), and per-file cost estimates break down spending by service.

**Content Understanding Integration**

Document analysis now uses Azure AI Foundry Content Understanding (`prebuilt-layout`) by default instead of Document Intelligence, resulting in approximately 69% cost reduction per page.

**Reliability and Large File Handling**

Files that fail during ingestion are now tracked per attempt. After exceeding the maximum retries (default 3), the file is automatically blocked, preventing repeated reprocessing and unnecessary document analysis costs. Stale jobs stuck after a container crash are auto-recovered after 2 hours. Additionally, large PDFs exceeding the analysis page limit (default 300 pages) are split automatically, and a memory guard skips oversized files to prevent OOM crashes.

* Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/BRwGaBAIICg?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="User Feedback" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

---

**[Release 2.6.1](https://github.com/Azure/GPT-RAG/tree/v2.6.1) - Conversation History and Multimodal Improvements**

**Conversation History**

Users can now list, resume, and delete past conversations directly from a sidebar in the chat UI.

**Multimodal Improvements**

Images now appear inline between response steps instead of grouped at the bottom, with improved validation accuracy.

---

### March 2026

**[Release 2.5.3](https://github.com/Azure/GPT-RAG/tree/v2.5.3) - New Orchestration Strategies, Infrastructure Overhaul, and Multimodality**

**New Orchestration Strategies** 

The orchestrator now supports new agentic strategies: 

- **Agent Service v2** uses Azure AI Foundry Agent Service v2 for managed orchestration. 

- **Microsoft Agent Framework**, Lightweight orchestration with direct Foundry access, no Agent Service.

- **Agent Service + Agent Framework** combines Agent Service v2 with the Microsoft Agent Framework for advanced scenarios. 

- **Multimodal** adds image understanding support for multimodality scenarios.  

**Infrastructure as External Bicep Module**

Bicep infrastructure extracted to the external [`bicep-ptn-aiml-landing-zone`](https://github.com/Azure/bicep-ptn-aiml-landing-zone) module for better maintainability and reuse. Deploy scripts hardened. [#424](https://github.com/Azure/GPT-RAG/pull/424)

---

### January 2026

**[Release 2.4.0](https://github.com/Azure/GPT-RAG/tree/v2.4.0) - Authentication and Document-Level Security**

This release introduces Microsoft Entra ID authentication in the frontend, with orchestrator-side user identity validation, plus RBAC-based access control and document-level authorization in retrieval workflows. It propagates user identity context through ingestion and orchestration so [Azure AI Search can enforce fine-grained ACL/RBAC](https://learn.microsoft.com/en-us/azure/search/search-query-access-control-rbac-enforcement) permissions end-to-end. [#417](https://github.com/Azure/GPT-RAG/pull/417)
  
How to configure it: [Authentication and Document-Level Security](howto_authentication.md)

### December 2025

**[Release 2.3.0](https://github.com/Azure/GPT-RAG/tree/v2.3.0) - SharePoint Lists and Azure Direct Models**

**Azure Direct Models (Microsoft Foundry)**

You can use Microsoft Foundry “Direct from Azure” models (for example, Mistral, DeepSeek, Grok, Llama, etc.) through the Foundry inference APIs with Entra ID authentication. [#296](https://github.com/Azure/GPT-RAG/issues/296)
  
How to configure it: [Azure Direct Models](howto_azure_direct.md)
  
Demo Video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/P87o8UwiTHw?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="User Feedback" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>


**SharePoint Lists**

The SharePoint connector now covers both SharePoint Online document libraries (files like PDFs/Office docs) and generic lists (structured fields) so your Azure AI Search index stays in sync with list items and documents. [#369](https://github.com/Azure/GPT-RAG/issues/369)

How to configure it: [SharePoint Data Source](ingestion_sharepoint_source.md) and [SharePoint Connector Setup Guide](howto_sharepoint_connector.md)

---

### October 2025

**[Release 2.2.0](https://github.com/Azure/GPT-RAG/tree/v2.2.1) - Agentic Retrieval and Network Flexibility**

This release introduces major enhancements to support more flexible and enterprise-ready deployments.

**Bring Your Own VNet**

Enables organizations to deploy GPT-RAG within their existing virtual network, maintaining full control over network boundaries, DNS, and routing policies. [#370](https://github.com/Azure/GPT-RAG/issues/370)

**Agentic Retrieval**

Adds intelligent, agent-driven retrieval orchestration that dynamically selects and combines information sources for more grounded and context-aware responses. [#359](https://github.com/Azure/GPT-RAG/issues/359)

---

### September 2025

**[Release 2.1.0](https://github.com/Azure/GPT-RAG/tree/v2.1.2) - User Feedback Loop**

Introduces a mechanism for end-users to provide thumbs-up or thumbs-down feedback on assistant responses, storing these signals alongside conversation history to continuously improve response quality.

* How to configure it: [User Feedback Configuration](howto_userfeedback.md)
* Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/t2EkzJ9P8HA?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="User Feedback" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>
