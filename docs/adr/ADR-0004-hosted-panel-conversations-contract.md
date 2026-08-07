# ADR-0004: Owner-bound managed-Conversations panel contract to finish the hosted-agent feature (issue #611)

**Status:** Proposed<br>
**Date:** 2026-08-07<br>
**Owners:** GPT-RAG maintainer (Paulo), architecture analysis, with gpt-rag-ui,
gpt-rag-orchestrator, and gpt-rag-ingestion component owners

## Context

ADR-0001 packaged GPT-RAG orchestration as a Foundry hosted agent, made the
orchestrator Container Apps optional, and froze two facts that bind this ADR:

- Hosted modes use **Foundry managed Conversations** as the chat-history system
  of record. **No Cosmos** carries chat content in hosted/no-panel. Feedback and
  administrative curation metadata live in Cosmos and exist **only when the
  administrative panel is deployed** (`DEPLOY_ADMINISTRATIVE_PANEL=true`).
- Hosted versions are immutable; update = publish + switch, rollback = revert.

ADR-0003 made multi-turn continuity **application-managed against managed
Conversations**, keyed by a stable logical conversation ID carried in Responses
**request metadata** (never the top-level `conversation` routing parameter,
which 404s across version replacement).

**Reconciliation with the approved zero-RBAC invariant (this revision).** A
subsequent security review tightened the container invariant beyond ADR-0003's
original wording. The approved invariant is now: **the hosted container must
hold NO managed-Conversations data-plane RBAC at all — neither read nor
write.** This is stronger than "history-blind reads." The reason is decisive:
per ADR-0001 the Foundry gateway strips the `Authorization` header, so **the
user token never reaches the container**. A container therefore has **no
authenticated source of the owner principal**; any owner value it wrote would be
derived from caller-supplied request metadata and is **forgeable by a direct
Foundry caller**. Granting the container even append/write RBAC would let a
direct caller (or a compromised version) write items and stamp arbitrary
ownership. Consequently, ADR-0003's design of "the hosted agent retrieves and
persists items to managed Conversations" is **superseded on the persistence
location only**: the container becomes **purely stateless** — it receives a
**complete, ordered set of input items** each turn and returns output, exactly
the "canonical stateless Responses input" ADR-0003 confirmed remains viable —
and **all** managed-Conversation create/read/append/delete plus the owner index
move to the **authenticated UI BFF**, which is the only component holding the
user identity. ADR-0003's other freezes (managed Conversations as SoR, logical
ID in metadata, no top-level `conversation` param, bounded replay) are
unchanged; only *who* touches the Conversations data plane changes.

Issue #611 requires the **optional panel** to finish the feature, not just ship
no-panel preview. The panel must support **history, feedback, curation, and
overview**. This ADR decides the ownership, identity model, and versioned API
contract for those four surfaces without violating ADR-0001/0003 freezes and
while honoring the stricter zero-RBAC container invariant above.

### Inventory (executable sources of truth, read-only)

Release pins (`manifest.json`): umbrella `v3.7.0`; gpt-rag-ui `v2.3.13`,
gpt-rag-orchestrator `v3.8.0`, gpt-rag-ingestion `v2.5.0`.

Runtime and contract facts observed in this repository and the pinned
components:

- **gpt-rag-ingestion** (`dataingest` ACA, always deployed for indexing) hosts a
  FastAPI app that already mounts `api.admin` (operator dashboard router), a
  Vite-built admin frontend (`/dashboard`, `/assets`), and `api.retrieval`
  (`POST /retrieve`, the fail-closed Toolbox boundary). It authenticates
  internal callers by `X-API-KEY` (`validate_api_key_header`) and validates a
  **delegated user bearer** only for `POST /ingest-documents` and `POST
  /retrieve` (`validate_delegated_user_bearer`, which rejects app-only tokens
  and requires `idtyp=user` + `scp`). Its identity holds Search/Storage/Cosmos
  data roles for ingestion, **not** managed-Conversations read authority.
- **`POST /retrieve`** (`retrieval_v2.py`) is the reference fail-closed pattern:
  server-owned index and identity, caller-supplied IDs are schema violations
  (`extra="forbid"`), disabled-by-default returning **503** unless
  `HOSTED_RETRIEVAL_ENABLED` **and** `HOSTED_RETRIEVAL_INV_002_VALIDATED` are
  both true, bounded outputs, Search failures → 502, and the user bearer is
  forwarded unchanged to Search via `x-ms-query-source-authorization` for native
  trimming. Tests in `test_retrieval_v2.py` assert 403 on app-only tokens and
  503 when the evidence gate is unset.
- **gpt-rag-ui** (`frontend` ACA, deployed in every mode that serves chat) is
  the Chainlit thin BFF that holds the **user Entra token**, performs OBO, and
  owns the logical conversation ID (ADR-0001/0003). It is the only component in
  the hosted path that has the end-user identity in hand.
- **Cosmos** (`main.parameters.json`) has a `conversations` container
  partitioned by `/principal_id` with composite indexes on
  `isDeleted`/`_ts`/`name` — the classic-mode chat store. Hosted modes must not
  repopulate it with protected chat content.
- **Current 501 behavior:** in hosted mode the panel/history call path returns
  **HTTP 501 Not Implemented** because no authorized cross-repo
  managed-Conversations contract exists yet. 501 is the correct fail-closed
  placeholder: it neither invents a service-identity read nor leaks data.

### The security problem this ADR must not get wrong

The panel needs to show a user their own conversations from managed
Conversations. Four constraints are non-negotiable:

1. The hosted container holds **zero managed-Conversations data-plane RBAC** —
   neither read nor write. It is stateless: it receives complete ordered input
   items and returns output, and never touches the Conversations data plane.
