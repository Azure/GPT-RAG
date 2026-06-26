# 🎯 Orchestrator

The Orchestrator is the core engine of GPT-RAG, an agentic orchestration layer built on the Microsoft Agent Framework and Azure AI Foundry Agent Service. It coordinates agent-based RAG workflows — each agent has a defined role — to generate accurate, context-aware responses for complex user queries. [GitHub Repository](https://github.com/Azure/gpt-rag-orchestrator).

## Key Features

- **Strategy-Based Architecture:** Pluggable orchestration strategies selected via Azure App Configuration (`AGENT_STRATEGY`).
- **Context Retrieval:** Intelligent retrieval from Azure AI Search or Foundry IQ with citation support and conservative retrieval-needed triage for local MAF strategies.
- **Microsoft Agent Framework:** Built on the Microsoft Agent Framework.
- **Conversation Persistence:** Maintains conversation history in Cosmos DB with real-time SSE streaming and bounded persisted history compaction.
- **Extensible Design:** Easy to add new strategies by extending `BaseAgentStrategy`.

## Available Strategies

The Orchestrator supports multiple strategies. The active strategy is set via the `AGENT_STRATEGY` key in Azure App Configuration. The default is `maf_lite`.

| Key | Strategy | Description |
|-----|----------|-------------|
| `maf_lite` | MAF Lite **(default)** | Microsoft Agent Framework with direct Azure OpenAI model access. Lightweight — no Agent Service dependency. Includes user profile memory and optional agentic search. |
| `maf_agent_service` | MAF + Agent Service | Microsoft Agent Framework with Azure AI Foundry Agent Service for server-side thread management and tool orchestration. Includes user profile memory and optional agentic search. |
| `single_agent_rag` | Single Agent RAG | Uses Azure AI Agents SDK with Agent Service for agentic RAG. Supports dynamic routing, streaming via event handlers, and pre-warming for low-latency first responses. |
| `mcp` | MCP | Model Context Protocol strategy using Semantic Kernel. Connects to an MCP server for tool orchestration and passes user context via HTTP headers. |
| `nl2sql` | NL2SQL | Natural language to SQL translation using Microsoft Agent Framework `ChatAgent` with local metadata lookup, SQL validation, and query execution. No Semantic Kernel or Agent Service agent creation is used in this path. |

## Retrieval backend

The orchestrator reads `RETRIEVAL_BACKEND` at startup:

| Value | Behavior |
| --- | --- |
| `ai_search` | Uses the GPT-RAG Azure AI Search index directly. This is the safe default and rollback path. |
| `foundry_iq` | Uses a Foundry IQ knowledge base. See [Retrieval backend selection](howto_retrieval_backend.md) for setup, security modes, and billing. |

`maf_lite`, `maf_agent_service`, `single_agent_rag`, and `multimodal` are the
RAG strategies affected by the backend selector. `mcp` and `nl2sql` do not use
the GPT-RAG retrieval backend.

## Conversation History and Retrieval Controls

Long-running chats are handled in two places: the model prompt receives only a recent history window, while the Cosmos DB conversation document is compacted before persistence so it keeps useful recent context without growing indefinitely. The default `maf_lite` strategy and the `multimodal` strategy also classify each turn as a greeting, retrieval-needed question, or no-retrieval follow-up; transformations such as "format that answer as a table" or "translate the previous answer" can skip Azure AI Search while still using the recent chat history.

| App Configuration key | Default | Purpose |
|-----------------------|---------|---------|
| `CHAT_HISTORY_MAX_MESSAGES` | `10` | Recent messages sent to the response model. |
| `CONVERSATION_HISTORY_COMPACTION_ENABLED` | `true` | Enables compaction before saving a conversation document to Cosmos DB. |
| `CONVERSATION_HISTORY_MAX_PERSISTED_MESSAGES` | `200` | Maximum recent messages kept in the persisted conversation document. |
| `CONVERSATION_HISTORY_MAX_BYTES` | `1500000` | Serialized size target for the persisted conversation document. |
| `RETRIEVAL_INTENT_HISTORY_MESSAGES` | `4` | Recent messages sent only to the retrieval-needed classifier. |
| `RETRIEVAL_INTENT_HISTORY_MAX_CHARS` | `4000` | Character budget for classifier history. |
| `ENABLE_NO_RETRIEVAL_FOLLOWUP_DETECTION` | `true` | Allows no-retrieval follow-ups to skip Azure AI Search; ambiguous turns still retrieve. |

## Visual Guide

New to the Orchestrator? Check out the [Orchestrator Visual Guide](orchestrator_visual_guide.md) for a visual walkthrough of the architecture and key components.

## Repository

🔗 [GitHub Repository](https://github.com/Azure/gpt-rag-orchestrator)
