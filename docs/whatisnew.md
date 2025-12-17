> 📌 [Check out what's coming next](https://github.com/orgs/Azure/projects/536/views/6)  (Azure org only)

### December 2025

**[Release 2.3.0](https://github.com/Azure/GPT-RAG/tree/v2.3.0) - SharePoint Lists and Azure Direct Models**

This release adds two major capabilities:

**Azure Direct Models (Microsoft Foundry)**
  You can use Microsoft Foundry “Direct from Azure” models (for example, Mistral, DeepSeek, Grok, Llama, etc.) through the Foundry inference APIs with Entra ID authentication.
  How to configure it: [Azure Direct Models](howto_azure_direct.md)

**SharePoint Lists**
  The SharePoint connector now covers both SharePoint Online document libraries (files like PDFs/Office docs) and generic lists (structured fields) so your Azure AI Search index stays in sync with list items and documents.
  How to configure it: [SharePoint Data Source](ingestion_sharepoint_source.md) and [SharePoint Connector Setup Guide](howto_sharepoint_connector.md)

### October 2025

**[Release 2.2.0](https://github.com/Azure/GPT-RAG/tree/v2.2.1) - Agentic Retrieval and Network Flexibility**

This release introduces major enhancements to support more flexible and enterprise-ready deployments.

**Bring Your Own VNet**
  Enables organizations to deploy GPT-RAG within their existing virtual network, maintaining full control over network boundaries, DNS, and routing policies.
  [#370](https://github.com/Azure/GPT-RAG/issues/370)

**Agentic Retrieval**
  Adds intelligent, agent-driven retrieval orchestration that dynamically selects and combines information sources for more grounded and context-aware responses.
  [#359](https://github.com/Azure/GPT-RAG/issues/359)

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