2. **Owner identity must come from an authenticated source**, never from
   caller-supplied request metadata. Only a component that validates the user
   token (the UI BFF) may assert an owner principal. A **direct Foundry caller
   must be unable to forge ownership** — which it cannot, because it can only
   reach the stateless container, and the container writes nothing to
   Conversations and holds no ownership authority.
3. A **caller-selected conversation ID must never drive a service-identity
   read**. That is a classic confused-deputy / IDOR: caller supplies another
   user's ID, a service credential reads it, and per-user isolation is lost.
   Every read is preceded by an authenticated owner check.
4. The panel must **fail closed** and must **not duplicate protected
   conversation content into Cosmos**. Cosmos carries only feedback and
   curation **metadata** where strictly necessary.

The evolving decision, under live **OQ-OWN** testing, is the **owner-binding
mechanism used by the authenticated UI BFF**. Two concerns must be separated,
because conflating them created a contradiction (a Cosmos-backed owner index
cannot be the default in hosted/no-panel, where **no Cosmos is deployed**):

- **Per-conversation owner binding (continuity + single-conversation history) —
  required in ALL hosted modes including no-panel.** Baseline is a
  **server-issued, signed, opaque, owner-bound conversation capability** minted
  by the BFF from the validated user token; it requires **no persistent store**
  and therefore holds in no-panel with zero Cosmos. The target, when **OQ-OWN**
  proves it, is **delegated OBO** reads where Foundry enforces per-user access
  natively.
- **Cross-conversation enumeration (the panel "list my conversations") — a
  panel-only feature.** It legitimately requires a metadata store and therefore
  exists **only** when `DEPLOY_ADMINISTRATIVE_PANEL=true`, backed by the
  BFF-authored **owner index** in panel Cosmos (or delegated enumeration under
  OBO). In hosted/no-panel there is simply **no enumeration endpoint** — the user
  continues the conversation they hold a capability for; there is no list to
  recover. This is expected and acceptable.

In both concerns the authority is the BFF, never the container. This ADR decides
everything invariant across the OQ-OWN outcome and makes only the BFF mechanism
selectable, defaulting to the store-free capability until OQ-OWN passes.

### Resolving the no-panel / no-Cosmos continuity contradiction

The prior revision wrongly made the Cosmos owner index the default owner-binding
for continuity. But continuity is needed in hosted/no-panel, where no Cosmos is
provisioned. The smallest enforceable fix that adds **no chat content, no new
always-on compute, and no store in no-panel** is a **signed owner-bound
conversation capability**:

- **Shape.** An opaque token = `base64url(payload) . base64url(HMAC/JWS over
  payload)` where payload = `{ oid, conversation_resource_id, issued_at, expiry,
  key_id }`. It carries **no chat content** — only a pointer, the owner, and
  lifetime/key metadata.
- **Minting.** Only the BFF mints, and only from a **validated user token**: at
  conversation creation it derives `oid` from the verified token, allocates the
  managed Conversation, and signs the capability. The container never mints (no
  token, no signing key).
- **Verification (every turn / history read).** The BFF (1) verifies the
  signature with the active key, (2) checks `expiry`, and (3) asserts the
  capability's `oid` **equals the current authenticated user's `oid`**. Only then
  does it read prior items by `conversation_resource_id` and assemble stateless
  input. Any failure → uniform **404**. A raw caller-selected conversation ID is
  never accepted; the only accepted reference is a signed capability whose owner
  is re-checked against the live token.
- **Signing key.** A secret in **Key Vault** referenced from App Configuration,
  reusing the existing `AUDIT-HMAC-KEY` provisioning precedent (created from
  cryptographically random bits when absent, only its reference stored in App
  Config). Key Vault exists in all modes; the BFF (`frontend` ACA) already holds
  `KeyVaultSecretsUser`. **No Cosmos, no storage account, no new compute.**
- **Key rotation / revocation.** `key_id` names the active version. Rotation
  advances `key_id` and retains the previous verification key for a bounded
  overlap window; capabilities minted under a retired key fail verification after
  overlap (bulk revocation). Because there is no per-capability store in
  no-panel, **fine-grained single-capability revocation is not available in
  no-panel**; it is bounded instead by a **short TTL with rolling re-mint** (each
  successful turn returns a fresh capability), keeping the live theft window
  small. Per-conversation revocation/delete IS available in panel mode via the
  owner index/SoR delete.
- **Restart / browser persistence.** The capability is **self-contained**, so a
  BFF restart loses no server state (nothing is stored server-side). The client
  persists it in the Chainlit user session / secure `HttpOnly` cookie. If the
  browser/session loses it in no-panel, the pointer is gone and the user starts a
  new conversation (no enumeration exists to recover it) — acceptable for
  no-panel; recovery is exactly what the optional panel adds.
- **List / history behavior.** No-panel: history of the **held** conversation
  works via its capability; there is **no** cross-conversation list. Panel:
  enumeration is added via the owner index; each listed conversation is rendered
  through the same capability/owner-gate before any content read.
- **Panel `{id}` is a lookup key, never a self-authorizing reference.** The
  `{id}` a panel client passes on `/panel/conversations/{id}/...` endpoints is
  the raw `conversation_resource_id` returned by enumeration (metadata only —
  see the panel endpoint table). It is **never** trusted on its own. Before any
  read/write, the BFF performs an **owner check** for that `{id}`: an
  owner-index row lookup asserting `principal_id == live oid` (Option A) or an
  equivalent delegated per-user authorization (Option B). Only after that
  check succeeds does the BFF treat `{id}` as `conversation_resource_id` and
  proceed — internally, this may reuse or mint a capability to perform the
  actual read, but the **client is never required to hold or present a
  capability for panel browsing**; the owner check on `{id}` is the
  authorization, consistent with "no caller-selected raw ID drives a
  service-identity read" because the read is never driven by `{id}` alone —
  it is driven by `{id}` **conditioned on** a passing owner check.
