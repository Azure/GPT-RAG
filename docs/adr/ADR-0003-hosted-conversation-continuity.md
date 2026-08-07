# ADR-0003: Multi-turn continuity for the hosted-agent Responses path across compute/version replacement

**Status:** Proposed<br>
**Date:** 2026-08-07<br>
**Owners:** GPT-RAG maintainer (Paulo), architecture analysis, with gpt-rag-ui and gpt-rag-orchestrator component owners (revised after independent security review)

> **Revision note (2026-08-07, superseded in part by ADR-0004).** Two points in
> this ADR are tightened by ADR-0004 after security review, and this ADR is
> updated to match:
>
> 1. **Persistence/replay location.** ADR-0004's approved invariant is that the
>    hosted **container holds zero managed-Conversations data-plane RBAC (neither
>    read nor write)**, because the Foundry gateway strips the user token so the
>    container has no authenticated identity and could only act on forgeable
>    caller metadata. Therefore the container is **purely stateless** — it
>    receives a complete ordered input set and returns output — and **all**
>    managed-Conversation read/append/persist plus continuity move to the
>    **authenticated UI BFF**. Where this ADR says "inside the hosted agent the
>    application retrieves/replays/persists," read "**the UI BFF** retrieves,
>    replays, and persists."
> 2. **How the logical ID is carried.** The stable logical conversation
>    identifier is **not** carried as a raw resource ID in request metadata that
>    a service could act on. It is carried as a **server-issued, signed,
>    opaque, owner-bound capability** minted by the BFF from the validated user
>    `oid` (`{oid, conversation_resource_id, issued_at, expiry, key_id}`), so no
>    caller-selected ID drives a read and a direct caller cannot forge ownership.
>    The capability requires **no store**, so continuity holds in
>    **hosted/no-panel with zero Cosmos**. See ADR-0004 for the capability
>    design, key rotation, replay/theft handling, and the panel-only owner index
>    used solely for cross-conversation enumeration.


## Context

ADR-0001 chose Option 1: package GPT-RAG orchestration as a Microsoft Foundry
hosted agent, with the Chainlit UI as a thin BFF speaking Responses, and made
the orchestrator Container Apps optional. ADR-0001 froze two relevant
contracts: hosted modes use **Foundry managed Conversations** as chat history
system of record (no Cosmos in hosted/no-panel), and hosted versions are
**immutable, one version serves 100% of traffic, update = publish new version +
switch, rollback = revert version**.

