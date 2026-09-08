# 🎯 Orchestrator

The Orchestrator is the core engine of GPT-RAG, an agentic orchestration layer
built on the Microsoft Agent Framework and Azure AI Foundry Agent Service. It
coordinates agent-based RAG workflows, where each agent has a defined role, to
generate accurate, context-aware responses for complex user queries. Current
GPT-RAG umbrella releases run it as an orchestrator Container App. Orchestrator
`v4.1.1` also packages the runtime as a Microsoft Foundry hosted agent, which
[GPT-RAG `v3.8.3`](https://github.com/Azure/GPT-RAG/releases/tag/v3.8.3) makes
the default for genuinely fresh deployments; see the
[exact hosted integration matrix](hosted_agent_release_matrix.md). The separate
[hosted continuity platform contract](hosted_continuity_platform_contract.md)
uses delegated `x-ms-user-identity` in the platform pivot merged by PR #633, but
remains disabled pending live evidence and
`HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED`. Hosted-panel is explicitly
selectable, but its user-history and operator surfaces remain off/503 behind
independent gates.
[GitHub Repository](https://github.com/Azure/gpt-rag-orchestrator).

## Key Features

- **Strategy-Based Architecture:** Pluggable orchestration strategies selected via Azure App Configuration (`AGENT_STRATEGY`).
- **Context Retrieval:** Intelligent retrieval from Azure AI Search or Foundry IQ with citation support and conservative retrieval-needed triage for local MAF strategies.
- **Microsoft Agent Framework:** Built on the Microsoft Agent Framework.
- **Conversation Persistence:** The currently released classic Container Apps topology maintains conversation history in Cosmos DB. In the hosted component matrix, the UI BFF owns managed Conversations and sends complete ordered input to the stateless runtime. Hosted/no-panel has no Cosmos continuity store. Both chat paths stream responses over SSE.
- **Extensible Design:** Easy to add new strategies by extending `BaseAgentStrategy`.

## Available Strategies

The Orchestrator supports multiple strategies. The active strategy is set via the `AGENT_STRATEGY` key in Azure App Configuration. The default is `maf_lite`.

| Key | Strategy | Description |
|-----|----------|-------------|
| `maf_lite` | MAF Lite **(default)** | Microsoft Agent Framework with direct Azure OpenAI model access. Lightweight, no Agent Service dependency. Includes user profile memory and optional agentic search. |
| `maf_agent_service` | MAF + Agent Service | Microsoft Agent Framework with Azure AI Foundry Agent Service for server-side thread management and tool orchestration. Includes user profile memory and optional agentic search. |
| `single_agent_rag` | Single Agent RAG | Uses Azure AI Agents SDK with Agent Service for agentic RAG. Supports dynamic routing, streaming via event handlers, and pre-warming for low-latency first responses. |
| `mcp` | MCP | Model Context Protocol strategy using Semantic Kernel. Connects to an MCP server for tool orchestration and passes user context via HTTP headers. |
| `nl2sql` | NL2SQL | Natural language to SQL translation using Microsoft Agent Framework `ChatAgent` with local metadata lookup, SQL validation, and query execution. No Semantic Kernel or Agent Service agent creation is used in this path. |

## Streaming outcomes

An HTTP response starting successfully, or some answer text arriving, does not
prove that a streamed turn completed successfully. When a failure reaches the
classic `POST /orchestrator` stream boundary, the existing terminal SSE event is
`event: error` with `data: An internal server error occurred.`. Earlier partial
output does not turn that failure into a successful answer. Cancellation is a
separate outcome, not a generic internal error. This classic wire format does
not replace the separate [hosted Responses contract](hosted_agent_release_matrix.md#stateless-hosted-runtime-contract).

The [audit failure semantics](governance_audit_contract_v1.md#failure-semantics-and-evidence-gaps)
describe what reaches the instrumented request boundary; a normal completion
event is not independent proof that every operation inside a strategy succeeded.

!!! warning "Unmerged primary-failure corrections"
    At the recorded [Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346)
    checkpoint [`f06d0cd`](https://github.com/Azure/gpt-rag-orchestrator/commit/f06d0cd7204c63e61ce1b6c80ae768c5f7f0597c),
    `maf_lite` and `maf_agent_service` propagate primary failures instead of
    returning raw exception details as ordinary assistant text. The existing
    `TurnErrorEvent`, `outcome.rejected` and `request.failed` path now observes
    those failures before or after partial output, without changing the wire
    format, schemas or distinct cancellation behavior.

    Checkpoint [`2dc6928`](https://github.com/Azure/gpt-rag-orchestrator/commit/2dc69285efa3d6bffb661e05e69797f54e1be45c)
    extends this correction to thrown primary failures in `nl2sql` and
    `multimodal`. NL2SQL's explicit typed validation and execution-result
    answers remain completed answers, distinct from thrown failures.
    The unmerged P6 follow-up
    [`03e908d`](https://github.com/Azure/gpt-rag-orchestrator/commit/03e908d23d770c16c8ea8a94a5c268c561afa2b2)
    preserves these ordinary answers while adding optional schema errors:
    unavailable schemas are supplied separately from usable schemas, including
    valid empty columns. SQL cursor/connection cleanup attempts both returned
    resources without letting ordinary close failures replace the primary typed
    result or propagating cancellation. This is not worker-thread cancellation
    redesign or a guarantee for resources never returned by acquisition.
    See the [NL2SQL quickstart](quickstart_nl2sql.md) for the scoped, unmerged
    behavior; no exception approval or new terminal policy is implied.
    Multimodal still buffers the model answer for image deduplication and
    optional validation before emission; its welcome prefix can arrive earlier.
    Buffered content is not emitted partial output. The added real-chain
    regressions distinguish these paths, cancellation and successful history
    from a failed turn, without adding raw error text to completed answer history.

    The SSE boundary logs a constant diagnostic without a traceback. The
    enclosing orchestration span disables automatic exception events and
    exception-derived status descriptions, then explicitly records
    `ERROR` / `internal_error` for primary failure. The checkpoint's real-chain
    MAF tests cover both strategies' success, early/partial failure, client
    initialization failure and cancellation, including an in-memory SDK span
    exporter. This is bounded application-owned evidence, not a guarantee
    about every third-party span, legacy log or live integration.

    This observable failure-path correction is coordinated in
    [#689](https://github.com/Azure/GPT-RAG/pull/689) and is not released behavior
    or full quality/exception approval. Separate optional profile, search,
    intent and context-provider contracts are not made universally fatal.

!!! warning "Unmerged required-retrieval failure correction"
    The scoped follow-up to orchestrator
    [#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346), at
    [`2f0f860`](https://github.com/Azure/gpt-rag-orchestrator/commit/2f0f860c652916edd020e08f969e211f52a221f6),
    changes configured retrieval failures in `maf_lite`, `maf_agent_service`
    and `multimodal`: provider construction and Search/Foundry retrieval
    failures interrupt the turn rather than producing an ordinary ungrounded
    answer. The composite context provider propagates required retrieval
    failures even when optional sibling context is available. The existing
    failed-turn audit and generic classic SSE error contract apply; raw
    provider errors are not returned as answer text. Cancellation remains
    cancellation.

    Successful retrieval with zero matches is still a normal result. These
    strategies retain their existing no-provider path when
    `SEARCH_SERVICE_QUERY_ENDPOINT` or `SEARCH_RAG_INDEX_NAME` is absent;
    this includes the existing construction guard on the Foundry backend.
    Lite and multimodal greeting/no-retrieval intents skip both provider
    initialization and retrieval. No new degraded-mode flag is introduced,
    and `SEARCH_RETRIEVAL_ENABLED` is not newly applied to these strategies.
    Optional memory, image enrichment and keyword fallback remain separate
    contracts. This follow-up remains unmerged, not released behavior
    or activation of any exception approval.

    Foundry credential failure still prevents that client's retrieve request,
    and failed HTTP retrieval does not expose its response body.
    [Retained identity fallbacks](howto_authentication.md#classic-container-apps-token-flow)
    are not new permission approval or strict OBO enforcement.

## Retrieval backend

The orchestrator reads `RETRIEVAL_BACKEND` at startup:

| Value | Behavior |
| --- | --- |
| `foundry_iq` | Uses a Foundry IQ knowledge base. This is the default for new GPT-RAG v3.0.2+ deployments with AI Landing Zone v2.1.2+. See [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md) for setup, security modes, and billing. |
| `ai_search` | Uses the GPT-RAG Azure AI Search index directly. Existing deployments can keep it until they migrate. It also remains the rollback and compatibility path. |

`maf_lite`, `maf_agent_service`, `single_agent_rag`, and `multimodal` are the
RAG strategies affected by the backend selector. `mcp` and `nl2sql` do not use
the GPT-RAG retrieval backend.

On `foundry_iq`, the Knowledge Base can also register optional additive
Knowledge Sources next to the documents source: [Work IQ](howto_grounding_work_iq.md)
for Microsoft 365 context, [Fabric ontology](howto_grounding_fabric_ontology.md)
for Microsoft Fabric analytical data, and
[Fabric Data Agent](howto_grounding_fabric_data_agent.md) for handing
questions off to a curated Fabric virtual analyst. All are off by default
and require a signed-in user.

!!! warning "Unmerged citation-signing failure clarification"
    At checkpoint [`ff1bb43`](https://github.com/Azure/gpt-rag-orchestrator/commit/ff1bb43f4fcd0e7d9c9e12efae0d75517b62221c),
    optional Blob citation signing preserves the original link when configuration
    or signing fails, including a URL parse failure. An unchanged link is not
    evidence that it is valid, signed or accessible. This fallback does not make
    a failed primary retrieval successful. The helper's failure diagnostics omit
    raw exception details and blob names; cancellation still propagates.
    Same-account, read-only signing and existing expiry/cache rules are unchanged.
    This is an unmerged correction with offline evidence, not a live access
    guarantee or approval of the two proposed exceptions.

## Conversation History and Retrieval Controls

In the currently released classic Container Apps topology, long-running chats
are handled in two places. The model prompt receives only a recent history
window, while the Cosmos DB conversation document is compacted before
persistence so it keeps useful recent context without growing indefinitely.
In the hosted component matrix, UI `v2.6.2` owns managed-Conversation lifecycle
and orchestrator `v4.1.1` is stateless. User-facing list/read/feedback/delete
routes exist in the UI component, but umbrella panel gates remain off. The default
`maf_lite` strategy and the `multimodal` strategy also classify each turn as a
greeting, retrieval-needed question, or no-retrieval follow-up. Transformations
such as "format that answer as a table" or "translate the previous answer" can
skip Azure AI Search while still using the recent chat history.

!!! warning "Unmerged retry and persistence evidence"
    The [`6b652d8`](https://github.com/Azure/gpt-rag-orchestrator/commit/6b652d8c4d664863a3d02d439b7b77210963320d)
    candidate preserves the one-shot invalid-payload retry only before output,
    with the original input, thread and `store=False` option. Ambiguous managed
    writes are reconciled against the exact two-message tail, not retried;
    this is not an idempotency or rollback guarantee. Hosted requests still
    perform no managed-Conversation operations.

    The P2 follow-up [`c9a74f9`](https://github.com/Azure/gpt-rag-orchestrator/commit/c9a74f9e8bc500c183f54e2f7540146770503452)
    narrows that retry: `max_tokens` must be supplied and the invalid-payload
    diagnostic must specifically reject `max_tokens` or its wire name
    `max_output_tokens` as "Not allowed when agent is specified". Ambiguous
    diagnostics, other-option rejections and any emitted chunk (including
    metadata-only output) propagate without replay. At most one retry removes
    only `max_tokens`; input, thread and all other options remain unchanged.
    Controlled managed/hosted caller tests are not live provider acceptance.

    Classic detached Cosmos persistence can fail after answer emission.
    A bounded background-error diagnostic is not a durable-completion receipt.
    Optional feedback question correlation can fail independently of feedback
    saving; it does not redefine history ownership or authorize new storage.
    These retained outcomes remain inactive exception proposals, not guarantees
    of persistence or recovery.

| App Configuration key | Default | Purpose |
|-----------------------|---------|---------|
| `CHAT_HISTORY_MAX_MESSAGES` | `10` | Recent messages sent to the response model. |
| `CONVERSATION_HISTORY_COMPACTION_ENABLED` | `true` | Enables compaction before saving a conversation document to Cosmos DB. |
| `CONVERSATION_HISTORY_MAX_PERSISTED_MESSAGES` | `200` | Maximum recent messages kept in the persisted conversation document. |
| `CONVERSATION_HISTORY_MAX_BYTES` | `1500000` | Serialized size target for the persisted conversation document. |
| `HOSTED_HISTORY_MAX_ITEMS` | `100` | Maximum managed history items supplied to the compatible hosted contract; accepted range 1-1,000. |
| `HOSTED_HISTORY_MAX_TOKENS` | `32000` | Token budget for managed hosted history; accepted range 1-1,000,000. |
| `HOSTED_HISTORY_TRUNCATION` | `drop_oldest` | The only accepted hosted overflow behavior. |
| `RETRIEVAL_INTENT_HISTORY_MESSAGES` | `4` | Recent messages sent only to the retrieval-needed classifier. |
| `RETRIEVAL_INTENT_HISTORY_MAX_CHARS` | `4000` | Character budget for classifier history. |
| `ENABLE_NO_RETRIEVAL_FOLLOWUP_DETECTION` | `true` | Allows no-retrieval follow-ups to skip Azure AI Search; ambiguous turns still retrieve. |

The hosted limits are inactive while `HOSTED_CONTINUITY_ENABLED=false`. When a
compatible component set is validated, the trusted UI BFF will derive
`x-ms-user-identity` for Responses protocol `2.0.0`. That owner header is
distinct from OBO retrieval. The hosted runtime is not an identity-header
source and receives no key, Conversation or impersonation RBAC, or Cosmos DB in
hosted/no-panel. Capability/HMAC remains a disabled fallback only.

### Hosted `v4.1.1` request contract

Hosted `POST /responses` rejects top-level `conversation` and
`previous_response_id` with HTTP 422. The caller must send the complete bounded,
oldest-to-newest text history as `input` for every turn. A plain non-empty string
is valid for one turn; a message array must be non-empty and end in a non-empty
user message. The runtime constructs no managed-Conversations client and
performs no create, read, append, or delete operation.

`POST /invocations` remains a distinct compatibility contract. Its opaque
`conversation_id` is only echoed and used for local retrieval scoping; it is not
managed state or authorization. UI `v2.6.2` currently replays complete ordered
messages through this compatibility path. See
[Stateless hosted runtime contract](hosted_agent_release_matrix.md#stateless-hosted-runtime-contract).

## Visual Guide

New to the Orchestrator? Check out the [Orchestrator Visual Guide](orchestrator_visual_guide.md) for a visual walkthrough of the architecture and key components.

## Repository

🔗 [GitHub Repository](https://github.com/Azure/gpt-rag-orchestrator)