- **Replay / theft.** The capability is **not sufficient by itself** — a read
  also requires a valid Entra user token whose `oid` matches the capability's
  `oid`. A stolen capability presented by a different user fails the `oid`
  equality check (→404). Theft is only useful if the victim's Entra session is
  also compromised, which is out of this boundary's scope. Short TTL + rolling
  re-mint further bound replay.
- **404 equivalence.** Bad signature, expired, wrong `oid`, retired key, or
  unknown conversation all return an identical **404** — no existence oracle.
- **Direct-caller spoofing.** Direct Foundry callers reach only the stateless,
  zero-RBAC container; they cannot mint (no signing key) or forge a capability,
  and the container reads/writes/owns nothing. Ownership only ever originates
  from a BFF mint over a validated token.
- **Sufficiency for cross-version continuity.** Yes. The capability carries
  `conversation_resource_id`, which points at the managed Conversation (SoR) that
  **survives version/compute replacement** (ADR-0003 evidence). The capability is
  not a version-bound gateway session (unlike the top-level `conversation`
  param), so it does not 404 across version swaps. Each turn is a fresh stateless
  request; continuity = capability (pointer+authz) + managed Conversations (SoR).
  The capability holds no content and is not the SoR.

An existing generic private store (e.g., the provisioned `conversation-cache`
Blob container) was considered for owner→conversation metadata in no-panel and
**rejected for the continuity path**: it reintroduces a persistent store, a
write path, and consistency/cleanup obligations that the capability avoids
entirely. A store remains justified **only** for the panel enumeration feature,
where cross-conversation listing genuinely needs one — and there it is Cosmos,
gated by the panel flag.

### Affected repositories

- `Azure/GPT-RAG` (this repo) — App Configuration contract (label `gpt-rag`),
  the versioned `contracts/conversations-panel-v1` schema, the panel deploy flag
  wiring, this ADR. Infra must assign managed-Conversations data-plane RBAC to
  the **UI BFF identity only** (Option A) or none (Option B/OBO), and **never**
  to the hosted agent / container identity.
- `Azure/gpt-rag-ui` — **exclusive owner** of all managed-Conversation
  create/read/append/delete and the owner index, and of user-facing
  list/read/feedback/deletion. It is the only component holding the user token,
  so it is the only authenticated source of the owner principal (the validated
  `oid`). Per turn it: validates the token, owner-gates, reads prior ordered
  items, sends a **complete stateless input set** to the container, receives
  output, and appends the new user/assistant items.
- `Azure/gpt-rag-ingestion` — **operator-facing** panel backend for **overview
  metrics over metadata** and **corpus/document curation it already has content
  access to**. It has **no conversation-content access** and exposes **no
  curation derived from conversation content**. Replaces the 501 only for these
  metadata/corpus surfaces; keeps its evidence-gated, fail-closed posture.
- `Azure/gpt-rag-orchestrator` — the hosted agent/container is **stateless**:
  it receives complete ordered input items and returns output. It holds **zero
  managed-Conversations RBAC**, creates/reads/appends nothing, and stamps no
  ownership. It cannot be an owner authority because it never sees the user
  token.

### Prioritized characteristics (measures)

1. **Authorization correctness / fail-closedness** — no cross-user read, no
   service-identity read driven by a caller ID, disabled surfaces return 503,
   non-owner returns 404 (no existence disclosure). (Two-user negative tests.)
2. **Content confinement** — zero protected chat content written to Cosmos or
   telemetry; overview metrics carry counts only. (Store-inspection tests.)
3. **Container zero-RBAC** — the hosted agent/container identity holds **no**
   Conversations data-plane role, read or write. (RBAC assertion / infra review.)
4. **Owner-authenticity / anti-spoof** — ownership is asserted only from a
   validated user token by the BFF; a direct Foundry caller cannot forge
   ownership. (Negative test: direct call cannot create/own a conversation.)
5. **Reversibility** — every surface is behind one flag; default preserves
   today's 501/absent-panel behavior. (Config-flip test.)
6. **Operability under the immutable-version + network-isolated model** — no new
   always-on compute; works with private endpoints. (Topology matrix.)

## Alternatives considered

### Option A: BFF-minted signed owner-bound capability for continuity (all modes), plus a panel-only owner index for enumeration (chosen baseline)

The **UI BFF** is the sole component that touches the Conversations data plane.
On the first turn the **authenticated BFF** (holding the validated user token,
`oid`) creates the managed Conversation, writes the new items, and mints a
**signed owner-bound capability** = signed `{oid, conversation_resource_id,
issued_at, expiry, key_id}`. The owner principal is the **validated `oid`**,
never caller metadata. The capability holds **no chat content** and needs **no
store** — so it works in hosted/no-panel with **zero Cosmos**. The stateless
container receives the complete ordered input set the BFF assembles and returns
output; it writes nothing.

- Per-conversation reads (all modes): the BFF verifies the capability signature,
  checks expiry/`key_id`, and asserts the capability `oid` **equals the live
  authenticated `oid`**; only then reads items by `conversation_resource_id`.
  Any failure → **404**. A raw caller-selected ID is never accepted.
- Enumeration (**panel only**, `DEPLOY_ADMINISTRATIVE_PANEL=true`): the BFF also
  records a **minimal owner-index** row — `principal_id → {conversation_id,
  title, timestamps}` — in the panel Cosmos container so the panel can list the
  user's conversations. `GET /panel/conversations` returns only rows where
  `principal_id == oid`; each item still passes the capability/owner gate before
  any content read. **Metadata only; no message content.** In no-panel this store
  and endpoint do not exist; continuity is unaffected.
- Anti-spoof: a direct Foundry caller reaches only the stateless container, which
  has zero Conversations RBAC and mints/owns nothing. Ownership originates only
  from a BFF mint over a validated token; a capability cannot be forged without
  the Key Vault signing key.
