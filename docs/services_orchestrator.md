# 🎯 Orchestrator

!!! note "Develop adoption, not a release"
    [Adoption status and approval scope](contributing.md#develop-adoption-status)
    supersede the historical “unmerged” and pending-exception labels below.
    Source pins remain implementation evidence; released manifest pins are unchanged.
    See that record for active rules, reference runs and remaining validation gaps.

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

!!! warning "Unmerged candidate: operator compatibility and recovery"
    The candidate guidance on this page is pinned to orchestrator
    [`ea61bc7cd7b2ac21c957bee5db959337fedd8760`](https://github.com/Azure/gpt-rag-orchestrator/commit/ea61bc7cd7b2ac21c957bee5db959337fedd8760)
    in [PR #346](https://github.com/Azure/gpt-rag-orchestrator/pull/346), including
    the [`25f1986..ea61bc7` diff](https://github.com/Azure/gpt-rag-orchestrator/compare/25f1986...ea61bc7)
    implementing [parent ADR-0006](https://github.com/Azure/GPT-RAG/blob/feature/python-module-boundaries/docs/adr/ADR-0006-orchestrator-retrieval-profile-and-history-failure-policy.md).
    It is **unmerged, not shipped** and does not change release pins or deployment gates.
    Required-user retrieval that previously continued without delegated authorization
    now fails; automatic profile access and collection are entirely suspended.
    Ordinary conversation history remains best effort, not durable on SSE completion.
    Before adoption, validate the exact UI/ingestion/infrastructure combination.
    Recover by fixing token forwarding, consent and source configuration, not by
    stripping authorization or enabling anonymous access. Prefer a forward fix or
    operationally disable affected retrieval routes; rollback to `25f1986` restores
    permissive paths and is not a safe security remedy. No data migration or
    deletion is performed. See [retrieval policy](#candidate-retrieval-authorization)
    and [API-key recovery](howto_authentication.md#legacy-api-key-recovery-h1).

- **Strategy-Based Architecture:** Pluggable orchestration strategies selected via Azure App Configuration (`AGENT_STRATEGY`).
- **Context Retrieval:** Intelligent retrieval from Azure AI Search or Foundry IQ with citation support and conservative retrieval-needed triage for local MAF strategies.
- **Microsoft Agent Framework:** Built on the Microsoft Agent Framework.
- **Conversation Persistence:** The currently released classic Container Apps topology maintains conversation history in Cosmos DB. In the hosted component matrix, the UI BFF owns managed Conversations and sends complete ordered input to the stateless runtime. Hosted/no-panel has no Cosmos continuity store. Both chat paths stream responses over SSE.
- **Extensible Design:** Easy to add new strategies by extending `BaseAgentStrategy`.

## Available Strategies

The Orchestrator supports multiple strategies. The active strategy is set via the `AGENT_STRATEGY` key in Azure App Configuration. The default is `maf_lite`.

| Key | Strategy | Description |
|-----|----------|-------------|
| `maf_lite` | MAF Lite **(default)** | Microsoft Agent Framework with direct Azure OpenAI model access. Lightweight, no Agent Service dependency. Conversation context and optional agentic search; candidate automatic profiles are suspended (below). |
| `maf_agent_service` | MAF + Agent Service | Microsoft Agent Framework with Azure AI Foundry Agent Service for server-side thread management and tool orchestration. Conversation context and optional agentic search; candidate automatic profiles are suspended (below). |
| `single_agent_rag` | Single Agent RAG | Uses Azure AI Agents SDK with Agent Service for agentic RAG. Supports dynamic routing, streaming via event handlers, and pre-warming for low-latency first responses. |
| `mcp` | MCP | Model Context Protocol strategy using Semantic Kernel. Connects to an MCP server for tool orchestration and passes user context via HTTP headers. |
| `nl2sql` | NL2SQL | Natural language to SQL translation using Microsoft Agent Framework `ChatAgent` with local metadata lookup, SQL validation, and query execution. No Semantic Kernel or Agent Service agent creation is used in this path. |

## Optional profile memory

!!! warning "Unmerged: automatic profiles completely suspended"
    At `ea61bc7` (pinned above), `maf_lite`, `maf_agent_service` and `multimodal`
    perform no automatic profile Cosmos reads/writes, extraction model calls,
    extraction tasks or profile mutations, even for syntactically valid legacy
    keys. Cached profile context is cleared; no profile welcome or personalization
    is supplied. Hosted profile memory remains disabled and multimodal hosted
    eligibility is unchanged. This supersedes the earlier `80d8fb2` negative-key
    eligibility check and earlier extraction-worker/adapter guidance.

    Legacy owner keys have no verified trusted identity binding. Neither a
    request-body identity nor substitution of classic `principal_id` for
    `user_id` establishes ownership. Existing records are left untouched:
    **no rekeying, migration, backfill or data deletion**. Do not repair the old
    extraction adapter or insert keys to reactivate collection. Restoration
    requires a separately reviewed, proven owner binding and privacy decision.
    Perfect model-returned profile JSON is irrelevant: the extraction model is
    not called. Ordinary chat/model calls and recent conversation context continue.

    MAF and multimodal prompt templates in this candidate, plus MAF
    fallback prompts, explicitly prohibit claims to learn, save or recall a
    persistent profile. Review operator-customized prompts for conflicting
    personalization promises. This is suspension, not a persistence fix.

## Candidate retrieval authorization

At the unmerged `ea61bc7` pin, the maintained MAF Lite, MAF Agent Service and
multimodal provider factories explicitly select the following internal modes.
These are not new App Configuration settings:

| Mode | Selection and behavior |
| --- | --- |
| `user_required` | A nonblank request assertion, `ALLOW_ANONYMOUS=false`, or a user-only source requires delegated authorization. Missing callback, missing/blank token, failed OBO or rejected retrieval fails the turn, with no application-identity fallback or alternate unfiltered query. |
| `service_only` | No user assertion, `ALLOW_ANONYMOUS=true`, and no source requiring a user. Existing service-identity access remains, within the source's app-only permissions; it does not impersonate a user. |

Search, multimodal Search and Foundry IQ providers default to `user_required`
when constructed directly; custom callers must explicitly classify legitimate
service-only access. Foundry IQ additionally requires a user for enabled Work IQ,
Fabric ontology, Fabric Data Agent, SharePoint remote, and configured MCP
query headers whose `valueFrom.kind` is `obo`. Mixed-source retrieval must not
silently drop a user-only member and answer from local documents. This applies
to MCP and non-MCP provider paths. `ALLOW_ANONYMOUS=true` is not a bypass for
requests carrying a user assertion or user-only sources.

The multimodal retry that removed `x-ms-query-source-authorization` after a
failed search is removed. Token/context setter failures propagate rather than
continuing with stale context; provider callbacks capture the request token.
Successful zero-match retrieval and existing no-provider/no-retrieval-intent
paths remain distinct from failure. Existing authenticated 401/403 boundaries
and generic classic SSE error framing remain; after streaming starts, partial
output is not success and cancellation stays cancellation.

**No application fallback is enabled:** equivalent per-source ACL enforcement
and explicit user disclosure have not been proven. Token scopes, forwarded
headers, conversation filters and mocked tests do not prove live document ACLs.
Before deployment, test authorized and unauthorized principals against every
source, including protected text, citations and images. Restore trusted token
forwarding, audiences, consent and permission metadata/configuration; do not
weaken `ALLOW_ANONYMOUS`, strip headers or switch identities as recovery.

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
    The later [candidate retrieval policy](#candidate-retrieval-authorization)
    supersedes the retained identity fallbacks at this earlier checkpoint.

!!! warning "Unmerged single-agent request-context correction"
    At [`80d8fb2`](https://github.com/Azure/gpt-rag-orchestrator/commit/80d8fb212088dfea2249d53593b9e1dca2f37967),
    the `single_agent_rag` bound Search tool propagates failure to apply its
    existing request context instead of searching with stale or unapplied
    context. The existing failed-turn/SSE error contract applies even after
    partial output; cancellation remains cancellation. Successful conversation
    scoping and disabled-retrieval behavior are unchanged. Token selection,
    `ALLOW_ANONYMOUS` and OBO/service-identity fallbacks were not changed by
    that checkpoint; see the later, scoped [candidate policy](#candidate-retrieval-authorization).

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
    with the original input, thread and `store=False` option. That checkpoint
    used text-only two-message reconciliation for ambiguous managed writes,
    superseded by the P5 correction below. Hosted requests still
    perform no managed-Conversation operations.

    The P2 follow-up [`c9a74f9`](https://github.com/Azure/gpt-rag-orchestrator/commit/c9a74f9e8bc500c183f54e2f7540146770503452)
    narrows that retry: `max_tokens` must be supplied and the invalid-payload
    diagnostic must specifically reject `max_tokens` or its wire name
    `max_output_tokens` as "Not allowed when agent is specified". Ambiguous
    diagnostics, other-option rejections and any emitted chunk (including
    metadata-only output) propagate without replay. At most one retry removes
    only `max_tokens`; input, thread and all other options remain unchanged.
    Controlled managed/hosted caller tests are not live provider acceptance.

    The P5 follow-up at
    [`6f89c39`](https://github.com/Azure/gpt-rag-orchestrator/commit/6f89c399f046a79f2f15e4d709c47864f33f7f8f)
    in [Azure/gpt-rag-orchestrator#346](https://github.com/Azure/gpt-rag-orchestrator/pull/346)
    confirms an ambiguous write only if the latest assistant item has the
    **actual ID submitted by that invocation**, as well as matching adjacent
    user/assistant roles and text. Old identical text, missing or rewritten
    IDs, concurrent tails and malformed lookup results remain unconfirmed.
    The write is not retried; unconfirmed reconciliation preserves the
    original write error. This is conservative SDK-backed evidence, not a
    live-service ID-retention, idempotency or rollback guarantee.

    Classic Cosmos writes now capture an independent snapshot before scheduling
    and retain task ownership until completion. A new conversation's update
    waits for its create result; failed, cancelled or unconfirmed creation
    cannot race the dependent update. A `None` write result is not logged as
    completed persistence. Final snapshot/scheduling failures and ordinary
    diagnostic-sink failures preserve the primary stream outcome; audit-context
    cleanup runs independently, including when new process-control exceptions
    propagate.

    Persistence is still detached and can fail after answer emission. There
    is no cross-request serialization, global pending-task bound, shutdown
    drain or durable queue. A completed SSE response or bounded diagnostic is
    not a durable-completion receipt. Parent ADR-0006 selects retention of this
    best-effort policy; `25f1986..ea61bc7` does not add durability machinery.
    Process loss can lose pending writes and concurrent writes can race.
    Restore Cosmos connectivity/permissions for future writes and monitor
    unconfirmed persistence; there is no automatic replay or recovery of lost
    history. A stronger guarantee needs separate design and approval.
    Optional feedback question correlation can fail independently of feedback
    saving; it does not redefine history ownership or authorize new storage.
    These retained outcomes were inactive exception proposals at the recorded
    checkpoint. Initial administrative acceptance is now recorded in the
    adoption status above; it does not guarantee persistence or recovery.

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
