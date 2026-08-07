# Hosted-agent component release matrix

This page records the exact hosted-agent component releases published on
2026-08-07 and the integration boundary that still applies to the GPT-RAG
umbrella deployment.

!!! warning "Components are published; there is no integrated umbrella release"
    The four releases below exist, but GPT-RAG has not published an umbrella
    release that pins and validates them together. The current `develop`
    manifest still references UI `v2.5.1`, orchestrator `v3.10.0`, ingestion
    `v2.6.0`, and an AILZ development commit. Keep the released GPT-RAG
    deployment on its documented classic topology. Do not infer that installing
    these four tags independently is a supported production upgrade.

## Exact published matrix

| Component | Release | Reviewed release commit | Relevant contract |
| --- | --- | --- | --- |
| GPT-RAG UI | [`v2.6.0`](https://github.com/Azure/gpt-rag-ui/releases/tag/v2.6.0) | [`81d6515`](https://github.com/Azure/gpt-rag-ui/commit/81d6515d8fc365402e958e861b671af037a4cc75) | Hosted/no-panel is the fresh UI default when `CHAT_BACKEND` is absent; continuity and panel surfaces remain opt-in and fail closed. |
| GPT-RAG orchestrator | [`v4.0.0`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v4.0.0) | [`1033d06`](https://github.com/Azure/gpt-rag-orchestrator/commit/1033d0690736f9787e5f227559dc4071d2043b79) | Canonical hosted `/responses` is stateless and requires caller-supplied ordered input. |
| GPT-RAG ingestion | [`v2.7.0`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.7.0) | [`84b9277`](https://github.com/Azure/gpt-rag-ingestion/commit/84b927769ef0839110f2d68e3ca471e2260567cf) | Metadata-only operator overview and document/corpus curation APIs. |
| AI Landing Zone | [`v2.5.0`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.5.0) | [`cacf418`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/commit/cacf418216ce7381d06263e0dd704a86b8a6f225) | Two-phase hosted-agent prerequisite/handoff support; both hosted flags default to `false`. |

The matrix implements the component portions of
[ADR-0003](https://github.com/Azure/GPT-RAG/blob/develop/docs/adr/ADR-0003-hosted-conversation-continuity.md)
and
[ADR-0004](https://github.com/Azure/GPT-RAG/blob/develop/docs/adr/ADR-0004-hosted-panel-conversations-contract.md).
It does not close their umbrella rollout and evidence gates.

## Modes and defaults

| Surface | Current behavior |
| --- | --- |
| Published GPT-RAG umbrella release | Classic Container Apps topology. |
| Fresh UI `v2.6.0` process with no `CHAT_BACKEND` value | Selects `hosted_agent`; invalid or incomplete hosted configuration fails startup. |
| Existing umbrella deployment | Its persisted topology is sticky. An unmarked pre-cutover deployment stays `classic`. |
| `DEPLOYMENT_TOPOLOGY=classic` | Explicit supported fallback; deploys UI, orchestrator, and ingestion Container Apps. |
| `DEPLOYMENT_TOPOLOGY=hosted-no-panel` | Implemented on `develop`, but not published as an integrated umbrella release. UI and ingestion remain in Container Apps; chat uses the hosted agent; no panel Cosmos containers are selected. |
| `DEPLOYMENT_TOPOLOGY=hosted-panel` | Platform selection still fails closed. Component endpoints exist, but the umbrella forces panel evidence flags off and does not publish this topology. |
| `HOSTED_CONTINUITY_ENABLED` | `false`. The platform publisher force-seeds it to `false`. |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated` when continuity is enabled; `capability` is an explicit fallback only. |
| `PANEL_HISTORY_ENABLED` / `PANEL_OPERATOR_SURFACES_ENABLED` | `false`; operator enablement is not part of the current umbrella release. |
| AILZ `PREPARE_HOSTED_AGENT` / `deployHostedAgent` | Both default to `false`. `deployHostedAgent=true` requires an immutable `sha256:` image digest. |

The platform contract publishes hosted history limits of 100 items and 32,000
estimated tokens with `drop_oldest`. UI `v2.6.0` has standalone code defaults of
40 items and 8,000 tokens when those App Configuration values are absent.
An integrated release must publish one reviewed set; operators must not assume
the UI fallback values equal the pending umbrella values.

## Stateless hosted runtime contract

Orchestrator `v4.0.0` performs no managed-Conversations create, read, append, or
delete operation in the hosted container. The caller supplies the complete,
bounded, oldest-to-newest history on every request.

For canonical `POST /responses`:

- `input` may be a non-empty string for a single turn or a non-empty ordered
  array of text-only `{role, content}` messages;
- an array must end in a non-empty `user` message;
- top-level `conversation` and `previous_response_id` are unsupported and each
  returns HTTP 422;
- there is no server fallback or deprecation path that reconstructs history;
- the runtime builds only local, ephemeral strategy state and disables
  model-side storage for the generation call; and
- classic non-hosted `/responses` behavior is unchanged.

```json
{
  "input": [
    {"role": "user", "content": "What is the retention period?"},
    {"role": "assistant", "content": "The policy states 30 days."},
    {"role": "user", "content": "Who approves an exception?"}
  ],
  "stream": true,
  "store": false
}
```

`POST /invocations` remains a distinct compatibility protocol. Its
`conversation_id` is only an opaque label for response tagging and
conversation-scoped retrieval; it does not authorize or select a managed
Conversation. UI `v2.6.0` currently sends complete ordered messages through
this compatibility route. An integrated umbrella cutover must explicitly align
the UI call route with the protocol and role evidence it validates.

## Delegated owner binding

The trusted UI BFF owns managed-Conversation lifecycle. For every create, read,
append, or delete in delegated mode, it:

1. validates the signed-in user's Entra token;
2. normalizes the validated `oid`;
3. acquires its own service-identity Foundry token; and
4. derives `x-ms-user-identity` only from that server-side `oid`.

The browser cannot submit or override the owner header. The hosted runtime is
not an identity-header source and receives no managed-Conversations RBAC.

The owner header is not an OAuth On-Behalf-Of token. OBO is used only for
downstream retrieval authorization, such as Toolbox passing a user bearer to
Foundry IQ or Azure AI Search for native permission trimming. Owner binding and
retrieval authorization have different audiences and must not be substituted.

### Protocol and RBAC evidence gate

UI `v2.6.0` accepts an attested Responses protocol version `>= 2.0.0`. The
pending GPT-RAG platform validator is deliberately stricter: it requires the
live endpoint to route 100% to one agent version declaring exactly one
Responses `2.0.0` protocol entry.

The same validator requires exactly these direct assignments to the UI BFF:

| Role | Required permission |
| --- | --- |
| Built-in **Foundry Agent Consumer** (`eed3b665-ab3a-47b6-8f48-c9382fb1dad6`) | Exactly `Microsoft.CognitiveServices/accounts/AIServices/endpoints/interact/action` in `DataActions`, with no control-plane actions. |
| Custom **GPT-RAG Hosted Agent User Identity Impersonation** (`bef66abe-a495-530a-be1d-5d882fecff03`) | Exactly `Microsoft.CognitiveServices/accounts/AIServices/agents/endpoints/UserIdentityImpersonation/action`, with no other actions or exclusions. |

Both assignments must be direct `ServicePrincipal` assignments at the
individual agent resource:

```text
/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/
accounts/<account>/projects/<project>/agents/<agent>
```

The custom role definition is assignable only within the hosted-agent resource
group. Project-, account-, resource-group-, subscription-, inherited-,
group-derived-, wildcard-, custom-equivalent-, or extra-DataAction assignments
do not satisfy the gate. **Foundry User** and **Project Runtime User** are not
substitutes.

If protocol, role definition, principal type, assignment scope, or identity
source cannot be proven, `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` remains
`false`, continuity remains off, and compatible continuity/history operations
fail closed with HTTP 503.

## Opaque handle failures

A genuinely absent handle starts a new conversation. A presented handle that is
foreign, stale, deleted, malformed, forged, expired, signed by a retired key, or
bound to another `oid` produces one opaque not-found result.

The BFF must not create a replacement conversation, invoke the hosted agent, or
append a turn after such a failure. This prevents a success-shaped new chat from
becoming an ownership or existence oracle. Transport and dependency failures
remain explicit 5xx failures; they are not converted to not-found.

## User panel surfaces

UI `v2.6.0` includes owner-gated endpoints for:

| Endpoint | Behavior |
| --- | --- |
| `GET /panel/conversations` | Lists metadata for only the caller's owner-index rows, using an opaque signed, expiring, `oid`-bound cursor. |
| `GET /panel/conversations/{id}/messages` | Checks ownership before reading ordered content live from managed Conversations. |
| `POST /panel/conversations/{id}/feedback` / `GET /panel/conversations/{id}/feedback` | Stores and reads bounded metadata-only rating, category, comment, and message reference. |
| `DELETE /panel/conversations/{id}` | Deletes the managed Conversation first, then panel metadata. Metadata cleanup failure returns `partial`, not a false success. |

Missing and non-owner resources both return 404. Invalid or cross-user cursors
return 422. Missing/invalid delegated tokens return 401; app-only tokens return
403. Downstream store failure returns 502. Undeployed or disabled user panel
surfaces return 503.

## Operator overview and corpus curation

Ingestion `v2.7.0` includes:

- `GET /panel/overview/metrics`;
- `GET /panel/corpus-curation/queue`; and
- `POST /panel/corpus-curation/{item_id}/decision`.

Overview reads aggregate counts only from the panel owner-index and feedback
metadata containers. Any bucket below `PANEL_OVERVIEW_MIN_CARDINALITY` (default
`5`) is returned as `null`, not as a small exact count.

Corpus curation covers documents already handled by ingestion. The queue uses
the existing per-file-log Blob store, and `approve`, `reject`, or `defer`
decisions use the Blob's ETag for optimistic concurrency. It does not curate or
read conversation content and does not write curation decisions to Cosmos.

Operator endpoints require:

- `DEPLOY_ADMINISTRATIVE_PANEL=true`;
- `PANEL_OPERATOR_SURFACES_ENABLED=true`;
- an explicit `PANEL_OPERATOR_APP_ROLE` or `PANEL_OPERATOR_GROUP_ID`; and
- a validated delegated user bearer carrying that role or group.

App-only tokens are rejected. The current umbrella publisher forces
`PANEL_OPERATOR_SURFACES_ENABLED=false`, so these APIs are component capability,
not an enabled umbrella feature.

!!! important "Released ingestion dashboard browser-auth status"
    The ingestion `v2.7.0` Vite dashboard does not initialize MSAL, acquire an
    access token, or add an `Authorization` header for the new operator panel
    requests. Its `panelFetch` uses plain browser `fetch`. The Overview and
    Curation tabs therefore show the backend's real 401/403/503 response unless
    an approved same-origin reverse-auth proxy adds the delegated operator
    bearer. This differs from the classic orchestrator dashboard, whose SPA has
    a working MSAL Authorization Code + PKCE flow.

## Data confinement

Managed Conversations is the only chat-content store for the hosted design.

- Hosted/no-panel provisions no panel Cosmos containers and has no Cosmos
  continuity fallback.
- Hosted/panel, when a future umbrella release enables it, uses only
  `panel-conversation-owner-index` and `panel-feedback`, partitioned by
  `/principal_id`.
- Cosmos may contain identifiers, titles, timestamps, principal IDs, ratings,
  category codes, bounded comments, and message references.
- Cosmos must never contain message bodies, citations, retrieved document
  content, or corpus document content.
- The hosted runtime identity has no Conversations role, impersonation role,
  capability key, or panel Cosmos role.

## Operator verification and rollback

There is currently no supported umbrella command sequence that enables this
matrix. The platform intentionally force-publishes continuity and operator
evidence flags as `false`. Before a future umbrella release enables them,
release validation must:

1. pin all four exact releases together;
2. deploy the immutable hosted image and verify the live Responses protocol;
3. verify the two exact direct UI BFF role assignments at individual-agent
   scope and reject broader or extra access;
4. verify browser-supplied owner headers are ignored and the BFF derives only
   the validated `oid`;
5. run two-user negative tests for cross-user read, continuation, history,
   feedback, and delete;
6. prove the runtime performs zero managed-Conversations operations and
   hosted/no-panel constructs no Cosmos client;
7. inject read/append failures and prove they cannot produce a success-shaped
   new conversation;
8. validate Basic and network-isolated deployments; and
9. separately validate panel user auth and the ingestion browser operator-token
   path before enabling panel flags.

The pending configuration contract uses:

| Key | Required value or default |
| --- | --- |
| `HOSTED_CONTINUITY_ENABLED` | `false` until all evidence passes |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated`; explicit fallback `capability` |
| `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` | `false` until protocol and RBAC validation |
| `HOSTED_CONVERSATION_DELEGATED_IDENTITY_HEADER` | `x-ms-user-identity` |
| `HOSTED_CONVERSATION_DELEGATED_IDENTITY_SOURCE` | `authenticated_ui_bff_principal` |
| `HOSTED_AGENT_RESPONSES_PROTOCOL_VERSION` | platform contract: exactly `2.0.0` |
| `HOSTED_AGENT_PROTOCOL_VERSION` | UI `v2.6.0` continuity attestation: `>=2.0.0`; the pending integration must reconcile/publish both names consistently |
| `HOSTED_CONTINUITY_UNAVAILABLE_STATUS_CODE` | `503` |
| `HOSTED_HISTORY_MAX_ITEMS` / `HOSTED_HISTORY_MAX_TOKENS` | pending umbrella defaults `100` / `32000` |
| `HOSTED_HISTORY_TRUNCATION` | `drop_oldest` |
| `PANEL_HISTORY_ENABLED` / `PANEL_OPERATOR_SURFACES_ENABLED` | `false` |
| `PANEL_CONVERSATION_ENUMERATION_MODE` | `owner_index` |
| `PANEL_CURSOR_TTL_SECONDS` / `PANEL_OVERVIEW_MIN_CARDINALITY` | `600` / `5` |

Rollback is a deployment/configuration operation, never a request-time retry:

1. set `HOSTED_CONTINUITY_ENABLED=false`;
2. select `DEPLOYMENT_TOPOLOGY=classic` and `CHAT_BACKEND=orchestrator`;
3. re-provision and redeploy the manifest-pinned classic components;
4. remove the UI BFF's exact agent-scoped Consumer and impersonation
   assignments; and
5. disable panel flags before removing panel-only metadata containers.

Managed Conversations remains the system of record, so rollback does not
require copying chat content into Cosmos. Panel owner-index and feedback rows
are metadata and may be retained or removed under the deployment's retention
policy.