- Operator surfaces (gpt-rag-ingestion): overview reads **counts over metadata**
  only; corpus curation operates on documents ingestion already indexes — never
  on conversation content.
- Benefits: works today in **every** mode with no store for continuity; no
  dependency on unproven delegated auth; **container holds zero Conversations
  RBAC**; owner authority is the authenticated BFF; matches the `POST /retrieve`
  fail-closed idiom and the `AUDIT-HMAC-KEY` Key Vault precedent.
- Costs and risks: the **BFF service identity** holds Conversations read/write
  RBAC, so the confused-deputy risk is concentrated there and mitigated by the
  capability `oid`-equality gate. No-panel lacks fine-grained per-capability
  revocation (bounded by short TTL + rolling re-mint and by key rotation); the
  panel adds per-conversation revocation via the owner index/SoR delete. The BFF
  must keep the (panel-only) index consistent with the SoR; a stale row can only
  cause a 404 or a spurious list entry, never content disclosure.
- Security and identity: the gate is a **server-side check** binding a signed,
  token-derived capability to the live token `oid` — not a caller claim and not
  forgeable by the container. Cosmos (panel only) holds only `principal_id` +
  identifiers/titles.
- Operational consequences: no new ACA; signing key in Key Vault (all modes);
  owner index in panel-only Cosmos; works network-isolated over private
  endpoints. Infra grants Conversations RBAC to the **BFF identity only**.
- Component compatibility: coordinated change across all four repos; App
  Configuration selector + capability-key keys; one `contracts/` schema.
- Reversibility: continuity mechanism is a single selector; panel enumeration is
  behind the panel flag; when a surface is off it returns 503 and writes nothing.

### Option B: Native delegated (OBO) reads/writes against managed Conversations from the BFF (preferred target, gated on OQ-OWN)

The BFF exchanges the user token (OBO) for a token that reads **and writes**
managed Conversations **as the user**, so Foundry/Conversations enforces per-user
authorization natively — the same philosophy as `POST /retrieve` forwarding the
user bearer to Search. No GPT-RAG-authored owner index is needed, and the **BFF
holds no standing Conversations RBAC**.

- Benefits: authorization enforced by the platform at the data plane; no
  GPT-RAG-owned ownership state; cleanest confused-deputy elimination; the BFF
  needs no ambient Conversations role; smallest long-term surface.
- Costs and risks: **depends on OQ-OWN** — whether the managed Conversations data
  API accepts a delegated user token and enforces per-user/owner access. If it
  only accepts a service credential, Option B collapses into a service-read and
  is **unsafe by itself**; it must not ship without native per-user enforcement
  proven.
- Security and identity: strongest when supported; the container still holds no
  role — the **user's** delegated token authorizes reads/writes, minted by the
  BFF which already holds the user token.
- Operational consequences: no index to keep consistent; requires a Conversations
  query-token audience config, analogous to `HOSTED_RETRIEVAL_TOKEN_AUDIENCE`.
- Component compatibility: same repo set; the mechanism differs only inside the
  BFF behind the selector.
- Reversibility: single flag; can fall back to Option A.

### Option C: A service identity (container or panel) reads/writes by caller-supplied conversation ID or caller-supplied owner (rejected)

Let any service identity create/read managed Conversations using caller-supplied
IDs or caller-supplied ownership — including the container stamping owner from
request metadata.

- Benefits: trivial to implement.
- Costs and risks: **rejected on security grounds.** Two failures: (1) cross-user
  IDs would drive service-identity reads (confused-deputy/IDOR); (2) ownership
  stamped from caller metadata is **forgeable by a direct Foundry caller**, since
  the container never sees the user token. It also requires granting the
  container Conversations RBAC, violating the zero-RBAC invariant.
- Reversibility: n/a — unsafe at any setting.

### Option D: Panel backend on a revived orchestrator ACA (rejected for this feature)

Bring the orchestrator Container Apps back as the panel backend (original
ADR-0001 wording).

- Benefits: a dedicated home; matches the earliest sketch.
- Costs and risks: reintroduces the compute ADR-0001 removed; in no-panel mode
  it is absent, so it cannot host owner-bound reads without also being deployed;
  it does not hold the user token (the UI does), so owner-binding would still
  route through the UI. More resource, no security benefit.
- Reversibility: heavier; a whole app toggles.

### Do not change (Option E)

- Benefits: none beyond deferral; keeps the safe 501.
- Costs and risks: the hosted-agent feature **cannot finish** — no history,
  feedback, curation, or overview in hosted mode. Fails issue #611.

## Decision

Finish the hosted panel with an **owner-bound, fail-closed, content-confining**
contract in which the **container holds zero managed-Conversations RBAC** and
the **authenticated UI BFF exclusively owns** managed-Conversation
create/read/append/delete and the owner index, split by audience across
already-deployed compute, with the BFF read mechanism selectable and defaulted
to the safe state:

1. **Stateless container, BFF-exclusive Conversations.** The hosted
   agent/container is stateless: it receives a **complete ordered input set**
   from the BFF each turn and returns output. It holds **zero
   managed-Conversations data-plane RBAC** and never creates, reads, appends, or
   deletes conversation items or ownership. The **gpt-rag-ui BFF** — the only
   component holding the user token — performs, per turn: token validation →
   owner gate → read prior ordered items → assemble complete stateless input →
   call container → append new user/assistant items. It is the sole authenticated
   source of the owner principal (validated `oid`). This supersedes ADR-0003's
   in-container persistence on the *location* of the write only.