The canonical Foundry Responses v2 path is implemented in
`Azure/gpt-rag-orchestrator` `develop` (through PR #304). The hosted agent
container explicitly persists user and assistant items into Foundry managed
Conversations.

### Observed blocker (evidence)

In a real `NETWORK_ISOLATION=true` deployment using an immutable image digest:

- Turn 1 works. The managed Conversation Items remain readable through the
  Conversations data API after the hosted compute/version is replaced.
- When the same **top-level Responses `conversation` ID** is reused on the
  replacement version, the Foundry hosted `/responses` gateway returns
  **HTTP 404**. It also 404s after routing back to the original version.
- A fresh request (no reuse of the prior top-level `conversation`) succeeds.

Conclusion supported by the evidence: the 404 is **platform pre-routing /
session-affinity behavior that executes before the application runs**. It is
not missing persisted data — the managed Conversation Items (the system of
record) are intact and readable. Two distinct Foundry constructs are being
conflated:

1. **Managed Conversations** — a durable data-plane store of items. Survives
   compute/version replacement. Readable. System of record (ADR-0001).
2. **The `/responses` gateway session binding keyed by the top-level
   `conversation` parameter** — a control-plane routing/session construct
   coupled to the serving version/compute session. Does **not** survive
   immutable-version or compute replacement.

Because ADR-0001's supported update model *is* version replacement, any
continuity mechanism that depends on construct (2) is structurally broken by
the platform's own update path.

### Security correction (why this ADR was revised)

A previous revision of this ADR chose an application-managed mechanism that
carried a **stable logical managed-Conversation ID in request metadata** and
then had the **hosted agent container** read prior items from managed
Conversations, replay them, run the turn, and append the new items — all inside
the container. An independent security review found this **SECURITY-INVALID**
and it is **withdrawn**:

- The Foundry gateway strips the `Authorization` header, so the **user token
  never reaches the container** (ADR-0001, "User identity and document-level
  security"). Any container-side managed-Conversations read is therefore a
  **service-identity** read.
- Letting a **caller-supplied logical conversation ID** drive a
  **service-identity** read is a textbook **confused-deputy / BOLA (IDOR)**:
  caller A can pass caller B's conversation ID and the hosted service credential
  would read and replay B's history. Per-user isolation is lost.
- It also requires granting the container a managed-Conversations data-plane
  **read** role, breaking the history-blindness invariant reaffirmed in
  ADR-0004.

The corrected model, decided below, moves **all** authorized managed-Conversation
create/read/append/delete into the **authenticated UI BFF** (which holds the end
user's Entra identity and can bind ownership), and reduces the hosted container
to a **stateless, history-blind** compute that receives complete bounded ordered
Responses input and returns output. This is consistent with ADR-0004's
owner-bound, fail-closed contract and its OQ-OWN read-mechanism selector.

### Acceptance criteria (from the task)

- Stable logical multi-turn continuity **across compute/version replacement**.
- Canonical Responses interoperability (stateless caller-supplies-input mode).
- **Fail-closed security**: no service-identity read driven by a caller-selected
  ID; no unauthorized cross-user read; no silent success-shaped fallback; a
  read/append failure must **not** silently start a fresh thread.
- **Owner-bound history**: the BFF authenticates the end user and binds
  conversation ownership before any read; non-owner and missing return
  **indistinguishable 404**.
- **History-blind, stateless container**: the hosted container holds **zero**
  managed-Conversations data-plane RBAC (no create/read/append/delete) and
  cannot select server-side history; direct hosted-agent calls stay stateless.
- No Cosmos chat content in hosted/no-panel; if an owner index is needed (Option
  A), only owner-binding **metadata** is stored, never content.
- Delegated OBO / Toolbox retrieval authorization preserved **separately** from
  history ownership (ADR-0001 INV-002, `POST /retrieve` boundary unchanged).
- Managed Conversation items remain the system of record; the BFF reads/appends,
  the container only generates output.

### Affected repositories

- `Azure/gpt-rag-ui` — thin **BFF** (`orchestrator_client.py`, `hosted_agent`
  path). **Owner of continuity**: authenticates the end user, binds conversation
  ownership, reads managed-Conversation history, builds the complete bounded
  ordered stateless Responses input, calls the hosted agent, and appends the new
  turns to managed Conversations. Holds the only end-user token in the hosted
  path.
- `Azure/gpt-rag-orchestrator` — hosted-agent Responses v2 adapter. Reduced to
  **stateless generation**: consume the caller-supplied input items, run the
  turn, return output. **Removes** container-side managed-Conversations
  read/replay/append. Preserves the Toolbox/OBO retrieval path and the
  `POST /retrieve` fail-closed boundary unchanged.
- `Azure/GPT-RAG` (this repo) — App Configuration contract (label `gpt-rag`),
  ADR record, and the `contracts/` continuity/owner-binding schema. Holds all
  **GPT-RAG-specific** history policy.
- `Azure/bicep-ptn-aiml-landing-zone` (**AILZ**) — generic landing-zone infra
  (consumed via the `infra/` submodule). Stays generic: it must **not** encode
  GPT-RAG history policy. Its only obligation here is to ensure the hosted-agent
  identity carries **no** managed-Conversations data-plane role at all — no
  create, read, append, or delete, and no append-only or write-only variant
  either. Zero role, full stop; nothing is assumed or carved out. GPT-RAG-specific
  policy stays in GPT-RAG.

### Prioritized characteristics (measures)

1. **Security fail-closedness / authorization correctness** — no caller-ID-driven
   service read; no cross-user read; non-owner and missing return an
   indistinguishable 404; read/append failure fails closed (no fresh-thread
   masquerade). (Two-user negative tests.)
2. **Continuity durability** — a turn on logical conversation `C` returns prior
   context after the serving version/compute is replaced, with no gateway 404.
   (Binary pass/fail in the isolated topology.)
3. **Container history-blindness** — the hosted-agent identity holds no
   Conversations data-plane read role and cannot select server history. (RBAC
   assertion / infra review; stateless-input contract test.)
4. **Content confinement** — no Cosmos chat content in hosted/no-panel; any owner
   index stores metadata only. (Store-inspection tests.)
5. **Protocol interoperability & operability** — request/response conform to the
   Responses stateless input-items schema; continuity is independent of which
   version is serving and is rollback-safe behind one config switch.
   (Schema conformance + version-swap matrix.)

## Alternatives considered

### Option A: Keep top-level `conversation`; declare a platform blocker

Continue passing the top-level Responses `conversation` ID and document that
cross-version continuity is unsupported until Foundry changes gateway session
behavior.

- Benefits: zero code change; strictly uses the platform's canonical
  server-side threading; honest about the limitation.
- Costs and risks: **fails acceptance**. In the ADR-0001 model, update = new
  version, so every routine update breaks continuity with a raw 404. Users lose
  their thread on ordinary operations, not just incidents.
- Security and identity: unchanged.
- Operational consequences: hosted/no-panel is effectively single-version-only
  for continuity; incompatible with the supported update/rollback path.
- Component compatibility: no change.
- Reversibility: n/a (no change).

### Option B: Container-side replay keyed by a caller-supplied logical Conversation ID (WITHDRAWN — security-invalid)

Carry a stable logical managed-Conversation ID in Responses **request metadata**
and have the **hosted agent container** validate it, read prior items from
managed Conversations, replay them as input, run the turn, and append the new
items — all inside the container using the container/service identity.

- **Rejected on security grounds (confused-deputy / BOLA / IDOR).** The gateway
  strips `Authorization`, so the container has no user token; its
  managed-Conversations read is necessarily a **service-identity** read. Driving
  that read from a **caller-selected** conversation ID lets any caller replay any
  other caller's history. This is the exact anti-pattern ADR-0004 Option C
  rejects.
- It also requires granting the container a managed-Conversations **read** role,
  breaking history-blindness.
- No append-only-that-cannot-read role is assumed to exist; even if it did, it
  would not make the caller-ID-driven **read** safe.
- **Explicit rejection of container replay:** the hosted container must never
  read or select server-side history. Withdrawn; retained here only to record the
  correction.

### Option C: BFF-mediated stateless replay with owner-bound history (chosen)

Move all authorized managed-Conversation **create/read/append/delete** into the
authenticated **gpt-rag-ui BFF**, and make the hosted container **stateless and
history-blind**. Each turn:

1. The BFF **authenticates the end user** (it holds the Entra token) and
   **binds conversation ownership** for the logical conversation **before any
   read**. Ownership is enforced by the mechanism selected under OQ-OWN:
   **`capability`** (default, safe today, **store-free** — a server-issued,
   signed, opaque, owner-bound capability whose embedded `oid` the BFF re-checks
   against the live token before any read; works in **hosted/no-panel with zero
   Cosmos**) or **`delegated`** (native per-user reads, **inert** until live
   OQ-OWN evidence proves per-user enforcement for the precise token/call path).
   A raw caller-selected ID is never accepted. Non-owner, forged/expired
   capability, and missing all return an **indistinguishable 404**. (The
   panel-only **owner index** in Cosmos is used solely for cross-conversation
   *enumeration* when the panel is deployed; it is **not** the continuity
   binding.)
2. On an owner hit, the BFF **reads** the ordered managed-Conversation items and
   builds the **complete, bounded, ordered, stateless Responses input** (bounded
   by an explicit history policy). A read failure **fails closed** (error to the
   user) and must **not** silently start a fresh thread.
3. The BFF calls the hosted agent with a **fresh `/responses` request** carrying
   the full input items — **no** top-level `conversation` param and **no**
   `previous_response_id`. The gateway performs no version-bound pre-routing and
   cannot 404 on a stale session.
4. The **container generates output statelessly** and returns it. It performs
   **no** read, replay, or persist.
5. The BFF **appends** the new user and assistant turns to managed Conversations
   (the SoR), using an **idempotent client turn ID**, under a **one-in-flight-turn
   per conversation** constraint initially. An append failure **fails closed**;
   the turn is not reported as durably persisted.

- Benefits: eliminates the confused-deputy path (no caller-ID-driven service
  read; ownership bound where the user token exists); continuity depends only on
  the durable store, which survives version/compute replacement (proven); keeps
  managed Conversations as SoR; no Cosmos chat content; container stays
  history-blind and stateless; consistent with ADR-0004.
- Costs and risks: the BFF owns threading mechanics (owner-binding, read, bounded
  replay, append), concurrency/idempotency, and a bounded-history policy. Full
  input per turn costs tokens/latency and needs explicit truncation or
  summarization. In `capability` mode the BFF signs/verifies a store-free
  capability (key in Key Vault, rotation via key version, short TTL with rolling
  re-mint; no fine-grained per-capability revocation in no-panel). The panel-only
  owner index, when present, is metadata-only and must stay consistent with the
  SoR (worst case: a 404 or a stale list row, never content disclosure).
- Security and identity: **three concerns kept separate** — (a) **history
  ownership** enforced by the BFF before any read; (b) **delegated OBO/Toolbox
  retrieval authorization** (document-level trimming) carried to Search via the
  existing passthrough, unchanged and independent of history ownership; (c) the
  **identity authenticating the Foundry `/responses` endpoint call**. Carried
  user context (b) is never conflated with the endpoint-call identity (c), and
  neither is treated as a history-ownership claim (a).
- Operational consequences: continuity is independent of the serving version;
  rollback-safe; matches the immutable-version model; **no new always-on compute
  and no store in hosted/no-panel** (continuity uses the store-free capability;
  the owner index exists only when the panel/Cosmos is deployed, for enumeration).
- Component compatibility: coordinated change across gpt-rag-ui (BFF owner) and
  gpt-rag-orchestrator (adapter reduced to stateless generation); one App
  Configuration selector and one `contracts/` schema in Azure/GPT-RAG; AILZ stays
  generic.
- Reversibility: single App Configuration switch; when continuity is off, the
  path degrades to safe **single-turn stateless** behavior, never to an
  unauthorized read.

### Option D: BFF/gateway detects version change and mints a new platform conversation, linking/replaying managed history

Keep the top-level `conversation` for within-version continuity; on detecting a
version change (or a 404), the BFF creates a **new** platform conversation,
replays managed history into it, and maintains a logical→(version, platform
conversation) mapping.

- Benefits: retains the platform's server-side auto-threading within a version.
- Costs and risks: highest complexity. The BFF must reliably detect version
  changes, own extra mapping state, and recover from 404 mid-conversation.
  Still depends on the fragile version-bound session for the common path.
  Concurrent turns during a version swap create races and duplicate/interleaved
  platform conversations. More moving parts on a preview control-plane behavior.
- Security and identity: unchanged, but the added BFF state widens surface.
- Operational consequences: 404-driven recovery is user-visible latency/retry;
  hard to test deterministically against a preview platform.
- Component compatibility: heavier BFF change; adds durable mapping state to a
  component ADR-0001 wants thin.
- Reversibility: moderate; the mapping/recovery logic is not a single switch.

### Option E: `previous_response_id` (or another official lifecycle pointer)

Chain turns with `previous_response_id` referencing the prior `resp_...`.

- Benefits: canonical chaining primitive.
- Costs and risks: same class of failure as Option A. `previous_response_id`
  points to a response object served by a version/session; it is expected to be
  version/compute-bound and does not reference the managed Conversation SoR.
  Does not solve cross-version continuity and arguably worsens SoR alignment.
- Security/operational/compatibility/reversibility: no advantage over A/C.

### Do not change (Option F)

- Benefits: none beyond deferral.
- Costs and risks: ships a hosted/no-panel experience that loses the thread on
  every routine version update; fails acceptance; erodes trust in the mode.

## Decision

Adopt **Option C**. Hosted-mode multi-turn continuity is **BFF-mediated,
owner-bound, and stateless at the container**. The authenticated **gpt-rag-ui
BFF** owns authorized managed-Conversation **create/read/append/delete**: it
authenticates the end user, binds conversation ownership before any read, reads
the ordered items from **Foundry managed Conversations (system of record)**,
builds the **complete, bounded, ordered, stateless Responses input**, calls the
hosted agent with a fresh `/responses` request (no top-level `conversation`, no
`previous_response_id`), and appends the new turns back to managed Conversations.
The **hosted container is history-blind and stateless**: it holds **zero**
managed-Conversations data-plane RBAC and only generates output from the input it
is given. **Container-side replay and any caller-ID-driven service read are
prohibited (Option B withdrawn).**

The **owner-binding mechanism is a selector** consistent with ADR-0004,
defaulting to the safe, **store-free** state so continuity holds in
hosted/no-panel:

- `capability` (**default**): a server-issued, signed, opaque, owner-bound
  capability minted by the BFF from the validated user `oid`
  (`{oid, conversation_resource_id, issued_at, expiry, key_id}`). The BFF
  re-checks the capability `oid` against the live token before any read. Requires
  **no store** (signing key in Key Vault, provisioned like `AUDIT-HMAC-KEY`), so
  it works in **hosted/no-panel with zero Cosmos**. Safe today; no dependency on
  an unproven platform capability.
- `delegated` (**target, gated**): native per-user managed-Conversations reads as
  the user. **Inert** until the live **OQ-OWN** two-user experiment proves actual
  per-user enforcement for the precise token/call path; only then may it be
  enabled.

A raw caller-selected conversation ID is **never** accepted as a read key. The
panel-only **owner index** (Cosmos) exists solely for cross-conversation
**enumeration** when the panel is deployed and stores **only** owner-binding
metadata (principal ID, conversation ID, title, timestamps) — **never** message
content. No Cosmos chat content exists in hosted/no-panel.

### Identity separation (non-negotiable)

Three distinct identities/authorizations must not be conflated:

1. **History ownership** — enforced by the BFF against the authenticated end user
   before any read; non-owner and missing both return **404**.
2. **Delegated OBO/Toolbox retrieval authorization** — the user context carried
   to Foundry IQ/Search for native document-level trimming (ADR-0001 target
   path). Unchanged by this ADR and independent of history ownership.
3. **Foundry `/responses` endpoint-call identity** — whatever credential
   authenticates the BFF→gateway call. Never treated as, or derived from, the
   carried user context (2) or a history-ownership claim (1).

### App Configuration contract (label `gpt-rag`, owned by Azure/GPT-RAG)

Defaults preserve safe behavior; enabling requires explicit evidence gates.
These align with ADR-0004's panel keys and the `POST /retrieve` idiom.

- `HOSTED_CONTINUITY_ENABLED` (default `false`) — when `false`, the hosted path
  is **single-turn stateless** (no server history, safe). When `true`, the BFF
  performs owner-bound read + bounded replay + append.
- `HOSTED_CONVERSATION_OWNER_BINDING` (default `capability`; alt `delegated`) —
  selects the owner-binding mechanism; `delegated` is inert until the validation
  gate is set. Same key as ADR-0004.
- `HOSTED_CONVERSATION_CAPABILITY_KEY` / `HOSTED_CONVERSATION_CAPABILITY_KEY_ID` /
  `HOSTED_CONVERSATION_CAPABILITY_TTL_SECONDS` — Key Vault-referenced signing key
  (provisioned like `AUDIT-HMAC-KEY`), active key version for rotation, and
  capability lifetime with rolling re-mint. Present in **all** modes; no store.
- `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED` (default `false`) — the **OQ-OWN
  evidence gate**, mirroring `HOSTED_RETRIEVAL_INV_002_VALIDATED`. Continuity in
  `delegated` mode stays disabled (safe capability/stateless) unless this is
  `true`.
- `HOSTED_CONVERSATIONS_TOKEN_AUDIENCE` — managed-Conversations query-token
  audience for `delegated` mode (analogous to `HOSTED_RETRIEVAL_TOKEN_AUDIENCE`);
  required only when `delegated`.
- `HOSTED_HISTORY_MAX_ITEMS` / `HOSTED_HISTORY_MAX_TOKENS` — explicit bounded
  history policy for the replayed input.
- `HOSTED_HISTORY_TRUNCATION` (default `drop_oldest`; alt `summarize`) — bound
  strategy when the policy limit is exceeded.

If a typed field is warranted (the continuity/capability envelope), it is added
under `contracts/` and byte-pinned like `audit-event-v1`. **AILZ carries no
GPT-RAG history policy**; it only guarantees the container identity holds no
Conversations read/write role and no capability signing key.

### Honest scope statement (protocol vs. continuity)

We do **not** invent a platform contract. In the current Foundry preview you
cannot simultaneously have (a) reliance on the platform's server-side
`conversation` / `previous_response_id` session threading and (b) stable
continuity across the platform's own immutable-version replacement. Therefore:

- **Preserved and canonical:** the Responses **request/response wire contract**,
  specifically the stateless "caller supplies input items" mode, which is a
  supported canonical usage of Responses. Interoperability of the message shape
  is intact.
- **Explicitly out of supported scope (preview / platform-limited):** durable
  cross-version continuity via the platform's server-side stateful
  `conversation` auto-loading and `previous_response_id` chaining. These are
  documented as **not durable across immutable-version replacement** and are not
  the GPT-RAG continuity mechanism.
- **Explicitly rejected:** container-side history read/replay of any kind, and
  any service-identity read driven by a caller-selected conversation ID.

## Consequences

### Positive

- No confused-deputy/BOLA path: the container never reads history, and no
  caller-selected ID ever drives a service-identity read.
- Continuity survives compute/version replacement and rollback, matching the
  ADR-0001 update model, because it depends only on the durable SoR.
- Managed Conversations stays the single system of record; the BFF reads/appends,
  the container only generates; no Cosmos chat content in hosted/no-panel.
- History ownership, delegated retrieval authorization, and endpoint-call
  identity remain cleanly separated; INV-002 / `POST /retrieve` untouched.
- Safe under OQ-OWN uncertainty: **store-free `capability`** ships now (works in
  hosted/no-panel with zero Cosmos); `delegated` is a config flip after live
  proof. Reversible behind one App Configuration switch.

### Negative or accepted

- The BFF owns threading mechanics (owner-binding, read, bounded replay, append),
  concurrency/idempotency, and the bounded-history policy — more logic in a
  component ADR-0001 wants thin.
- Per-turn token/latency cost of sending full bounded input; requires the
  explicit truncation/summarization bound.
- In `capability` mode the BFF signs/verifies a store-free capability (Key
  Vault-backed key, rotation via key version, short TTL + rolling re-mint); no
  fine-grained per-capability revocation in no-panel (bounded by TTL + rotation).
  The panel-only owner index, when present, is metadata-only and must stay
  consistent with the SoR (at worst a 404 or stale list row, never content
  disclosure).
- Gives up the platform's server-side auto-threading convenience while the
  preview limitation stands.
- Reconciled with ADR-0004: managed-Conversation create/read/append/delete and
  ownership belong to the **BFF**, not the container; the container is stateless
  with zero Conversations RBAC and no signing key.

## Adoption and migration

Coordinated, ordered change (compatible-commit discipline per AGENTS.md):

1. **Azure/GPT-RAG** — freeze the App Configuration contract (label `gpt-rag`):
   add `HOSTED_CONTINUITY_ENABLED`, `HOSTED_CONVERSATION_OWNER_BINDING`,
   `HOSTED_CONVERSATION_CAPABILITY_KEY` (Key Vault ref, provisioned like
   `AUDIT-HMAC-KEY`), `HOSTED_CONVERSATION_CAPABILITY_KEY_ID`,
   `HOSTED_CONVERSATION_CAPABILITY_TTL_SECONDS`,
   `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED`,
   `HOSTED_CONVERSATIONS_TOKEN_AUDIENCE`, `HOSTED_HISTORY_MAX_ITEMS`,
   `HOSTED_HISTORY_MAX_TOKENS`, `HOSTED_HISTORY_TRUNCATION`, all defaulting to the
   safe state (continuity off, `capability`, validation gate `false`). Add the
   `contracts/` continuity/capability envelope schema + `.sha256` if a typed field
   is warranted. Publish this ADR. No runtime behavior change yet.
2. **gpt-rag-orchestrator** — reduce the hosted-agent Responses v2 adapter to
   **stateless generation**: consume the caller-supplied bounded ordered input
   items and return output. **Remove** any container-side managed-Conversations
   read/replay/append and any dependency on the top-level `conversation` /
   `previous_response_id` for continuity. Emit `audit-event-v1` for
   turn-generated and legacy-404-detected (metadata only). No Conversations
   read/write role and no capability signing key on the container identity.
3. **gpt-rag-ui** — in the `hosted_agent` BFF path: authenticate the end user;
   bind conversation ownership (`capability` default — mint on create, verify
   signature + expiry + `oid` equality) before any read; read ordered items from
   managed Conversations; build the complete bounded ordered stateless Responses
   input; call the hosted agent with a fresh `/responses` request (no top-level
   `conversation`, no `previous_response_id`); append the new user/assistant turns
   to managed Conversations with an idempotent client turn ID; enforce one
   in-flight turn per conversation; re-mint a fresh capability on success; fail
   closed on read or append failure (no fresh-thread masquerade). Non-owner,
   forged/expired capability, and missing → 404.
4. **AILZ (`bicep-ptn-aiml-landing-zone`)** — no GPT-RAG history policy. Confirm
   (infra/RBAC review) the hosted-agent identity carries **no**
   managed-Conversations data-plane read/write role and **no** capability signing
   key; Conversations RBAC and the signing key belong to the **BFF identity**
   only.
5. Revalidate in both topology classes (Basic and network-isolated with private
   endpoints/private ACR), run the negative security suite (below) **including
   no-panel/zero-Cosmos continuity**, then update `manifest.json` pins for
   gpt-rag-orchestrator and gpt-rag-ui together.

Migration boundaries: no backfill required. Existing managed-Conversation items
are read by the BFF via owner-bound lookup; only the read/append **owner** and
the routing mechanism change. Classic mode is unaffected. In `capability` mode a
conversation without a live capability (e.g., browser/session loss in no-panel)
starts fresh — an accepted, safe default (no content disclosure); the optional
panel adds enumeration-based recovery. Backfill of panel owner-index rows, if
desired, is a separate metadata-only migration.

Rollback: flip `HOSTED_CONTINUITY_ENABLED` off (path degrades to safe single-turn
stateless) and revert the coordinated manifest pin. Because managed Conversations
is SoR, the capability is stateless, and any owner index is metadata only, no
chat-content migration is needed either direction; rotating
`HOSTED_CONVERSATION_CAPABILITY_KEY_ID` invalidates outstanding capabilities and
owner-index rows can be dropped.

## Negative security tests (must pass before enable)

- **NST-1 Cross-user read (BOLA/IDOR):** user B requests continuity/history on
  user A's conversation ID → **404**, indistinguishable from a missing ID; no
  managed-Conversations read is issued on A's items. (Reuses the INV-002 two-user
  harness.)
- **NST-2 No container read path:** infra/RBAC assertion that the hosted-agent
  identity has **no** Conversations data-plane read/list/append role; a wire test
  asserts the container receives only caller-supplied input and issues no
  Conversations read.
- **NST-3 No caller-ID-driven service read:** any code path where a caller-supplied
  conversation ID reaches a service-identity Conversations read without a prior
  owner hit is a failing test (static + integration).
- **NST-4 Fail-closed on read/append failure:** injected read failure and injected
  append failure each return an error and do **not** start a fresh thread or
  stream a success-shaped completion.
- **NST-5 Delegated mode stays inert:** with `HOSTED_CONVERSATION_OWNER_BINDING=delegated`
  but `HOSTED_CONVERSATION_OWNER_BINDING_VALIDATED=false`, continuity does not
  perform a native delegated read (safe capability/stateless), never a service
  read.
- **NST-6 No content leakage to Cosmos/telemetry:** after turns, assert no message
  body or document content in Cosmos (owner index metadata only) or in
  `audit-event-v1`.
- **NST-7 Capability forgery/theft/replay:** a capability with a bad signature,
  expired TTL, retired `key_id`, or `oid` not matching the live token → **404**
  (uniform with missing); a stolen capability presented without the matching
  authenticated `oid` token is rejected; rotating `..._KEY_ID` invalidates all
  outstanding capabilities.
- **NST-8 No-panel/zero-Cosmos continuity:** with the panel undeployed and no
  Cosmos, a multi-turn conversation stays continuous within TTL using the
  capability alone; no owner index or Cosmos client is instantiated.

## Operational behaviors

- **Concurrency:** one in-flight turn per conversation initially; concurrent turns
  are serialized or rejected deterministically.
- **Idempotency:** client turn IDs deduplicate retried appends; a retry never
  double-appends.
- **Bounded history:** replay is bounded by `HOSTED_HISTORY_MAX_ITEMS` /
  `HOSTED_HISTORY_MAX_TOKENS` with `HOSTED_HISTORY_TRUNCATION`; policy is explicit
  and observable.
- **Failure semantics:** read failure and append failure both fail closed;
  gateway 404 on a stale session cannot occur (no top-level `conversation`).
- **Telemetry:** `audit-event-v1` records owner-bind result, read, append,
  turn-generated, and legacy-404-detected — **metadata only**, correlation IDs
  only, no conversation body or document content.

## Compliance verification (fitness functions)

- **FF-1 Continuity across replacement:** turn on version A, replace with a new
  immutable digest (version B), then a turn on the same logical conversation
  returns prior context with **no gateway 404**; repeat after rolling back to A.
  Automated integration test in the isolated topology.
- **FF-2 No version-bound session dependency:** contract/wire test asserts the BFF
  sends the full stateless input and **never** the top-level `conversation`
  parameter or `previous_response_id` for continuity.
- **FF-3 History-blind stateless container:** RBAC assertion that the hosted-agent
  identity holds no Conversations data-plane role; wire test asserts the container
  issues no read/append and only generates from supplied input.
- **FF-4 Owner gate before read:** a `(caller, conversation_id)` with no valid
  owner binding (no capability match / signature / `oid` equality) returns
  **404**; a caller ID never reaches a managed-Conversations read without a prior
  owner-binding validation.
- **FF-5 Managed Conversations is SoR / no Cosmos chat:** after a turn, items are
  readable via the Conversations data API; hosted/no-panel constructs history
  solely from it; assert no Cosmos chat client is instantiated and any owner index
  holds metadata only.
- **FF-6 Fail-closed read/append:** read or append failure returns an error and
  does **not** start a fresh thread or stream a success-shaped completion.
- **FF-7 Concurrency & idempotency:** concurrent turns on one conversation yield
  deterministic ordering; a retried turn with the same client turn ID does not
  double-append.
- **FF-8 Retrieval identity preserved & separate:** reuse ADR-0001 INV-002
  two-user negative retrieval test; per-user/group trimming via Toolbox
  passthrough unchanged and independent of history ownership.
- **FF-9 Canonical wire conformance:** requests/responses validate against the
  Responses schema/SDK types (stateless input-items mode).

## Documentation impact

Update the hosted-agent operator page on the `docs` branch: describe BFF-mediated
owner-bound continuity, the container's stateless/history-blind role, the
`capability` (store-free default) vs `delegated` selector and its OQ-OWN gate, the
capability lifecycle (mint/verify/rotate/TTL), the bounded-history policy and its
App Configuration keys, the fail-closed 404/error semantics, and
an explicit preview note that platform server-side `conversation` /
`previous_response_id` threading is not durable across version replacement.
Explicitly document that container-side history read/replay is prohibited.

## Review trigger

Reassess when any of the following occurs:

- **OQ-OWN resolves:** live evidence proves (or denies) native per-user enforcement
  for delegated managed-Conversations reads on the precise token/call path — only
  then may `delegated` be enabled and the validation gate set.
- Foundry changes `/responses` gateway session/pre-routing so a top-level
  `conversation` survives immutable-version/compute replacement, or provides an
  official rebind/continuation lifecycle.
- Foundry changes managed-Conversations identity/RBAC, header propagation, ordering,
  optimistic concurrency, or `store` semantics affecting read/append design.
- Hosted agents leave preview.
- Any NST or FF regresses in validation or production, or a security review reports
  a cross-user or service-identity read path.

## Open questions

- **OQ-OWN (blocking `delegated` default):** does managed Conversations accept a
  **delegated user token** and enforce per-user/owner authorization for the exact
  BFF token/call path? If yes → `delegated` may supersede `capability` for reads
  and the owner index is not needed for reads. If no → the store-free
  `capability` binding stays and container-side/service-ID reads remain
  prohibited. Live two-user experiment in progress; design is safe regardless
  (`capability` default, zero Cosmos in no-panel).
- **OQ-1 (ordered read + concurrency):** confirm the managed-Conversations data
  API (used by the BFF, not the container) supports ordered read and an
  optimistic-concurrency / turn-sequence primitive sufficient for FF-7. If not,
  the single-active-turn constraint is the contract.
- **OQ-2 (double-store):** confirm the container's stateless generation with
  `store=false` on the response does not itself persist items, so the BFF is the
  sole append path and no double-store occurs.
- **OQ-3 (bounded-history policy):** finalize `HOSTED_HISTORY_MAX_ITEMS` /
  `HOSTED_HISTORY_MAX_TOKENS` defaults and truncation-vs-summarization ownership.
- **OQ-4 (owner stamp durability):** confirm the create path durably records the
  owner principal (and that it survives version replacement) so ownership is
  attributable without content inspection — shared with ADR-0004 OQ-611-OWNERSTAMP.
- **OQ-CAP (capability sufficiency):** confirm the signed capability envelope
  (`{oid, conversation_resource_id, issued_at, expiry, key_id}`) plus live-token
  `oid` equality is sufficient owner binding for reads/appends with no store, and
  finalize TTL/rotation defaults — shared with ADR-0004 OQ-611-CAP.
- **OQ-REVOKE (revocation granularity):** in no-panel there is no per-capability
  revocation (only TTL expiry + key rotation as bulk revocation); confirm this is
  acceptable or require the panel/owner-index for fine-grained revocation —
  shared with ADR-0004 OQ-611-REVOKE.
- **OQ-7 (cancel/background lifecycle):** define cancel/partial-turn behavior;
  recommend synchronous streaming with completed-turn-only append for the first
  release, so a cancelled turn appends nothing.
