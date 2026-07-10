This page highlights the notable features added to GPT-RAG over time. It is a
feature outline, not a full changelog. For the detailed record of every release,
patch, and fix, see the [GitHub releases](https://github.com/Azure/GPT-RAG/releases).

> 📌 [Check out what's coming next](https://github.com/orgs/Azure/projects/536/views/6)  (Azure org only)

### July 2026

- **Work IQ grounding (public preview).** The orchestrator can now augment retrieval with signals from the signed-in user's Microsoft 365 world (mail, meetings, files, chats, people) through Foundry IQ. Off by default. Requires a signed-in user, an M365 Copilot license, and gated preview access. See [Work IQ grounding](howto_work_iq.md).
- **CAF resource naming by default.** Fresh Basic and Zero Trust deployments produce Cloud Adoption Framework-aligned resource names automatically, with an opt-out to the legacy scheme. See [resource naming guide](howto_resource_naming.md).
- **Admin dashboard sign-in.** The orchestrator dashboard SPA now performs its own Microsoft Entra ID sign-in using MSAL (Authorization Code + PKCE), with a clear "signed in but missing Admin role" state and a runtime `auth-config` endpoint so the SPA can bootstrap in either authenticated or open mode. See [Admin Dashboard Sign-in](howto_dashboard_signin.md).

### June 2026

- **Foundry IQ retrieval backend.** New deployments retrieve through a native Azure Blob Knowledge Source in Foundry IQ by default, with Azure AI Search still fully supported for existing deployments and custom ingestion pipelines. See [Retrieval backend selection](howto_retrieval_backend.md).
- **Operator dashboards.** An opt-in dashboard at `/dashboard` on the orchestrator and ingestion apps gives admins conversation analytics, a conversations browser, live configuration editing, and on-demand job runs with queue and schedule visibility.

### May 2026

- **In-chat file uploads.** Users can upload files directly in a conversation, and the uploader identity is preserved end to end so uploaded content is retrieved only within that conversation.
- **Existing-platform deployment.** Operators can integrate with shared Private DNS zones, hub networking, observability, jumpbox/Bastion/NAT, and other existing platform resources from the root parameters file, without editing the infra submodule.
- **AI Landing Zone v2.** Adds uniform IP allow-listing across services, bring-your-own DNS/observability/hub-and-spoke parameters, and pre-flight validation that fails fast on region, quota, or parameter problems before reaching ARM.

### April 2026

- **Ingestion Admin Dashboard with Content Understanding.** A dashboard for monitoring and managing ingestion jobs and files, plus document analysis via Azure AI Foundry Content Understanding by default for roughly 69% lower cost per page.

  <div style="position: relative; padding-bottom: 42%; height: 0; overflow: hidden; max-width: 640px; margin: 12px 0 20px 0; border-radius: 8px;">
    <iframe src="https://www.youtube.com/embed/BRwGaBAIICg?rel=0&modestbranding=1"
            style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;"
            title="Ingestion Admin Dashboard"
            frameborder="0"
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen>
    </iframe>
  </div>
- **Conversation history.** List, resume, and delete past conversations from a sidebar in the chat UI, with inline multimodal images between response steps.

### March 2026

- **Orchestration strategies.** Choose between Azure AI Foundry Agent Service v2, the Microsoft Agent Framework, a combined mode, and multimodal, with Bicep infrastructure moved to the external [AI Landing Zone module](https://github.com/Azure/bicep-ptn-aiml-landing-zone).

### January 2026

- **Document-level security.** Microsoft Entra ID authentication with orchestrator-side identity validation and RBAC/ACL enforcement in retrieval, so access control is applied end to end. See [Authentication and Document-Level Security](howto_authentication.md).

### December 2025

- **Azure Direct Models (Microsoft Foundry).** Use Foundry "Direct from Azure" models such as Mistral, DeepSeek, Grok, and Llama through the Foundry inference APIs with Entra ID authentication. See [Azure Direct Models](howto_azure_direct.md).

  <div style="position: relative; padding-bottom: 42%; height: 0; overflow: hidden; max-width: 640px; margin: 12px 0 20px 0; border-radius: 8px;">
    <iframe src="https://www.youtube.com/embed/P87o8UwiTHw?rel=0&modestbranding=1"
            style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;"
            title="Azure Direct Models"
            frameborder="0"
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen>
    </iframe>
  </div>
- **SharePoint Lists.** The SharePoint connector covers both document libraries and generic lists, keeping your index in sync with list items and documents. See [SharePoint Data Source](ingestion_sharepoint_source.md).

### October 2025

- **Bring Your Own VNet.** Deploy GPT-RAG inside your existing virtual network with full control over network boundaries, DNS, and routing.
- **Agentic retrieval.** Agent-driven retrieval that dynamically selects and combines information sources for more grounded responses.

### September 2025

- **User feedback loop.** End users can rate assistant responses thumbs-up or thumbs-down, stored alongside conversation history to improve quality. See [User Feedback Configuration](howto_userfeedback.md).

  <div style="position: relative; padding-bottom: 42%; height: 0; overflow: hidden; max-width: 640px; margin: 12px 0 20px 0; border-radius: 8px;">
    <iframe src="https://www.youtube.com/embed/t2EkzJ9P8HA?rel=0&modestbranding=1"
            style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;"
            title="User Feedback"
            frameborder="0"
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen>
    </iframe>
  </div>