2. **No new ACA.** User-facing history/feedback/deletion land in the
   **gpt-rag-ui** BFF (it holds the user token → owner-binding). Operator-facing
   **overview metrics (metadata counts)** and **corpus/document curation**
   (content ingestion already indexes) land in the **gpt-rag-ingestion** admin
   app, replacing the 501 for those surfaces. Ingestion exposes **no curation
   derived from conversation content** — it has no conversation-content access.
   The panel **frontend** extends the existing ingestion Vite admin dashboard for
   the **operator** overview/corpus-curation views and reuses the Chainlit UI for
   the **user** history/feedback views. Smallest safe footprint: endpoints attach
   to compute that already runs.

3. **Owner-binding is invariant; the BFF mechanism is a selector; continuity is
   store-free.** Ship **Option A** baseline: per-conversation owner binding
   (continuity + single-conversation history in **all** modes) via a **BFF-minted
   signed owner-bound capability** that needs **no store**, plus a **panel-only**
   owner index (Cosmos) for cross-conversation enumeration. Adopt **Option B
   (native delegated OBO)** the moment **OQ-OWN** proves managed Conversations
   enforces per-user authorization for delegated tokens. Both keep the
   **container at zero Conversations RBAC** and both fail closed. **Option C is
   prohibited.** No-panel has no enumeration endpoint and no Cosmos; continuity
   still works via the capability.

4. **Fail-closed by default.** Every panel surface is disabled unless the panel
   is deployed **and** its evidence gate is set, mirroring `POST /retrieve`.
   Until owner-binding is validated, hosted history keeps returning the safe
   status (503 when the surface exists but is gated off; 501 remains acceptable
   only where no endpoint is wired yet). No service-identity-by-caller-ID read
   and no caller-asserted ownership is shipped in any state.

5. **Content confinement.** Managed Conversations remains the sole store of chat
   content. Cosmos (panel-only) carries feedback and curation **metadata** and
   the owner index — identifiers, titles, timestamps, principal IDs, decisions —
   **never** message bodies or retrieved document content. Overview metrics are
   aggregate counts with a minimum-cardinality threshold and never join content.

### Versioned API contract: `conversations-panel-v1`

Owned by `Azure/GPT-RAG` in `contracts/`, byte-pinned like `audit-event-v1`,
consumed by gpt-rag-ui (user surfaces) and gpt-rag-ingestion (operator
surfaces). Common rules: request bodies are strict (`extra=forbid`); identity
and index/store selection are **server-owned**; correlation via `req_[0-9a-f]{32}`
propagated into `audit-event-v1`; pagination via **opaque, signed, expiring
cursors** (never raw offsets or caller IDs); all list/read responses are
bounded.

User-facing (gpt-rag-ui BFF, requires delegated user token, owner-gated):

| Method / path | Purpose | Authorization | Not-authorized result |
| --- | --- | --- | --- |
| `GET /panel/conversations?cursor=` | **Panel-only** — list the caller's conversations (id, title, created/updated); no content | Owner-index rows where `principal_id == oid` (A) or delegated list (B). **Absent in no-panel** | Empty page; never another user's rows |
| `GET /panel/conversations/{id}/messages?cursor=` | Ordered history for one owned conversation (all modes) | **Owner check on `{id}`**: owner-index row `principal_id == live oid` (A) or delegated per-user authorization (B); only on success does the BFF read by `conversation_resource_id == {id}` (may reuse/mint a capability internally) | **404** (no existence disclosure) |
| `POST /panel/conversations/{id}/feedback` | Create feedback **metadata** (rating, reason code, message ref) → Cosmos | Owner gate | **404** |
| `GET /panel/conversations/{id}/feedback` | Read caller's own feedback | Owner gate | **404** |
| `DELETE /panel/conversations/{id}` | Owner-initiated retention/deletion: delete managed Conversation items + panel metadata/index row | Owner gate | **404** |

Operator-facing (gpt-rag-ingestion admin, requires operator app role / group,
**not** end-user tokens, **no conversation-content access**):

| Method / path | Purpose | Authorization | Leakage control |
| --- | --- | --- | --- |
| `GET /panel/corpus-curation/queue?cursor=` | **Document/knowledge-base** curation items (documents ingestion already indexes and can access) | Operator role | Corpus artifacts only; **no conversation content** |
| `POST /panel/corpus-curation/{item_id}/decision` | Record a corpus curation decision (metadata) | Operator role | Decision + document refs only |
| `GET /panel/overview/metrics` | Aggregate **counts over panel metadata** (conversation/feedback counts, corpus states) | Operator role | Counts only; suppress buckets below min-cardinality; **no content join** |

Conversation-content curation is **not** an operator surface. If a user wishes to
curate their own conversation (e.g., flag/redact a message), that is an
**owner-scoped** action on a user-facing endpoint under the owner gate, never an
ingestion-operator capability. Any future operator content-review capability
would require a separate, explicitly-authorized, audited design and is out of
scope here (denied by default) — see OQ-611-OPSCOPE.

Error semantics (uniform): **401** missing/invalid bearer; **403** wrong token
type/audience (app-only token on a user surface, or missing operator role);
**404** not-owner or missing (never 403 for ownership, to avoid existence
disclosure); **422** schema/bounds violation; **502** managed-Conversations or
downstream failure; **503** surface deployed but evidence gate unset. Retention:
deletion is a hard delete of managed-Conversation items plus panel metadata;
`delete_after`-style policy intent is recorded but GPT-RAG performs no automatic
scheduled deletion (consistent with v3.7.0 governance guidance).

### App Configuration contract (label `gpt-rag`, owned by Azure/GPT-RAG)

Continuity keys (apply in **all** hosted modes, including no-panel; no store).
Authoritatively defined in ADR-0003; restated here for context — ADR-0003 is
the source of truth if wording ever diverges:

