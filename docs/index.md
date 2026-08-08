<img src="media/logo.png" alt="Enterprise RAG Logo" width="80" align="left"/>

# GPT-RAG Solution Accelerator 

GPT-RAG is an enterprise-grade accelerator for building conversational AI assistants on Azure, powered by intelligent agents that understand questions, find the right information, and deliver clear, accurate answers using trusted enterprise data.

Designed with Zero-Trust security and Infrastructure as Code (IaC) principles from the ground up, GPT-RAG accelerates production deployments while ensuring consistency, governance, and operational excellence. It supports text, image, and voice scenarios, enabling organizations to rapidly create rich multimodal experiences.

[Latest Stable Release {{ latest_release("azure/gpt-rag") }} :material-tag:](https://github.com/azure/gpt-rag/releases/latest){ .md-button--pill }
{% set rc_tag = latest_release_candidate("azure/gpt-rag") %}{% if rc_tag %}
[Pre-release {{ rc_tag }} :material-tag: ]({{ latest_release_candidate_url("azure/gpt-rag") }}){ data-md-color-accent="orange" .md-button--pill .md-button--pill--rc }
{% endif %}

## Architecture at a glance

GPT-RAG can start as a Basic deployment and expand into Zero Trust, public
ingress, existing-platform integration, or optional AI capabilities. The
approved target makes Microsoft Foundry hosted/no-panel the fresh-deployment
chat runtime and retains the Container Apps orchestrator as an explicit
fallback. See the [Architecture](architecture.md) page for the mode contract
and required-vs-configurable deployment table.

!!! warning "Exact matrix pinned; runtime validation and release remain blocked"
    The umbrella integration pins UI `v2.6.0`, orchestrator `v4.0.0`, ingestion
    `v2.7.0`, and AILZ `v2.5.0`. Explicit hosted-panel topology selection is
    supported, but continuity, user-history, owner-binding validation, and
    operator-surface gates remain deployment-published `false`. The latest
    runtime attempt activated the agent version but session readiness returned
    HTTP 424, so the integration is not validated or shipped. See the
    [hosted-agent integration matrix](hosted_agent_release_matrix.md) for
    the exact runtime, identity, RBAC, panel, data, and rollback contracts.

![Chat runtime modes and hosted deployment lifecycle](media/architecture_chat_runtime_modes.svg)

![Modular architecture layers](media/architecture_modular_layers.svg)

![Zero Trust Architecture](media/architecture_zero_trust.png)
*Full Zero Trust reference architecture. This is the complete network-isolated
view, not the minimum Basic deployment. The focused SVG above describes the
component-level hosted design; the matrix page records its umbrella release
gate.*

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
| **[Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)** | Manages agentic workflows with Microsoft Agent Framework, Azure AI, and strategy-specific integrations. |
| **[Web UI](https://github.com/Azure/gpt-rag-ui)**                 | User interface for chat interactions, supports streaming and custom themes.             |
| **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)**  | Extracts, chunks, and indexes enterprise data for optimized retrieval.                  |
| **[MCP Server](https://github.com/Azure/gpt-rag-mcp)**            | Optional Model Context Protocol service for tool hosting and business logic integration. |


## Contributing

We welcome contributions from the community! Check our **[Contribution Guidelines](contributing.md)** for CLA, code of conduct, and PR guidelines.