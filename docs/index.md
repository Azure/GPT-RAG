<img src="media/logo.png" alt="Enterprise RAG Logo" width="80" align="left"/>

# GPT-RAG Solution Accelerator 

GPT-RAG is an enterprise-grade accelerator for building agentic AI assistants on **Microsoft Foundry**. Agents built with the **Microsoft Agent Framework** interpret the question, retrieve the right evidence through **Foundry IQ**, the default retrieval backend since v3.0.2, and return grounded, traceable answers over trusted enterprise data.

Foundry IQ gives the orchestrator one Knowledge Base endpoint that fans out across Blob, existing Azure AI Search indexes, Work IQ, Fabric, SharePoint, OneLake, Web and MCP servers, with permission trimming built in. Azure AI Search direct remains fully supported as the compatibility and rollback path. See [Grounding sources overview](howto_grounding_overview.md).

Designed with Zero-Trust security and Infrastructure as Code (IaC) principles from the ground up, GPT-RAG accelerates production deployments while ensuring consistency, governance, and operational excellence. It supports text, image, and voice scenarios, enabling organizations to rapidly create rich multimodal experiences.

[Latest Stable Release {{ latest_release("azure/gpt-rag") }} :material-tag:](https://github.com/azure/gpt-rag/releases/latest){ .md-button--pill }
{% set rc_tag = latest_release_candidate("azure/gpt-rag") %}{% if rc_tag %}
[Pre-release {{ rc_tag }} :material-tag: ]({{ latest_release_candidate_url("azure/gpt-rag") }}){ data-md-color-accent="orange" .md-button--pill .md-button--pill--rc }
{% endif %}

## Architecture at a glance

GPT-RAG can start as a Basic deployment and expand into Zero Trust, public
ingress, existing-platform integration, or optional AI capabilities. Retrieval
and orchestration run on Microsoft Foundry, with the orchestrator hosted in
Container Apps. See the [Architecture](architecture.md) page for the deployment
modes and the required-vs-configurable table.

![Zero Trust Architecture](media/architecture_zero_trust.png)
*Full Zero Trust reference architecture. This is the complete network-isolated
view, not the minimum Basic deployment.*

## Governance

Before connecting enterprise data or relying on telemetry as evidence, review
[Governance and responsible operation](governance_overview.md). It explains
intended use, limitations, data and telemetry responsibilities, retention,
access, and the exact audit trail contract available since
[GPT-RAG v3.7.0](https://github.com/Azure/GPT-RAG/releases/tag/v3.7.0),
disabled by default.

## Runtime Services

| Services                                                          | Description                                                                             |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **[Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)** | Manages agentic workflows with Microsoft Agent Framework on Microsoft Foundry, Foundry IQ retrieval, and strategy-specific integrations. |
| **[Web UI](https://github.com/Azure/gpt-rag-ui)**                 | User interface for chat interactions, supports streaming and custom themes.             |
| **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)**  | Extracts, chunks, and indexes enterprise data for optimized retrieval.                  |
| **[MCP Server](https://github.com/Azure/gpt-rag-mcp)**            | Optional Model Context Protocol service for tool hosting and business logic integration. |


## Contributing

We welcome contributions from the community! Check our **[Contribution Guidelines](contributing.md)** for CLA, code of conduct, and PR guidelines.