- `HOSTED_CONVERSATION_OWNER_BINDING` (default `capability`; alt `delegated`) —
  selects per-conversation owner binding: BFF-minted signed capability (A) vs.
  delegated OBO (B). `delegated` is inert until
  **`HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED`** (ADR-0003) is `true` for
  the hosted continuity call path — this is a **different, independent** gate
  from the panel-only `PANEL_HISTORY_OWNER_BINDING_VALIDATED` below; neither
  substitutes for the other.
- `HOSTED_CONVERSATION_CAPABILITY_KEY` — **Key Vault reference** to the HMAC/JWS
  signing key, provisioned like `AUDIT-HMAC-KEY` (created from random bits when
  absent; only the reference is stored in App Config). Present in all modes; no
  Cosmos, no storage account.
- `HOSTED_CONVERSATION_CAPABILITY_KEY_ID` (default `v1`) — active signing key
  version; advance to rotate (previous key retained for a bounded overlap).
- `HOSTED_CONVERSATION_CAPABILITY_TTL_SECONDS` (default e.g. `3600`) — capability
  lifetime; the BFF re-mints a fresh capability on each successful turn (rolling)
  to bound replay/theft in the absence of per-capability revocation.

Panel keys (apply **only** when the administrative panel is deployed):

- `DEPLOY_ADMINISTRATIVE_PANEL` (existing, default `false`) — provisions panel
  Cosmos metadata containers (feedback, curation, owner index) and enables panel
  routers, **including cross-conversation enumeration**. Absent → no Cosmos, no
  enumeration.
- `PANEL_HISTORY_ENABLED` (default `false`) — panel user history/feedback gate.
- `PANEL_HISTORY_OWNER_BINDING_VALIDATED` (default `false`) — the **OQ-OWN
  evidence gate for the panel enumeration/read call path only**, mirroring
  `HOSTED_RETRIEVAL_INV_002_VALIDATED`. `PANEL_CONVERSATION_ENUMERATION_MODE=
  delegated` and any delegated per-conversation panel read require it true.
  This gate is **independent of** `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED`
  (ADR-0003) — it governs only the panel's own list/read path and never
  unlocks `delegated` for the core hosted-continuity binding, and vice versa.
- `PANEL_CONVERSATION_ENUMERATION_MODE` (default `owner_index`; alt `delegated`)
  — panel-only listing backend: BFF-authored owner index in panel Cosmos (A) vs.
  delegated user enumeration (B).
- `PANEL_CONVERSATIONS_TOKEN_AUDIENCE` — Conversations query-token audience for
  Option B (analogous to `HOSTED_RETRIEVAL_TOKEN_AUDIENCE`); required only in
  `delegated` binding/enumeration.
- `PANEL_OVERVIEW_MIN_CARDINALITY` (default e.g. `5`) — metric bucket
  suppression threshold.

## Threat model

| Threat | Vector | Mitigation in this ADR |
| --- | --- | --- |
| **Cross-user conversation IDs (IDOR)** | Caller passes another user's `conversation_id` | Only a signed capability is accepted; the BFF re-checks the capability `oid` equals the live token `oid` before any read; miss → 404. A raw caller ID never drives a read (A) or the read is delegated as the user (B) |
| **Capability theft / replay** | Attacker presents a stolen capability | A capability alone is **insufficient**: reads also require a valid Entra token whose `oid` matches the capability `oid`, so a different user fails the equality check (→404). Short TTL + rolling re-mint bound the window; key rotation performs bulk revocation |
| **Capability forgery** | Attacker mints/edits a capability | Signed with a Key Vault key held only by the BFF; edits break the signature (→404); the container has no signing key and cannot mint |
| **Direct agent/Foundry callers** | Direct caller reaches the container and tries to read/enumerate/own conversations | Container holds **zero Conversations RBAC** and never touches the data plane; it only consumes BFF-supplied stateless input, and cannot mint capabilities. It reads, writes, and owns nothing |
| **Ownership forgery** | Caller-supplied owner in request metadata to claim a conversation | Ownership originates only from a BFF mint (capability) over a validated token `oid`; the container writes no ownership, so caller metadata can never establish ownership |
| **Service-identity confused deputy** | A service credential reads by caller ID | Prohibited (Option C rejected). Only the **BFF identity** holds Conversations RBAC (Option A) or none (Option B/OBO); every BFF read is gated by the capability `oid`-equality check |
| **Support/admin over-reach** | Operator role reads protected user chat content | Operator surfaces expose metadata/counts and **corpus** artifacts only; ingestion has no conversation-content access; raw conversation content is not provided and would require a separate, elevated, audited path (out of scope, denied by default) |
| **Document-citation leakage** | Re-rendered history shows citations to documents the user has since lost access to | History stores **citation references**, not document content; render re-checks access (native trimming) before resolving a citation; snapshot-vs-live divergence recorded as OQ-611-CITE |
| **Telemetry leakage** | Content or IDs in logs/metrics | `audit-event-v1` metadata-only; correlation IDs only; overview metrics thresholded; capability signatures/keys never logged; no conversation body or document content in any log/metric |
| **Existence disclosure** | 403-vs-404 oracle reveals a conversation exists | Uniform **404** for bad/expired/wrong-`oid`/retired-key capability and for missing |
| **Pagination tampering** | Caller forges cursor to page another user's data | Opaque, signed, expiring cursors bound to the authenticated principal |

## Consequences

### Positive

- The hosted-agent feature can **finish**: history, feedback, curation, and
  overview exist in hosted mode with a versioned, fail-closed contract.
- No new always-on compute; endpoints attach to already-deployed UI and
  ingestion apps; works in the network-isolated topology.
- Container holds **zero Conversations RBAC**, managed-Conversations-as-SoR, and
  no-Cosmos-chat freezes (ADR-0001/0003) are preserved and strengthened.
- Safe under OQ-OWN uncertainty: the safe mechanism ships now; the preferred
  native mechanism is a config flip once proven.

### Negative or accepted

