# ADR-0006: Preserve retrieval authorization, disable unsupported profile collection, and retain best-effort classic history

**Status:** Implemented in candidate ea61bc7; independent adoption review and live acceptance pending<br>
**Date:** 2026-09-09<br>
**Owners:** GPT-RAG platform and orchestrator implementation/review teams

## Context and authority

This decision completes the architectural choices for orchestrator P3/P4/P5 in
[Azure/GPT-RAG#681](https://github.com/Azure/GPT-RAG/issues/681), supplementing
[ADR-0005](ADR-0005-python-quality-gates-and-ui-package.md), not approving
exception records or declaring the issue complete.

The user authorizes the agent to choose the remaining options and complete the
issue, and suggests application-identity fallback with clear logs or user
disclosure. Preserving actual user/document authorization is a repository
constraint; disclosure alone does not satisfy it. The agent selects suspension
of unverified automatic profile access/collection and explicit best-effort
classic SSE history without queues or migration. Those are agent-selected
decisions under the user's delegation, not separate explicit user selections.
This is not independent maintainer approval or permission to bypass policy,
activate unreviewed exceptions, merge, change settings, deploy, or release.

Operators need predictable failure semantics; users must not receive another
principal's documents or profile because a dependency failed. Priorities:

1. Authorization: zero protected records, citations, or images exposed in
   negative-principal and missing-OBO tests.
2. Privacy: zero automatic profile-extraction model calls, profile mutations,
   or profile writes from maintained chat callers after this change.
3. Failure truth: every failed required retrieval reaches the turn/transport
   error boundary; no failure is reported as a successful empty search.
4. Compatibility: deliberate service-only retrieval and existing SSE framing,
   history partitions, hosted statelessness, and versioned wire schemas remain.
5. Operability/cost: safe diagnostics distinguish disabled, denied, empty,
   unconfirmed, and confirmed outcomes; no new Azure resources, model calls,
   durable workers, or configuration keys.

### Executable evidence inspected

Decision-time sources were parent `f376e1c` and orchestrator
`25f1986bfcf3a2b5f6057942a17fe7763e41c934`. Implementation is committed at
`ea61bc7cd7b2ac21c957bee5db959337fedd8760`; source and regression evidence were
reviewed without treating that agent review as independent maintainer approval.
Final-head CI run `34300904165` passed tests, frontend, typing and architecture,
but lint, exceptions, policy and the aggregate gate failed. The source inventory
below describes the decision-time defects, not remaining candidate behavior.

- `specs/001-python-module-boundaries/tasks.md`, `quickstart.md`, and
  `contracts/quality-gates.md`: six P3 originals, seven partial P4 originals,
  one classic P5 original remain; functional receipts do not activate quality
  policy or prove live authorization/recovery.
- `manifest.json` still pins orchestrator `v4.1.1` / `9b64a5b`, UI `v2.6.2` /
  `f59cca9`, ingestion `v2.7.3` / `38a3955`, and AILZ `v2.5.1` / `9cc5859`.
  The candidate worktree is not the shipped manifest combination.
- `main.parameters.json` retains network-isolation topology, App Configuration
  label `gpt-rag`, Foundry IQ preview API selection and separate security-field
  filtering configuration. No service preference becomes a new requirement.
- `contracts/README.md` describes the versioned audit, hosted ownership, and
  strict panel contracts. Hosted ownership is distinct from retrieval OBO.
  None of those schemas or their integrity hashes changes here.
- `src/orchestration/orchestrator.py`: `create` logs and continues after token
  assignment failure; classic documents have `principal_id`, not `user_id`.
  `_start_conversation_persistence` takes deep copies and retains tasks;
  `_persist_conversation` orders update after confirmed create and distinguishes
  `None` from success. `stream_response` protects primary outcome/audit cleanup.
- `src/strategies/{search_context_provider,foundry_iq_context_provider,
  multimodal_search_context_provider}.py`: token acquisition failures can
  continue without delegated authorization; Foundry's stricter handling is
  conditional on MCP. Multimodal explicitly removes the header and retries.
- The three `_create_search_provider` callers in `maf_lite_strategy.py`,
  `maf_agent_service_strategy.py`, and `multimodal_strategy.py` use
  `allow_anonymous=True` for non-MCP OBO acquisition regardless of strict
  request mode. Required policy cannot be inferred from callback presence.
- `connectors/search.py::build_conversation_filter` selects conversation and
  shared chunks, not user ACLs. `connectors/foundry_iq.py` distinguishes Pattern B
  security-field filtering from native source authorization; remote sources
  require OBO. A Pattern B flag alone proves no equivalent coverage.
- `BaseAgentStrategy._get_profile_user_id` rejects absent, non-string, blank,
  and trimmed `default_user`; it returns other values verbatim. This is a
  negative key guard, not authenticated ownership.
- `UserProfileMemory.invoked` schedules extraction. `_extract_and_update_profile`
  passes `chat_options` and reads `result.value`;
  `OpenAIChatClient.get_response` consumes `options` and returns `ChatResponse`
  text. Existing real-adapter caller tests show an ineffective extraction can
  still send a model request. Fixing spelling/parsing would reactivate collection.
- Three strategy load/save helpers address `user_profile_{user_id}` without
  proving a trusted owner binding. Lite/multimodal schedule post-flow save;
  service uses `_persist_user_memory`. Existing records can contain personal data.
- `main.py::orchestrator_endpoint` validates bearer identity when configured,
  but starts with body `user_context`; anonymous branches use `setdefault`.
  Body identity fields, API keys, and Dapr authentication therefore cannot be
  treated as trusted per-user ACL/profile provenance.
- `api/turn_sse.py::serialize_turn_event` already serializes safe turn errors.
  `tests/test_profile_caller_safety.py` and
  `tests/test_conversation_persistence_boundaries.py` exercise maintained
  framework/adapter and detached-history callers with mocked remote services.

## Alternatives considered

| Option | Benefits | Costs, security and operational consequences |
| --- | --- | --- |
| A: Fail closed where user authorization is unproven; suspend automatic profiles; retain best-effort SSE (selected) | Small runtime correction; no added collection or Azure resources; reversible code changes | Some previously permissive retrieval/profile behavior becomes unavailable; history loss remains possible |
| B: Implement equivalent application-side ACL enforcement, authenticated legacy-profile binding and consented extraction, plus awaited history writes | Potentially preserves personalized operation and stronger write acknowledgement | Viable separate project, but requires source-complete ACL and revocation evidence, trusted identity mapping and collection approval; adds latency and coupled security tests; awaiting writes still does not provide durable recovery |
| C: Disable all retrieval and all history until a new durable architecture exists | Simple conservative emergency posture | Unnecessarily removes deliberate service-only functionality; queue/storage/network/RBAC and migration costs are not justified by this issue |
| Do not change | No compatibility interruption or implementation cost | Silent privilege weakening remains possible; ineffective extraction still sends data; incomplete P3/P4 and ambiguous P5 acceptance persist |

All options must respect managed identity/service RBAC, private network paths,
and component release pins. A managed identity authenticates the application,
not the user. Logging does not implement authorization. Option B is not made
safe merely by changing frameworks or Azure services.

## Decision

### P3: explicit request-local retrieval authorization

Implement an internal, typed request-local mode (`user_required` or
`service_only`); this is not a new external setting or wire schema. Resolve it
at trusted composition and pass it explicitly to all three providers. Never
downgrade it after a token/context error. Conservative default for an omitted
provider mode is `user_required`; maintained service-only callers must opt in.

For the maintained classic path, a nonblank incoming user assertion, strict
`ALLOW_ANONYMOUS=false`, or a selected source requiring user credentials makes
the mode `user_required`. A supplied invalid assertion is not anonymous.
`service_only` is retained only for an intentional anonymous/no-user-token
route allowed by existing configuration and sources which support service
authorization. Authenticated requests do not become service-only just because
`ALLOW_ANONYMOUS=true`. Unknown or contradictory mode is rejected.
Hosted/source-specific credential requirements remain at least as strict.

| Mode / event | Retrieval action | Observable outcome |
| --- | --- | --- |
| Retrieval intentionally disabled/not selected | No retrieval call | Existing ordinary-chat behavior; not an authorization fallback |
| `service_only`, allowed source | Service identity, same conversation/source scoping; no OBO attempt required | Safe mode diagnostic; no claim of user trimming |
| `user_required`, valid OBO available | Forward delegated authorization with service transport credentials as required | Existing source-level user ACL enforcement; normal results/empty result |
| `user_required`, missing/blank token, callback absent, returns `None`, or raises | No search/retrieve call unless the equivalent-ACL row below is satisfied | Fail closed through existing safe turn/HTTP error path |
| User-token/context assignment fails | Abort creation before strategy invocation; never reuse old context | Safe diagnostic and existing public failure mapping |
| Search/retrieve rejects delegated request or fails mid-enumeration | Propagate failure; discard partial retrieval context; no stripped-header retry | Safe required-retrieval error; no success/empty-context substitution |
| Proven equivalent user ACL enforcement, application fallback requested | Only an explicitly implemented, reviewed source-complete path may run | Both safe operator diagnostic and user-visible disclosure required |
| Unknown policy, incomplete ACL proof, native source requiring OBO, or mixed KB with any uncovered source | No application fallback | Fail closed |
| Any mode, successful retrieval returns zero authorized records | Return empty context | Empty is distinct from failure |
| Cancellation | Propagate cancellation | No retry or completion claim |

**The equivalent-ACL fallback row is not enabled by this implementation.**
No inspected source/caller combination demonstrates its equivalence. It is an
allowed future option, not an existing capability or a Boolean bypass. Before
enabling it, prove authenticated tenant/principal/group provenance, full source
and document coverage (including shared/upload chunks and images), deny-by-
default behavior for missing/malformed ACLs, revocation/group-overage handling,
and filtering before content reaches model/citation/image download. Prove the
same denial results as delegated authorization for adversarial principals.
No source silently drops out to create a misleading partial answer. Disclosure
must reach the user via a tested compatible transport as well as sanitized
logs; logs alone are insufficient. Revisit this ADR before enabling that row.

Minimum P3 binding by original finding (do not rename original IDs):

| Original finding | Implementation boundary and disposition |
| --- | --- |
| `legacy-orchestrator-token-setter` | `orchestration/orchestrator.py::Orchestrator.create`: propagate setter failure; do not run the strategy. Test assignment of `None` clears prior request state too. |
| `legacy-text-provider-obo-service-fallback` | `SearchContextProvider.invoking`: enforce mode before Search; remove acquisition-error continuation for required users. |
| `foundry-context-obo-compatibility` | `FoundryIQContextProvider.invoking`: enforce the same policy for MCP and non-MCP; retain stricter MCP/native source gates and separate incoming-token handling. |
| `legacy-multimodal-obo-service-fallback` | `MultimodalSearchContextProvider.invoking`: same preflight; no unauthorized document/image access. |
| `legacy-multimodal-retry-without-obo` | Same method: remove authorization-header-removal retry; preserve normal failure classification. Verify actual delegated value reaches the SDK, never a diagnostic redaction placeholder. |
| `multimodal-retry-empty-context` | Same method: failure propagates, including iterator failure; only successful zero records yield empty context. Do not retain a dead retry handler solely for inventory compatibility. |

Update `_create_search_provider` in all three strategy files: derive mode
before token acquisition and propagate it to text/Foundry/multimodal providers;
do not force anonymous acquisition for non-MCP. Keep corrected
single-agent request-context propagation unchanged and regression-tested.
A small connector-layer policy helper is permissible; it must not import
API/application modules or duplicate JWT/OBO implementations.

### P4: explicit no-collection disposition, not accidental adapter failure

Disable automatic extraction for **all maintained callers**, regardless of
adapter class or a model's ability to return valid JSON. Make
`UserProfileMemory.invoked` a truthful no-op and ensure direct
`_extract_and_update_profile` entry cannot call the model or mutate data.
Retain compatible callable surfaces as needed; `flush` must not invent work.
Do not repair `chat_options`/`options`, parse `result.text` into a profile, add
a feature flag to re-enable extraction, or rely on adapter exceptions.

For final closure also suspend automatic profile load/save/context/welcome in
the three maintained strategies: the existing negative guard has no trusted
legacy-key binding. Keep the guard's existing rejection and verbatim semantics
as a compatibility helper, but it must not confer eligibility for storage.
Use a separate disabled eligibility decision in maintained callers; clear
cached `_user_memory` on disabled/ineligible turns and do not allocate a
memory-only model client or schedule `_post_flow_cleanup`.
Do not set `conversation.user_id = principal_id`, trim/rekey valid legacy
keys, use request `user_id`, or accept anonymous body principals as owners.

This deliberately sacrifices automatic legacy-profile personalization until a
trusted provenance contract exists, rather than claiming old arbitrary keys
are authenticated. Existing Cosmos profile documents remain untouched:
no read/modify/write refresh, deletion, reindex, partition move, or migration.
Profile models/serialization and compatibility load/save helpers may remain,
but are not a supported user-facing bypass. Ordinary conversation history
writes are separate and remain enabled under P5.

Future use of an existing profile requires a server-authenticated principal
and a demonstrable owner-to-existing-key association checked before **any**
profile read, context injection, or write. Key validity, string equality with
an untrusted claim, existence of a record, or conversation ownership alone
does not establish that association. No such binding is introduced here.
Restoring even read-only personalization requires reviewed provenance evidence;
restoring extraction additionally requires explicit collection authorization,
retention/privacy requirements, and adapter-contract tests. Hosted memory
remains off, and multimodal does not become hosted-eligible.

Emit bounded, safe diagnostics such as `profile_extraction_disabled` and
`profile_access_disabled_unverified_binding` through configured logging,
without raw keys, principal identifiers, messages, or exception payloads.
Do not announce successful collection, "profile saved", or a welcome based
on inaccessible data. Revise prompts/session-summary wording so ordinary chat
does not promise that it is learning or persisting new profile information.

This disposes all seven original P4 findings:

- `optional-profile-background-extraction`:
  `strategies/maf_plugins/user_profile_memory.py::UserProfileMemory.invoked`,
  `_extract_and_update_profile`, `flush`.
- `maf-lite-optional-profile-load` / `maf-lite-optional-profile-save`:
  `MafLiteStrategy._ensure_user_memory`, `initiate_agent_flow`,
  `_post_flow_cleanup`, `_load_user_profile`, `_save_user_profile`.
- `maf-service-optional-profile-load` / `maf-service-optional-profile-save`:
  `MafAgentServiceStrategy._create_user_memory`, `_persist_user_memory`,
  `initiate_agent_flow`, `_load_user_profile`, `_save_user_profile`.
- `multimodal-profile-load-compatibility` /
  `multimodal-profile-save-compatibility`: corresponding memory initialization,
  load/save, `initiate_agent_flow`, and post-flow cleanup in
  `strategies/multimodal_strategy.py`.

Retained helper tests must still distinguish confirmed writes, `None`,
read/write errors, and cancellation; absence of a maintained caller is not
blanket approval for broad handlers. Change real-caller tests that currently
expect ineffective extraction or arbitrary-key personalization to assert zero
collection/access instead; do not simply delete their coverage.

### P5: explicitly best-effort classic history

Select best-effort SSE for `legacy-detached-conversation-persistence` / H5.
Successful SSE means the response was streamed, **not** that history was
committed. Detached tasks can be lost at process termination; simultaneous
requests can race; there is no global pending-task bound, shutdown drain,
cross-request serialization, durable retry, queue, or recovery guarantee.

Keep existing retained task ownership, independent pre-scheduling deep copies,
create-before-update dependency, safe failure logging, unconfirmed-result
handling, and cleanup that preserves stream exceptions/cancellation.
An unconfirmed create must suppress its dependent update. Do not add write
retries or turn success into a persistence acknowledgement. Do not attempt
an SSE error after the stream has already closed for a detached write failure.
Operator diagnostics and documented persistence semantics are the applicable
failure surface; required retrieval failure remains a primary stream error.

Minimum P5 runtime change is **none** if existing boundary tests continue to
pass at the implementation head. H5's remaining work is explicit contract/docs,
review and pinned evidence, not a durability rewrite. This does not weaken
managed-conversation reconciliation or hosted ownership contracts.

## Compliance verification and implementation handoff

Only orchestrator runtime/tests need implementation; parent owns this ADR and
later release composition. UI/ingestion need compatibility validation, not a
runtime change for the selected policy. Documentation remains in the platform
`docs` branch, not this worktree.

Use existing pytest tooling, beginning with:

```text
pytest -q tests/test_required_retrieval_failures.py tests/test_context_provider_boundary_dispositions.py tests/test_legacy_runtime_boundary_dispositions.py tests/test_primary_strategy_failure_boundaries.py
pytest -q tests/test_profile_caller_safety.py tests/test_user_profile_memory_boundaries.py tests/test_profile_persistence_boundaries.py
pytest -q tests/test_conversation_persistence_boundaries.py tests/test_conversation_history.py tests/test_audit_lifecycle.py tests/test_orchestration_turn.py
```

Extend these suites and the three strategy suites; then run `pytest -q` and
the protected-base quality command documented in spec quickstart (including
orchestrator `python -I -S` startup requirements). The command list is the initial implementation handoff; final evidence is
recorded in the current receipt in `specs/001-python-module-boundaries/tasks.md`.

Acceptance at the actual implementation head:

1. Table-drive mode/token/error cases through real provider factories and
   maintained strategy, turn and HTTP/SSE callers, not just a policy helper.
   Assert zero downstream calls for missing required authorization, including
   absent callback and `None` results, and zero alternate search on rejection.
   Test MCP/non-MCP, strict/anonymous config, token present/absent, keyword/
   hybrid, successful empty results and cancellation/partial output.
2. Prove no prior user's token/context survives setter failure or sequential
   user changes. Untrusted body fields never establish per-user authorization.
   At authenticated boundaries retain existing 401/403 behavior; after SSE
   starts retain safe error-event framing, not an invented status/schema.
3. Assert zero returned protected text/citations/images for unauthorized
   principals. Source-enforced ACLs require separate live tests: mocked SDK
   headers do not prove Azure permission filters or remote source behavior.
   Test conversation filters alongside, not instead of, document authorization.
4. Through the real framework hooks and direct-model adapter, assert zero
   extraction calls/tasks/mutations and zero profile Cosmos reads/writes for
   all maintained callers, including a syntactically valid legacy key, cached
   prior profile, spoofed request identity, new classic principal-only document,
   and hosted mode. Preserve ordinary chat/history and guard verbatim behavior.
   A model returning perfect extraction JSON must still not be called.
5. P5 tests must allow SSE to finish while a write is blocked; verify independent
   snapshots, strong task retention/release, create failure/`None` suppressing
   update, update failure/`None` never logging success, and primary error/
   cancellation plus audit cleanup preserved. Test draining is not production
   durability. Make no restart-recovery assertion.
6. Seed synthetic sensitive markers in tokens, provider failures and profiles;
   new diagnostics and public failures must not expose them. Do not add fields
   or enum values to versioned audit/panel schemas without separate contract work.
7. Reconcile exact changed/removed handler bindings in the component PR through
   normal review. The six/seven/one originals can become functionally resolved
   only with matching source and tests; no exception activation, invented
   approval, baseline weakening or inventory-ID churn follows from this ADR.

## Adoption, migration, rollback and documentation

Implement against the inspected orchestrator candidate in a reviewed PR,
record exact before/after SHAs and fresh test results, and update coordinated
docs (existing draft context: orchestrator #346 and platform docs #688 per
specs). Do not inherit older test counts as final-byte evidence.

Document retrieval modes and failed-OBO behavior, disabled automatic profile
collection **and personalization**, unchanged legacy records/no key migration,
and the distinction between streamed response and persisted history. Search
the docs branch's orchestrator, authentication/retrieval, history and
troubleshooting pages and examples for conflicting claims; update all matches
and run its strict build. Exact page paths require docs-owner verification;
that worktree was not inspected or edited here.

No data, configuration, RBAC, network, deployment, or shared wire migration.
Basic and private-network deployments retain existing service endpoints.
Disabling extraction reduces model calls; no new Azure cost is introduced.
Fail-closed requests may increase visible errors; monitor safe error counts,
mode selection and persistence-unconfirmed counts without sensitive content.

Validate the candidate with the exact UI/ingestion and infrastructure
combination before a separately approved release repins `manifest.json`.
Do not equate the candidate SHA with the current manifest's orchestrator tag.
Docs and runtime must describe the same shipped behavior.

Rollback is a reviewed redeployment of a known compatible component artifact
and coordinated docs; after a future release pin change restore the validated
manifest combination as necessary. A raw rollback to `25f1986` reintroduces
permissive OBO paths and ineffective-but-active extraction calls and is **not**
a safe security remedy. Prefer a forward fix preserving fail-closed retrieval
and profile suspension, or disable affected retrieval routes operationally.
Code rollback cannot recover lost history, undo prior disclosure/collection,
or establish ownership of old profiles. No storage rollback/migration is added.

## Limits, open questions and review triggers

- This artifact selects policy; it does not close #681, approve handlers,
  activate checks, or prove production authorization/persistence.
- Before the component PR is marked complete, implementation must verify all
  provider construction sites and trusted route classification at its exact
  head. Any undocumented service-only caller must be explicitly classified,
  not grandfathered by catching OBO failures.
- Before restoring profile access, identify a trusted legacy-key owner binding;
  absent proof, suspension remains the final policy, not a temporary bypass.
- Before enabling application fallback, satisfy the equivalent-ACL and
  user-disclosure gate above for every source. No live evidence is claimed.
- Before promising history durability, undertake a separate latency/capacity/
  recovery design and authorization review. Process loss and concurrent writes
  are accepted limits of this choice.
- Required protected reviews/quality adoption and the other #681 packages remain
  outside this decision. Reassess at any source/SDK authorization change,
  profile reactivation proposal, persistence-SLO change, or before release if
  the evidence above is incomplete.
