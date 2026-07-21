This page highlights the notable features added to GPT-RAG over time. It is a
feature outline, not a full changelog. For the detailed record of every release,
patch, and fix, see the [GitHub releases](https://github.com/Azure/GPT-RAG/releases).

> 📌 [Check out what's coming next](https://github.com/orgs/Azure/projects/536/views/6)  (Azure org only)

### July 2026

- **Governance audit and provenance integration ([GPT-RAG v3.7.0](https://github.com/Azure/GPT-RAG/releases/tag/v3.7.0)).**
  The umbrella release pins orchestrator `v3.8.0` and ingestion
  `v2.5.0` to the shared `audit-event-v1` contract. Audit, sensitive-content
  capture, actor pseudonymization, and ingestion provenance remain off by
  default. When no operator-managed HMAC reference exists, post-provisioning
  creates a stable 256-bit key in Key Vault and registers only its Key Vault
  reference; existing Key Vault references are preserved. It also adds optional
  provenance fields to existing Azure AI Search indexes without recreating
  them. See
  [Audit Contract v1](governance_audit_contract_v1.md) for configuration,
  migration, rollback, and evidence limitations. `delete_after` records policy
  intent only; it does not trigger automatic deletion.
- **Generic MCP Server knowledge source (preview, [v3.6.0](https://github.com/Azure/GPT-RAG/releases/tag/v3.6.0)).**
  The Knowledge Base can call approved tools on a remote MCP server you
  operate or trust and blend those results with other Foundry IQ sources.
  The feature is off by default, requires a trusted-host allowlist, and must
  be deployed together with orchestrator `v3.7.0`. See
  [Foundry IQ: Generic MCP server](howto_grounding_mcp_server.md).
- **Four new Foundry IQ knowledge sources (preview, [v3.5.0](https://github.com/Azure/GPT-RAG/releases/tag/v3.5.0)).** All off by default and gated by their own App Config flags.
    - **SharePoint remote (`remoteSharePoint`).** Live retrieval from SharePoint via the Copilot Retrieval API, with per-user OBO ACL. See [Foundry IQ: SharePoint remote](howto_grounding_sharepoint_remote.md).
    - **OneLake indexed (`indexedOneLake`).** Fabric OneLake as a knowledge source, indexed and queried natively by Foundry IQ. See [Foundry IQ: OneLake](howto_grounding_onelake.md).
    - **SharePoint indexed (`indexedSharePoint`).** Foundry IQ indexes a SharePoint site using app-only Microsoft Graph auth (Sites.Selected preferred). See [Foundry IQ: SharePoint indexed](howto_grounding_sharepoint_indexed.md).
    - **Web grounding (`web`).** Public web results scoped by allow / block domain lists, billed per Bing call. See [Foundry IQ: Web grounding](howto_grounding_web_bing.md).
- **Fabric Data Agent grounding (preview, [v3.4.3](https://github.com/Azure/GPT-RAG/releases/tag/v3.4.3)).** Answers can now be grounded on a Microsoft Fabric Data Agent, a virtual analyst that runs queries over Fabric data. It sits alongside documents, Work IQ, and the Fabric ontology source. Off by default, same OBO auth and data-egress notes as the other Fabric source. See [Foundry IQ: Fabric Data Agent](howto_grounding_fabric_data_agent.md).
- **App Configuration seeding fix ([v3.4.1](https://github.com/Azure/GPT-RAG/releases/tag/v3.4.1)).** `azd provision` now seeds the `WORK_IQ_*` and `FABRIC_IQ_*` App Configuration keys with `enabled=false` and empty string defaults, so operators no longer have to create them by hand before flipping Work IQ or the Fabric knowledge sources on in an existing environment.
- **Fabric ontology grounding (preview, v3.4.0).** Answers can now blend analytical data from a Microsoft Fabric ontology alongside documents and Work IQ. Off by default, gated by data residency (may route data outside your Foundry region). See [Foundry IQ: Fabric ontology](howto_grounding_fabric_ontology.md) and the [Grounding sources overview](howto_grounding_overview.md).
- **Work IQ grounding (public preview).** The orchestrator can now augment retrieval with signals from the signed-in user's Microsoft 365 world (mail, meetings, files, chats, people) through Foundry IQ. Off by default. Requires a signed-in user, an M365 Copilot license, and gated preview access. Work IQ, the Fabric knowledge sources, and the documents source can all run together on the same Knowledge Base. See [Foundry IQ: Work IQ](howto_grounding_work_iq.md).
- **CAF resource naming by default.** Fresh Basic and Zero Trust deployments produce Cloud Adoption Framework-aligned resource names automatically, with an opt-out to the legacy scheme. See [resource naming guide](howto_resource_naming.md).
- **Admin dashboard sign-in.** The orchestrator dashboard SPA now performs its own Microsoft Entra ID sign-in using MSAL (Authorization Code + PKCE), with a clear "signed in but missing Admin role" state and a runtime `auth-config` endpoint so the SPA can bootstrap in either authenticated or open mode. See [Admin Dashboard Sign-in](howto_dashboard_signin.md).

### June 2026

- **Foundry IQ retrieval backend.** New deployments retrieve through a native Azure Blob Knowledge Source in Foundry IQ by default, with Azure AI Search still fully supported for existing deployments and custom ingestion pipelines. See [Grounding sources overview](howto_grounding_overview.md).
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
