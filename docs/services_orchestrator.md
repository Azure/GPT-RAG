# 🎯 Orchestrator

The Orchestrator is the core engine of GPT-RAG, an agentic orchestration layer built on the Microsoft Agent Framework and Azure AI Foundry Agent Service. It coordinates agent-based RAG workflows — each agent has a defined role — to generate accurate, context-aware responses for complex user queries. [GitHub Repository](https://github.com/Azure/gpt-rag-orchestrator).

## Key Features

- **Strategy-Based Architecture:** Pluggable orchestration strategies selected via Azure App Configuration (`AGENT_STRATEGY`).
- **Context Retrieval:** Intelligent retrieval from Azure AI Search with citation support.
- **Microsoft Agent Framework:** Built on the Microsoft Agent Framework.
- **Conversation Persistence:** Maintains conversation history in Cosmos DB with real-time SSE streaming.
- **Extensible Design:** Easy to add new strategies by extending `BaseAgentStrategy`.

## Available Strategies

The Orchestrator supports multiple strategies. The active strategy is set via the `AGENT_STRATEGY` key in Azure App Configuration. The default is `maf_lite`.

| Key | Strategy | Description |
|-----|----------|-------------|
| `maf_lite` | MAF Lite **(default)** | Microsoft Agent Framework with direct Azure OpenAI model access. Lightweight — no Agent Service dependency. Includes user profile memory and optional agentic search. |
| `maf_agent_service` | MAF + Agent Service | Microsoft Agent Framework with Azure AI Foundry Agent Service for server-side thread management and tool orchestration. Includes user profile memory and optional agentic search. |
| `single_agent_rag` | Single Agent RAG | Uses Azure AI Agents SDK with Agent Service for agentic RAG. Supports dynamic routing, streaming via event handlers, and pre-warming for low-latency first responses. |
| `mcp` | MCP | Model Context Protocol strategy using Semantic Kernel. Connects to an MCP server for tool orchestration and passes user context via HTTP headers. |
| `nl2sql` | NL2SQL | Natural language to SQL translation using a multi-agent pipeline (Triage → SQL Query → Synthesizer) with Semantic Kernel and Agent Service. |

## Visual Guide

New to the Orchestrator? Check out the [Orchestrator Visual Guide](orchestrator_visual_guide.md) for a visual walkthrough of the architecture and key components.

## Repository

🔗 [GitHub Repository](https://github.com/Azure/gpt-rag-orchestrator)