- Baseline Option A adds a GPT-RAG-owned owner index that must stay consistent
  with the SoR (bounded blast radius: at worst a 404 or a stale list row, never
  content disclosure), and concentrates Conversations RBAC on the **BFF identity**.
- The BFF now owns per-turn read-prior-items + assemble-stateless-input + append
  (moved out of the container per the stricter invariant). This adds BFF logic
  and the bounded-replay policy (ADR-0003) now lives entirely in the BFF.
- Audience split means two backends implement one contract; the shared
  `contracts/` schema and conformance tests keep them aligned.
- Citation snapshot-vs-live access divergence is an accepted, documented risk
  pending OQ-611-CITE.
- **ADR-0003 has been revised** (see its revision note): its in-container
  persist/replay design is superseded on location — the BFF, not the
  container, reads/appends managed Conversations. Its other freezes are
  retained.

## Adoption and migration

Coordinated, ordered change (compatible-commit discipline per AGENTS.md):

1. **Azure/GPT-RAG** — add `contracts/conversations-panel-v1` (schema +
   `.sha256`); the App Configuration keys above (defaults preserve current
   behavior); the **capability signing key** provisioned in Key Vault like
   `AUDIT-HMAC-KEY` (created from random bits when absent, only its reference in
   App Config) — present in **all** hosted modes; panel Cosmos metadata containers
   gated by `DEPLOY_ADMINISTRATIVE_PANEL`; and infra RBAC assigning Conversations
   data-plane roles to the **BFF identity only** and **removing any such role from
   the hosted agent/container identity**. Publish this ADR. No runtime behavior
   change yet.
2. **gpt-rag-orchestrator** — make the hosted agent/container **stateless**:
   remove any managed-Conversations read/append/persist from the container and
   confirm it consumes only the BFF-supplied complete ordered input. Remove any
   Conversations RBAC from the container identity. No owner stamping and no
   capability minting in the container (it has no authenticated identity or key).
   Emit `audit-event-v1` for the turn only.
3. **gpt-rag-ui** — the BFF becomes the **exclusive** Conversations owner and the
   **sole capability minter/verifier**. Continuity (all modes,
   `HOSTED_CONVERSATION_OWNER_BINDING=capability`): on create, allocate the
   managed Conversation and mint a signed owner-bound capability from the
   validated `oid`; per turn, verify capability (signature + expiry + `oid`
   equality) → read prior items by `conversation_resource_id` → assemble complete
   stateless input → call container → append items → re-mint a fresh capability.
   Panel (when deployed): also write/read the owner index for enumeration behind
   `PANEL_HISTORY_ENABLED` + (`delegated` requires
   `PANEL_HISTORY_OWNER_BINDING_VALIDATED`); implement history/feedback/deletion.
   Never accept a raw caller-selected ID.
4. **gpt-rag-ingestion** — implement operator **overview (metadata counts)** and
   **corpus/document curation** routers behind `DEPLOY_ADMINISTRATIVE_PANEL`,
   replacing the 501 for those surfaces; **no conversation-content access or
   conversation-content curation**; fail-closed 503 when gated off; operator-role
   check plus existing bearer patterns.
5. Revalidate in Basic and network-isolated topologies; run the two-user negative
   suite, the direct-caller anti-spoof test, and a **capability
   theft/expiry/rotation** test; validate **no-panel continuity with zero Cosmos**;
   then update `manifest.json` pins for all changed components together.

Migration boundaries: no backfill. Existing classic Cosmos-backed history is
untouched and remains the classic path. Hosted/no-panel provisions **no Cosmos**
and uses store-free capability continuity; hosted/panel adds the Cosmos owner
index for enumeration only.

Rollback: flip `HOSTED_CONVERSATION_OWNER_BINDING`/`PANEL_HISTORY_ENABLED`/
`DEPLOY_ADMINISTRATIVE_PANEL` as needed and revert the coordinated manifest pin.
Because managed Conversations is SoR, the capability is stateless, and Cosmos
holds only metadata, no chat-content migration is needed either direction;
owner-index rows are metadata and can be dropped; rotating
`HOSTED_CONVERSATION_CAPABILITY_KEY_ID` invalidates outstanding capabilities.

## Compliance verification (fitness functions)

- **FF-1 Owner gate (deterministic):** `GET /messages`, feedback, and delete for
  a capability whose `oid` ≠ live token `oid`, or an absent/forged capability,
  return **404**; a raw caller-selected ID is never accepted. Unit + contract.
- **FF-1b Capability lifecycle (deterministic):** a tampered signature, expired
  capability, or capability minted under a retired `key_id` (past overlap) all
  return **404**; a valid capability with matching `oid` succeeds; a successful
  turn returns a fresh (rolling) capability. Unit tests over the signer/verifier.
- **FF-1c No-panel continuity with zero store (live):** in hosted/no-panel
  (`DEPLOY_ADMINISTRATIVE_PANEL=false`, no Cosmos), a multi-turn conversation
  retains prior context via the capability across turns **and** across an
  immutable-version/compute replacement, with **no Cosmos provisioned** and no
  gateway 404 (ties to ADR-0003 FF-1).
- **FF-2 Two-user negative (live):** user A creates a conversation; user B's list
  (panel) omits it; B presenting A's capability with B's token, or A's raw ID,
  fails `GET /messages`, feedback POST/GET, and DELETE with 404; operator overview
  shows counts without content. Reuse INV-002.
- **FF-3 Content confinement:** after any operation, assert **no** message body or
  document content exists in Cosmos, the capability, or telemetry; overview
  responses contain only counts and suppress sub-threshold buckets.
- **FF-4 Container zero-RBAC (strengthened):** infra/RBAC assertion that the
  hosted agent/container identity holds **no** Conversations data-plane role
  (read *or* write) and has **no** capability signing key; a container-originated
  read/append/create attempt fails at the platform. Conversations RBAC exists
  **only** on the BFF identity (Option A) or nowhere (Option B/OBO).
