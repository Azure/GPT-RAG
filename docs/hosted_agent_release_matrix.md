# Hosted-agent integration matrix

This page records the exact hosted-agent component releases pinned by the
GPT-RAG umbrella release [`v3.8.2`](https://github.com/Azure/GPT-RAG/releases/tag/v3.8.2)
and the independent evidence gates that remain fail closed.

!!! danger "Do not deploy `v3.8.0` or `v3.8.1`"
    Earlier revisions of this page pinned the matrix to `v3.8.1`. Neither
    `v3.8.0` nor `v3.8.1` reaches a running deployment: `v3.8.0` pins
    orchestrator `v4.1.0`, whose `frontend/` SPA build fails, and `v3.8.1`
    repairs that build but still pins ingestion `v2.7.1`, which crashes on boot
    after a successful image build. The matrix below is the `v3.8.2`
    combination, which deploys end to end.

!!! warning "Pins are shipped in umbrella `v3.8.2`; evidence gates remain fail closed"
    The umbrella `manifest.json` pins all four exact releases below and explicit
    `hosted-panel` topology selection is supported. The manifest's umbrella tag
    is `v3.8.2`; use only a GPT-RAG source or release that contains these pins
    rather than combining component tags independently.
    `HOSTED_CONTINUITY_ENABLED`, `PANEL_HISTORY_ENABLED`,
    `PANEL_HISTORY_OWNER_BINDING_VALIDATED`, and
    `PANEL_OPERATOR_SURFACES_ENABLED` remain deployment-published `false`.
    This documentation does not claim that their separate live evidence and
    authorization procedures have completed. A prior validation attempt saw
    the hosted agent version become active while session readiness returned
    HTTP 424; that crash was root-caused to a `gpt-rag-orchestrator` circular
    import and fixed in
    [orchestrator `v4.0.1`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v4.0.1).
    Readiness (item 1 of the evidence gate below) has since been re-run and
    passes under `NETWORK_ISOLATION=true` against the exact pins below: the
    hosted agent reaches active state, session readiness succeeds, and a
    grounded answer returns with its citation. These pins shipped as umbrella
    release [`v3.8.2`](https://github.com/Azure/GPT-RAG/releases/tag/v3.8.2).
    Evidence-gate items 2 through 8 and the `store` contract matrix have not
    been re-run; the four flags above remain deployment-published `false`.

## Exact integrated matrix

| Component | Release | Reviewed release commit | Relevant contract |
| --- | --- | --- | --- |
| GPT-RAG UI | [`v2.6.2`](https://github.com/Azure/gpt-rag-ui/releases/tag/v2.6.2) | [`f59cca9`](https://github.com/Azure/gpt-rag-ui/commit/f59cca919f0bc59631d7bba7f3e223dff3718244) | Hosted/no-panel is the fresh UI default when `CHAT_BACKEND` is absent; continuity and panel surfaces remain opt-in and fail closed. |
| GPT-RAG orchestrator | [`v4.1.1`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v4.1.1) | [`9b64a5b`](https://github.com/Azure/gpt-rag-orchestrator/commit/9b64a5b962067161cb55252c6e0917a2738ba984) | Canonical hosted `/responses` is stateless and requires caller-supplied ordered input. Fixes the `dependencies`/`connectors` circular import that crashed the hosted entrypoint on startup ([PR #311](https://github.com/Azure/gpt-rag-orchestrator/pull/311)), released in `v4.0.1`. Unconditionally forces `store: false` on every hosted `POST /responses` call and rejects `background: true` with HTTP 422 ([PR #313](https://github.com/Azure/gpt-rag-orchestrator/pull/313)), released in `v4.0.2`; see "Store false wire contract" below. `v4.1.0` inverts request-field validation from a strict allowlist to ignore-and-log with a minimal deny-list: only `previous_response_id` is rejected with HTTP 422, and every other field the adapter does not act on is dropped and logged. A strict allowlist turned each newly injected Foundry client field into a hosted-agent outage. `store` and `background` handling is unchanged. `v4.1.0` also suppresses spurious `opentelemetry.context.detach` error records emitted by third-party GenAI instrumentation. `v4.1.1` repairs the `frontend/` SPA build that the `Dockerfile` runs in its first stage: `v4.1.0` could not be built at all, so every clean deployment of umbrella `v3.8.0` failed at the orchestrator image build. Runtime behaviour is unchanged. |
| GPT-RAG ingestion | [`v2.7.2`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.7.2) | [`b9e5ac3`](https://github.com/Azure/gpt-rag-ingestion/commit/b9e5ac3b2b36810b8d720398c3b8bbffc5ba7f75) | Metadata-only operator overview and document/corpus curation APIs. Repairs the OpenTelemetry import that crashed `v2.7.1` at boot after a successful image build. |
| AI Landing Zone | [`v2.5.1`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.5.1) | [`9cc5859`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/commit/9cc5859af5c8ab3b31709c9e16e0db11a170a404) | Two-phase hosted-agent prerequisite/handoff support; both hosted flags default to `false`. Also allows the Foundry Agent Service's `agent365.svc.cloud.microsoft` observability endpoint through Azure Firewall under network isolation (`v2.5.1`, patch). |

The matrix implements the component portions of
[ADR-0003](https://github.com/Azure/GPT-RAG/blob/develop/docs/adr/ADR-0003-hosted-conversation-continuity.md)
and
[ADR-0004](https://github.com/Azure/GPT-RAG/blob/develop/docs/adr/ADR-0004-hosted-panel-conversations-contract.md).
It completes their coordinated pin and topology-composition step. It does not
close their independent live evidence and authorization gates.

## Modes and defaults

| Surface | Current behavior |
| --- | --- |
| Umbrella integration manifest | Pins the exact matrix above. Stamped as [`v3.8.2`](https://github.com/Azure/GPT-RAG/releases/tag/v3.8.2). |
| Fresh UI `v2.6.2` process with no `CHAT_BACKEND` value | Selects `hosted_agent`; invalid or incomplete hosted configuration fails startup. |
| Existing umbrella deployment | Its persisted topology is sticky. An unmarked pre-cutover deployment stays `classic`. |
| `DEPLOYMENT_TOPOLOGY=classic` | Explicit supported fallback; deploys UI, orchestrator, and ingestion Container Apps. |
| `DEPLOYMENT_TOPOLOGY=hosted-no-panel` | Fresh-deployment default. UI and ingestion remain in Container Apps; chat uses the hosted agent; no panel Cosmos containers are selected. |
| `DEPLOYMENT_TOPOLOGY=hosted-panel` | Explicit supported topology. Deploys UI and ingestion, omits the orchestrator Container App, and provisions only the owner-index and feedback metadata containers. User-history and operator routes still return 503 because their independent gates remain `false`. |
| `HOSTED_CONTINUITY_ENABLED` | `false`. The platform publisher force-seeds it to `false`. |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated` when continuity is enabled; `capability` is an explicit fallback only. |
| `PANEL_HISTORY_ENABLED` / `PANEL_HISTORY_OWNER_BINDING_VALIDATED` / `PANEL_OPERATOR_SURFACES_ENABLED` | Deployment-published `false`; topology support does not imply live surface enablement. |
| AILZ `PREPARE_HOSTED_AGENT` / `deployHostedAgent` | Both default to `false`. `deployHostedAgent=true` requires an immutable `sha256:` image digest. |

The platform contract publishes hosted history limits of 100 items and 32,000
estimated tokens with `drop_oldest`. UI `v2.6.2` has standalone code defaults of
40 items and 8,000 tokens when those App Configuration values are absent.
The umbrella publishes the reviewed 100/32,000 values; operators must not
remove them and then assume the UI fallback values are equivalent.

## Stateless hosted runtime contract

Orchestrator `v4.1.1` performs no managed-Conversations create, read, append, or
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
Conversation. UI `v2.6.2` currently sends complete ordered messages through
this compatibility route. An integrated umbrella cutover must explicitly align
the UI call route with the protocol and role evidence it validates.

## Store false wire contract

!!! warning "Gap fixed and pinned; live network-isolated re-run still pending"
    A prior exact-matrix live validation against a network-isolated deployment
    showed that `POST /responses` succeeded when the caller sent
    `store: false`, but an **omitted or `true`** `store` deterministically
    failed with a platform `storage_error`. Root cause: the pinned
    `azure-ai-agentserver-responses==2.0.0b1` host auto-activates its own
    network-bound Foundry storage provider whenever the process detects it is
    running as a hosted agent and no explicit `store` override is supplied —
    true of every real deployment — and only calls that provider when the
    **caller's** `store` is true (an omitted `store` defaults to `true` per the
    Responses contract). Orchestrator `v4.0.1`'s already-stateless design
    (previous section) hardcoded `store: False` only on the *separate, inner*
    call the hosted strategy makes to the model; it did not touch the
    *outer*, wire-level `store` field on the incoming request, which is the
    one the auto-activated provider reads.

    The fix that forces `store: False` unconditionally on every hosted
    `POST /responses` call — regardless of what a caller sends or omits, for
    both streaming and non-streaming requests, and rejecting
    `background: true` with HTTP 422 (it requires `store: true` in the pinned
    SDK) — merged as
    [orchestrator PR #313](https://github.com/Azure/gpt-rag-orchestrator/pull/313)
    and released as
    [`v4.0.2`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v4.0.2)
    (commit
    [`c653b3e`](https://github.com/Azure/gpt-rag-orchestrator/commit/c653b3ec0a553f55244e197f3be993ad33ffe02f),
    722 tests passing upstream). Umbrella release `v3.8.2` pins the successor
    commit `9b64a5b` (`v4.1.1`), which leaves `store` and `background`
    handling unchanged. **The store contract itself has not been
    re-validated.** A network-isolated run on these pins confirms readiness and
    a grounded answer, but does not exercise the field matrix. Do not describe
    the store contract as validated or safe under network isolation until the
    exact matrix (`store` unset / `true` / `false`, under
    `NETWORK_ISOLATION=true`, streaming and non-streaming) is re-run live
    against this pin and passes. This warning must remain until that re-run is
    recorded here.

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

UI `v2.6.2` accepts an attested Responses protocol version `>= 2.0.0`. The
GPT-RAG platform validator is deliberately stricter: it requires the
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

UI `v2.6.2` includes owner-gated endpoints for:

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

Ingestion `v2.7.2` includes:

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

App-only tokens are rejected. The umbrella publisher keeps
`PANEL_OPERATOR_SURFACES_ENABLED=false`, so an explicitly deployed
hosted-panel topology still returns 503 from these routes until the separate
operator evidence and authorization gate is completed.

!!! important "Released ingestion dashboard browser-auth status"
    The ingestion `v2.7.2` Vite dashboard does not initialize MSAL, acquire an
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
- Hosted-panel uses only
  `panel-conversation-owner-index` and `panel-feedback`, partitioned by
  `/principal_id`.
- Cosmos may contain identifiers, titles, timestamps, principal IDs, ratings,
  category codes, bounded comments, and message references.
- Cosmos must never contain message bodies, citations, retrieved document
  content, or corpus document content.
- The hosted runtime identity has no Conversations role, impersonation role,
  capability key, or panel Cosmos role.

### Deployment identity boundaries

- A private Azure AI Search deployment uses its explicit Search user-assigned
  identity. `postProvision` preserves `SEARCH_SERVICE_UAI_RESOURCE_ID` when
  already supplied or resolves it from the Search resource; it must not replace
  the value with an empty identity.
- Panel setup resolves exactly one managed-identity principal from each target
  Container App. Zero or multiple distinct principals fail setup rather than
  guessing.
- The frontend principal receives **Cosmos DB Built-in Data Contributor** and
  the ingestion principal receives **Cosmos DB Built-in Data Reader**, each
  scoped separately to only `panel-conversation-owner-index` and
  `panel-feedback`.
- Neither principal receives panel access at Cosmos account scope. Ingestion
  receives no panel write access, and the hosted agent receives no panel Cosmos
  role.

## Operator verification and rollback

The matrix and all three topologies are composed by the umbrella integration.
For an explicit hosted-panel deployment, select the topology before the first
provision:

```powershell
azd env set DEPLOYMENT_TOPOLOGY hosted-panel
azd env set HOSTED_AGENT_RESOURCE_SCOPE "api://<application-id>/.default"
azd env set HOSTED_CONTINUITY_ENABLED false
azd provision
pwsh scripts/prepareHostedDeployment.ps1
azd provision
azd deploy
```

On POSIX systems, use `scripts/prepareHostedDeployment.sh`. The first provision
creates hosted prerequisites and the two metadata containers. The preparation
step resolves an immutable image digest; the second provision materializes the
hosted handoff. UI and ingestion are deployed, but the orchestrator Container
App is omitted. Do not override the deployment-published panel or continuity
evidence flags: their routes intentionally remain off/503.

The generated `hosted-agent/azure.yaml` prebuilt-image path must retain:

```yaml
services:
  orchestrator-agent:
    host: azure.ai.agent
    language: docker
    docker:
      remoteBuild: true
```

Before the child project runs `azd deploy orchestrator-agent`, the pre-deploy
hook sets `AZD_AGENT_SKIP_ACR=true` alongside the immutable
`HOSTED_AGENT_IMAGE_VERSION`. These settings tell the `azure.ai.agent` host to
deploy the prepared digest without replacing the reviewed Docker service
contract or launching a second ACR build.

Before those independent live surfaces can be enabled, validation must:

1. deploy the immutable hosted image and verify the live Responses protocol;
2. verify the two exact direct UI BFF role assignments at individual-agent
   scope and reject broader or extra access;
3. verify browser-supplied owner headers are ignored and the BFF derives only
   the validated `oid`;
4. run two-user negative tests for cross-user read, continuation, history,
   feedback, and delete;
5. prove the runtime performs zero managed-Conversations operations and
   hosted/no-panel constructs no Cosmos client;
6. inject read/append failures and prove they cannot produce a success-shaped
   new conversation;
7. validate Basic and network-isolated deployments; and
8. separately validate panel user auth and the ingestion browser operator-token
   path before enabling panel flags.

The prior runtime attempt did not satisfy item 1: the agent version reached
active state, but session readiness returned HTTP 424. That specific crash
was root-caused to a `dependencies`/`connectors` circular import in the
hosted entrypoint (`src/api/hosted_entrypoint.py` imports `dependencies`
before anything else in the process has "warmed up" `connectors`, unlike
the classic entrypoint) and fixed in
[orchestrator `v4.0.1`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v4.0.1)
([PR #311](https://github.com/Azure/gpt-rag-orchestrator/pull/311)), whose
successor `v4.1.1` is pinned above. Item 1 has since been re-run against a
live, network-isolated deployment on those pins and passes: the agent version
reaches active state, session readiness succeeds, and a grounded answer
returns with its citation. Evidence steps 2 through 8 have not been re-run.
Preserve the fail-closed flags and do not describe those steps as validated
until each one succeeds.

The configuration contract uses:

| Key | Required value or default |
| --- | --- |
| `HOSTED_CONTINUITY_ENABLED` | `false` until all evidence passes |
| `HOSTED_CONVERSATION_OWNER_BINDING` | `delegated`; explicit fallback `capability` |
| `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` | `false` until protocol and RBAC validation |
| `HOSTED_CONVERSATION_DELEGATED_IDENTITY_HEADER` | `x-ms-user-identity` |
| `HOSTED_CONVERSATION_DELEGATED_IDENTITY_SOURCE` | `authenticated_ui_bff_principal` |
| `HOSTED_AGENT_RESPONSES_PROTOCOL_VERSION` | platform contract: exactly `2.0.0` |
| `HOSTED_AGENT_PROTOCOL_VERSION` | UI `v2.6.2` continuity attestation: `>=2.0.0`; deployments must keep it consistent with the exact platform Responses setting |
| `HOSTED_CONTINUITY_UNAVAILABLE_STATUS_CODE` | `503` |
| `HOSTED_HISTORY_MAX_ITEMS` / `HOSTED_HISTORY_MAX_TOKENS` | umbrella defaults `100` / `32000` |
| `HOSTED_HISTORY_TRUNCATION` | `drop_oldest` |
| `PANEL_HISTORY_ENABLED` / `PANEL_HISTORY_OWNER_BINDING_VALIDATED` / `PANEL_OPERATOR_SURFACES_ENABLED` | deployment-published `false` |
| `PANEL_CONVERSATION_ENUMERATION_MODE` | `owner_index` |
| `PANEL_CURSOR_TTL_SECONDS` / `PANEL_OVERVIEW_MIN_CARDINALITY` | `600` / `5` |

Rollback is a deployment/configuration operation, never a request-time retry.
It has two independent forms. Choose the narrowest one that resolves the
regression: reverting the image version keeps the hosted topology, while
topology rollback abandons hosted mode entirely.

### Version rollback: stay hosted, serve the previous image

A hosted agent version is immutable and serves 100% of the traffic, with no
canary and no traffic splitting. Rolling back therefore means switching the
endpoint back to a digest that was already published and validated. Revert
only the image identity and leave the topology untouched:

```powershell
pwsh scripts/prepareHostedDeployment.ps1 --image-version sha256:<previous-digest>
azd provision
azd deploy
```

On POSIX systems, use `scripts/prepareHostedDeployment.sh` with the same
argument. `--image-version` takes a canonical immutable digest, skips the image
build entirely, and clears generated-image provenance by writing an empty
`HOSTED_AGENT_IMAGE_SOURCE_COMMIT` and
`HOSTED_AGENT_IMAGE_STARTUP_COMMAND_SHA256`. The second provision materializes
the deploy handoff for the reverted digest.

Clearing that provenance is required, not cosmetic. A *generated* digest is
validated against the orchestrator commit pinned in `manifest.json`; a mismatch
fails composition with `DeploymentTopologyError` before any resource changes,
which is what stops a half-reverted environment from reaching Azure. An
*operator-supplied* digest carries no generated provenance, so that coherence
check does not apply and the older image is accepted while `manifest.json`
keeps pointing at the newer pin. Do not work around the check by hand-editing
`HOSTED_AGENT_IMAGE_VERSION` while leaving a stale source commit in place.

Because provenance is cleared, the environment no longer records which commit
produced the running image. Record the digest and its originating release
outside the environment before switching, so the reverted state stays
auditable.

To return to the manifest-pinned build, re-run the preparation step without
`--image-version`. A digest whose source commit no longer matches the manifest
is rebuilt from the current pin rather than reused.

### Topology rollback: leave hosted mode

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