- **FF-4b Anti-spoof / direct caller (live):** a direct Foundry call to the
  container cannot create, own, read, or append a conversation, and cannot mint a
  capability; caller-supplied owner metadata never establishes ownership; the only
  conversations that exist are those the authenticated BFF created from a
  validated token.
- **FF-5 Fail-closed gating:** panel user history endpoints return **503** unless
  `PANEL_HISTORY_ENABLED` (and, for `delegated`, `PANEL_HISTORY_OWNER_BINDING_VALIDATED`);
  operator endpoints return **503** unless `DEPLOY_ADMINISTRATIVE_PANEL`;
  `HOSTED_CONVERSATION_OWNER_BINDING=delegated` is inert until its validated gate.
- **FF-6 Token-type enforcement:** user surfaces reject app-only tokens (403,
  reusing the `idtyp`/`scp` checks); operator surfaces reject end-user tokens
  lacking the operator role (403).
- **FF-7 Contract conformance:** requests/responses validate against
  `conversations-panel-v1`; capabilities and cursors are opaque, signed,
  principal-bound, and expiring; the byte-pinned `.sha256` matches in both
  consumers.
- **FF-8 Error-semantics matrix:** 401/403/404/422/502/503 mapping verified per
  the table, including uniform 404 for bad/expired/wrong-`oid` capability vs
  missing.
- **FF-9 No conversation-content curation on operator surface:** ingestion
  operator endpoints expose no conversation body; corpus-curation touches only
  documents ingestion already indexes.

## Documentation impact

Update the hosted-agent operator page on the `docs` branch: panel modes and
flags, the `conversations-panel-v1` contract, the **stateless-container /
BFF-exclusive-Conversations** model and the owner-binding model with its OQ-OWN
gate, the audience split (user history/feedback in the UI, operator overview and
**corpus** curation in the ingestion admin app — no conversation-content
curation), the zero-Conversations-RBAC container guarantee, content-confinement
guarantees, retention/deletion semantics, and the citation snapshot caveat. Note
that ADR-0003 is superseded on persistence location and must be updated.

## Review trigger

Reassess when any of the following occurs:

- **OQ-OWN resolves (two independent, per-call-path gates — neither substitutes
  for the other):**
  - Hosted continuity call path: managed Conversations data API confirms
    per-user authorization for delegated tokens on the **BFF's per-turn
    read/append path** — switch `HOSTED_CONVERSATION_OWNER_BINDING` to
    `delegated` only after setting **`HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED`**
    (ADR-0003) true for that exact call path.
  - Panel history/enumeration call path: the same API property confirmed
    separately for the **panel's list/read path** — switch
    `PANEL_CONVERSATION_ENUMERATION_MODE` (and, for per-conversation panel
    reads, the delegated-read branch) to `delegated` only after setting
    **`PANEL_HISTORY_OWNER_BINDING_VALIDATED`** (this ADR) true for that exact
    call path. This gate never unlocks `HOSTED_CONVERSATION_OWNER_BINDING`,
    and the ADR-0003 gate never unlocks panel delegated enumeration/reads —
    each path requires its own live evidence per the "exact call path"
    requirement.
- Foundry changes managed-Conversations identity/RBAC, ordering, or deletion
  semantics.
- Any FF regresses in validation or production, or a security review reports a
  cross-user or service-identity read path, or a capability theft/forgery path.
- Hosted agents leave preview or change header/identity propagation.

## Open questions

- **OQ-OWN (governs the binding mechanism, not continuity availability):** Does
  the managed Conversations data API accept a **delegated user token** and enforce
  per-user (owner-bound) authorization? If yes → `delegated` (Option B) may
  supersede the capability **for reads** and the owner index is dropped for reads.
  If no → the **capability** (Option A) remains the store-free continuity binding
  and Option C stays prohibited. Note: continuity is **not** blocked on OQ-OWN —
  the capability works today with zero store; OQ-OWN only decides whether the
  platform can enforce reads natively instead.
- **OQ-611-CAP (capability primitives):** Confirm the signing algorithm and key
  handling (HMAC vs JWS), Key Vault provisioning parity with `AUDIT-HMAC-KEY`,
  the TTL/rolling-re-mint values, and the rotation overlap window. Confirm the
  client persistence surface (Chainlit session vs `HttpOnly` cookie) meets the
  restart/browser requirements without exposing the capability to scripts.
- **OQ-611-OWNERSTAMP:** Confirm the **BFF** can durably record ownership — via a
  signed capability (Option A, no store) or via managed-Conversation ownership
  established by the user's delegated identity (Option B) — and that it survives
  version replacement (ADR-0003). The **container never records ownership**.
- **OQ-611-BFF-RBAC:** For Option A, confirm the minimal Conversations data-plane
  role the **BFF identity** needs (read + append + delete for owner-gated
  operations) scoped without granting the container any role. For Option B,
  confirm the BFF can operate with **no standing Conversations RBAC** using OBO.
- **OQ-611-REVOKE:** Confirm the acceptability of no fine-grained per-capability
  revocation in no-panel (bounded by short TTL + rolling re-mint + key rotation),
  or define a minimal revocation signal that does not reintroduce an always-on
  store in no-panel.
- **OQ-611-CITE:** Decide citation re-render policy — re-check live access before
  resolving a stored citation reference vs. accept a documented snapshot risk.
- **OQ-611-OPSCOPE:** Confirm operator identity model for ingestion panel
  surfaces (app role vs. Entra group) and whether any elevated, audited
  content-access path is ever in scope (default: no).
- **OQ-611-DELRETENTION:** Confirm deletion propagation SLA/consistency between
  managed-Conversation item delete and owner-index/feedback metadata delete
  (panel mode).
