# ADR-0003: Use Foundry IQ as the Microsoft IQ integration boundary

- **Status:** Accepted
- **Date:** 2026-08-04
- **Owners:** GPT-RAG maintainers

## TL;DR

GPT-RAG integrates Microsoft IQ capabilities through an Azure AI Search
Foundry IQ Knowledge Base:

- **Approach A, Foundry IQ**, is the preferred integration boundary and the
  default for new platform deployments. GPT-RAG provisions Knowledge Sources
  and one Knowledge Base, and the orchestrator calls the Foundry IQ `retrieve`
  API.
- **Approach B, direct Azure AI Search**, remains supported as the compatibility,
  migration, and rollback path. It queries the GPT-RAG Search index directly
  and preserves the established security-field contract.
- Work IQ, Fabric IQ ontology, and Fabric Data Agent sources are opt-in. Their
  user-delegated authorization must fail closed; managed identity must not
  replace a missing user token.
- `indexedOneLake` is not yet an end-to-end platform capability. The pinned
  orchestrator can describe it and post-provision scripts seed its settings,
  but the platform Search template does not provision or bind the source.
- Direct Work IQ and Fabric IQ tools in Foundry Agent Service are a viable
  future orchestration alternative, but GPT-RAG does not currently use them.
- `gpt-rag-ingestion` can be logically unnecessary for a primary Foundry IQ
  `azureBlob` corpus, but it is not deployment-optional today. It remains
  required by the platform topology and by `searchIndex`, direct Search
  rollback, uploads, SharePoint ingestion, NL2SQL, and specialized processing.

This ADR records the architecture already implemented across GPT-RAG platform
release `v3.7.0` and pinned orchestrator `v3.8.0`. It does not change runtime
behavior.

## Context

GPT-RAG originally grounded responses by querying an Azure AI Search index
directly. Foundry IQ added a Knowledge Base abstraction that can orchestrate
retrieval across indexed enterprise content and remote knowledge sources.
Subsequent releases added Work IQ, Fabric ontology, Fabric Data Agent, and
OneLake-related configuration at different levels of completeness.

Foundry IQ and Fabric IQ are separate products. In this architecture, Foundry
IQ connects to the concrete Fabric capabilities represented by
`fabricOntology`, `fabricDataAgent`, and `indexedOneLake` Knowledge Sources.
Calling those capabilities directly from an agent is a different orchestration
boundary.

The implementation issue that brought these additions together is
[Azure/GPT-RAG#543](https://github.com/Azure/GPT-RAG/issues/543). The repository
also contains the earlier Foundry IQ tracking issue
[#526](https://github.com/Azure/GPT-RAG/issues/526). Neither issue established
the long-term boundary among:

1. a Foundry IQ Knowledge Base called by GPT-RAG;
2. a GPT-RAG-owned direct Azure AI Search query path; and
3. native Work IQ or Fabric IQ tools invoked directly by a Foundry Agent
   Service agent.

Without an explicit decision, operators could reasonably infer unsupported
combinations, especially that every seeded knowledge-source setting is
provisioned end to end, that managed identity can replace delegated identity
for remote sources, or that `gpt-rag-ingestion` can already be removed.

### Scope

This decision governs:

- the platform repository that provisions Search, App Configuration, and
  Container Apps;
- `gpt-rag-orchestrator`, whose pinned runtime selects and calls the retrieval
  backend;
- `gpt-rag-ingestion`, where the selected source pattern still requires it;
- user and service identity across Azure AI Search, Microsoft 365, and Fabric;
- adoption, rollback, observability, and release compatibility.

It does not decide how Microsoft evolves preview IQ APIs, make a compliance
claim, or authorize removal of the ingestion Container App.

### Sources of truth

The deployed combination is defined by
[`manifest.json`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/manifest.json),
not by independently selecting the latest component versions. At the time of
this decision it pins:

| Component | Version |
| --- | --- |
| GPT-RAG platform | `v3.7.0` |
| gpt-rag-orchestrator | `v3.8.0` (`844fe14757d07a2cdc828189105fbce831f3c11d`) |
| gpt-rag-ingestion | `v2.5.0` |
| AI Landing Zone | `v2.3.0` |

Implementation and release evidence is listed in
[Verified evidence](#verified-evidence). Product how-to documentation remains
on the repository's `docs` branch and is not a substitute for the pinned
runtime contract.

### Current implementation

#### Platform provisioning

For fresh platform deployments,
[`main.parameters.json`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/main.parameters.json)
sets `RETRIEVAL_BACKEND=foundry_iq`. The Search definition template
[`config/search/search.j2`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/config/search/search.j2)
renders:

- one primary `azureBlob` or `searchIndex` Knowledge Source;
- optional `workIQ`, `fabricOntology`, and `fabricDataAgent` Knowledge Sources;
- one shared Knowledge Base that references the enabled sources.

The setup implementation
[`config/search/setup.py`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/config/search/setup.py)
reconciles these resources in this order:

1. validate and apply index updates;
2. delete Knowledge Bases before Knowledge Sources;
3. reconcile standard Search resources;
4. run the Work IQ consent preflight;
5. create Knowledge Sources before the Knowledge Base; and
6. fail provisioning when the configured Foundry IQ backend cannot create its
   Knowledge Sources or Knowledge Base.

This is a replacement-style reconciliation, not a non-disruptive patch.
Externally added Knowledge Base bindings can be removed by a later
post-provision run.

The Work IQ preflight is deliberately conservative. If consent is absent or
cannot be established, the setup removes the Work IQ source and its Knowledge
Base reference before provisioning. Other configured sources can continue.
This avoids binding a source known not to work, but it also means operators
must observe the omission rather than assume all requested sources were bound.

#### Orchestrator runtime

Pinned orchestrator `v3.8.0` selects exactly one `ContextProvider` from
`RETRIEVAL_BACKEND`. The `foundry_iq` provider uses the `2026-05-01-preview`
Foundry IQ `retrieve` API and passes the configured Knowledge Base name,
activity, output mode, retrieval instructions, and source-specific parameters.
The `ai_search` provider retains the direct Search query path.

Remote Work and Fabric sources receive the incoming user's delegated token.
Local indexed sources can use service identity according to their configured
authorization mode. The backend selector falls back to direct Search when the
setting is missing or unknown in the standalone component, while the platform
deployment explicitly sets the Foundry IQ value.

### Prioritized characteristics

The decision prioritizes these characteristics in order:

1. **Authorization correctness.** A source may return only content the current
   user and deployed service are allowed to retrieve. Missing user delegation
   must never become broader service access.
2. **Reversibility.** An operator must be able to return to an
   authorization-equivalent direct Search corpus without changing the public
   chat API.
3. **Release compatibility.** Platform templates, orchestrator behavior,
   ingestion behavior, preview API versions, and documentation must be
   validated as one pinned combination.
4. **Operability.** Source enablement, omission, latency, errors, and cost must
   be visible independently rather than hidden behind aggregate retrieval
   success.
5. **Extensibility.** New IQ sources should be added through typed,
   template-driven Knowledge Source definitions rather than strategy-specific
   application code.
6. **Performance and cost.** Added orchestration and remote-source latency must
   stay within an operator-approved request budget and produce attributable
   Search, Microsoft 365, Fabric, and model costs.

## Considered alternatives

### Approach A: Foundry IQ Knowledge Base

GPT-RAG provisions or references Foundry IQ Knowledge Sources, binds them to a
Knowledge Base, and calls the Knowledge Base through the orchestrator context
provider.

**Benefits**

- Gives document, Work IQ, and Fabric sources one retrieval boundary.
- Centralizes source selection, retrieval instructions, citations, and
  source-specific parameters.
- Keeps agent strategies independent of each source integration.
- Supports an `azureBlob` primary corpus without requiring GPT-RAG ingestion
  to populate the primary Search index.
- Allows remote sources to preserve their native user-delegated authorization
  semantics.
- Extends through template and configuration contracts rather than branching
  every agent strategy.

**Costs and risks**

- Depends on preview Search APIs and source-specific preview behavior.
- Adds Knowledge Base planning latency and source-dependent tail latency.
- Replacement-style provisioning can temporarily remove the Knowledge Base or
  erase untracked external bindings.
- Remote sources add tenant consent, licensing, network, data-boundary, and
  service-availability dependencies.
- A successful Knowledge Base response may represent only a subset of intended
  sources unless per-source outcomes are observed.
- Foundry IQ and remote systems introduce costs beyond the direct Search query.

### Approach B: direct Azure AI Search

GPT-RAG queries its Search index directly through the existing Search context
provider.

**Benefits**

- Preserves the mature GPT-RAG index, query, citation, and security-field
  behavior.
- Has fewer control-plane resources and no Knowledge Base planner.
- Provides a fast compatibility and rollback path.
- Retains specialized GPT-RAG ingestion, chunking, multimodal, SharePoint,
  upload, and NL2SQL flows.
- Limits a retrieval request to infrastructure already operated by GPT-RAG.

**Costs and risks**

- Does not natively compose Work IQ or Fabric IQ remote sources.
- Keeps retrieval orchestration and security filtering in GPT-RAG.
- Requires an ingestion pipeline or another producer to maintain the Search
  corpus.
- A stale or differently authorized rollback index can produce incorrect or
  over-broad results.

### Approach C: direct Foundry Agent Service Work IQ and Fabric IQ tools

Foundry Agent Service exposes preview
[`work_iq_preview`](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/work-iq)
and
[`fabric_iq_preview`](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/fabric-iq)
tools. A hosted agent could invoke those tools directly instead of receiving
grounding from GPT-RAG's Foundry IQ context provider.

This is technically viable and may become attractive as Agent Service hosting
matures. It is **not implemented by GPT-RAG today**. In pinned orchestrator
`v3.8.0`, the MAF Agent Service strategy creates its prompt agent without
tools; retrieval is still injected through the selected context provider.

**Benefits**

- Lets the hosted agent plan and invoke source tools directly.
- Could reduce GPT-RAG-specific retrieval glue for Agent Service strategies.
- Aligns with the platform-native tool lifecycle if the preview contracts
  become stable.

**Costs and risks**

- Couples retrieval behavior to one hosting strategy instead of the shared
  GPT-RAG context-provider contract.
- Creates different grounding semantics between local and hosted strategies.
- Requires new delegated-identity, audit, approval, timeout, citation, and
  error contracts.
- May make deterministic fallback to direct Search harder.
- Is currently preview and lacks GPT-RAG integration and release evidence.

This option requires a separate, time-boxed architecture spike and decision.
It must not be enabled by configuration alone under this ADR.

### Approach D: no explicit decision

Continue adding sources and settings independently without freezing the
retrieval boundary.

**Benefit**

- No immediate engineering work.

**Costs**

- Operators cannot distinguish implemented, externally provisioned, and
  aspirational integrations.
- Security and rollback behavior remain implicit.
- Releases can claim source support without testing platform provisioning,
  runtime invocation, and authorization together.
- Direct Agent Service tools could accidentally create strategy-specific
  semantics.

This option is rejected.

## Decision

Adopt **Approach A, Foundry IQ Knowledge Base, as the Microsoft IQ integration
boundary**, while retaining **Approach B, direct Azure AI Search, as a supported
compatibility and rollback backend**.

The following constraints are part of the decision:

1. A request uses one configured retrieval backend. Agent strategies do not
   select or mix backends independently.
2. New platform deployments use `foundry_iq`; existing deployments are not
   silently migrated.
3. Work IQ, Fabric ontology, Fabric Data Agent, and future remote sources remain
   opt-in and disabled by default.
4. User-delegated sources require a valid user OBO token. Managed identity must
   never substitute for missing or failed delegation.
5. Service-managed sources and control-plane operations use managed identity
   where supported; secrets remain in Key Vault or a Key Vault reference.
6. Direct Search remains release-tested. It may be removed only by a later ADR
   with a migration path for every supported ingestion and authorization
   pattern.
7. Direct Agent Service IQ tools remain outside the implemented boundary until
   a separate decision defines strategy parity, identity, audit, and rollback.
8. A source is called supported only when platform provisioning, App
   Configuration, pinned orchestrator runtime, authorization, documentation,
   and live validation all agree.

### Knowledge Source contract

| Source | Platform provisioning | Runtime identity | Decision status |
| --- | --- | --- | --- |
| `azureBlob` | Rendered and bound by `search.j2` | Managed service identity | Supported primary Foundry IQ corpus |
| `searchIndex` | Rendered and bound by `search.j2` | Search resource identity plus configured `filterAddOn` document authorization | Supported custom-ingestion corpus |
| `workIQ` | Opt-in, preflighted, rendered, and bound | User OBO | Supported preview; consent, tenant, licensing, and latency gates apply |
| `fabricOntology` | Opt-in, rendered, and bound | User OBO | Supported preview; Fabric caller permissions apply |
| `fabricDataAgent` | Opt-in, rendered, and bound | User OBO | Supported preview; Fabric caller permissions apply |
| `indexedOneLake` | Settings seeded, but not rendered or bound by the platform template | Pre-registered source identity and Fabric RBAC; no user OBO in the pinned runtime | Externally preprovisioned/experimental; not end-to-end supported |

`indexedOneLake` is a known implementation gap, not an exception to the
support rule. The pinned orchestrator contains the source kind and platform
post-provision scripts seed `ONELAKE_*` settings, but
`config/search/search.settings.j2` and `config/search/search.j2` do not create
or bind it. A subsequent platform reprovision can therefore recreate the
Knowledge Base without the externally attached OneLake source. End-to-end
support requires template reconciliation, tests, operator documentation, and
live authorization validation.

When an operator pre-registers and binds the source, the pinned runtime can add
`indexedOneLake` source parameters with the configured workspace and lakehouse.
That path does not require user OBO, does not use `filterAddOn`, and does not
trigger the remote Work/Fabric runtime extension by itself. The pre-registered
Knowledge Source's managed identity and Fabric RBAC govern indexing access.
This shared service access must not be represented as per-user document
authorization; any future document-level permission mode requires an explicit
contract and negative authorization tests.

### Ingestion boundary

The retrieval backend and ingestion topology are related but not equivalent.

- With an `azureBlob` primary Knowledge Source, Foundry IQ owns chunking and
  indexing for that corpus. GPT-RAG ingestion is logically unnecessary for
  those documents.
- With a `searchIndex` primary Knowledge Source, another producer must populate
  the index. GPT-RAG ingestion remains the supported producer when custom
  chunking, multimodal or large-document processing, uploads, SharePoint
  ingestion, NL2SQL, or existing index contracts are required.
- Direct Search requires a maintained Search corpus. Operators retaining it as
  a rollback path must keep the corpus current and authorization-equivalent.
- The platform still deploys and discovers the ingestion Container App and
  assumes its endpoints during post-provisioning. Therefore
  `gpt-rag-ingestion` is **not deployment-optional** under this ADR, even when
  it is not on the primary `azureBlob` data path.

Making ingestion deployment-optional requires a separate cross-repository
change that removes topology assumptions, defines feature exclusions, updates
health and FQDN discovery, and proves both provisioning modes.

## Identity, security, and compliance boundaries

### Service identity

Platform provisioning and service-to-service Search access use managed
identity and Azure RBAC where supported. This removes application credentials
from the normal Search data path but does not authorize user-scoped remote
content.

### User delegation

Work IQ, `fabricOntology`, and `fabricDataAgent` are user-delegated sources.
The orchestrator forwards the user's token in
`x-ms-query-source-authorization`. The token represents the current caller and
the remote system enforces that caller's permissions.

The current orchestrator OBO exchange uses the configured Entra application
client secret for the OAuth exchange. This is not managed-identity OBO. The
secret must remain a Key Vault reference, be rotated, and be excluded from
logs, traces, audit properties, prompts, and exception text.

For these remote sources:

- no incoming user token means no remote retrieval;
- OBO failure means no remote retrieval;
- service managed identity must not be used as a broader fallback;
- token audiences and tenant must be validated rather than inferred;
- same-tenant, admin-consent, licensing, and conditional-access prerequisites
  remain operator responsibilities.

The current Work IQ preflight can omit the source when consent cannot be
proved. Runtime and operational telemetry must make the omission visible.

### Document authorization

For direct Search and `searchIndex` patterns, GPT-RAG must preserve the
configured document-security fields and query-time filters. Foundry IQ
`filterAddOn` does not replace index-time ACL hygiene, and a rollback index is
safe only when its authorization semantics are equivalent to the active
corpus.

OneLake authorization must not be inferred from the source kind. Before the
experimental path can become supported, its provisioning contract must declare
whether retrieval is shared service access or document-level user enforcement,
then prove that choice with negative authorization tests.

### Compliance and data boundaries

IQ integration is a data-access mechanism, not a compliance certification.
Grounded content can flow through:

- Azure AI Search and its Knowledge Base planner;
- Microsoft 365 or Fabric source services;
- Azure OpenAI model prompts and responses;
- Cosmos DB conversation history when enabled; and
- Application Insights and audit telemetry according to configured capture
  policy.

Operators must validate tenant, region, network, retention, eDiscovery,
sensitivity-label, and regulatory requirements for every enabled source.
Preview availability or a successful deployment does not establish compliance.
Sensitive prompts, source excerpts, tokens, identifiers, and tool payloads must
not be logged by default.

## Operational model

### Provisioning and drift

Knowledge Base reconciliation deletes Knowledge Bases before Knowledge Sources
and recreates sources before the Knowledge Base. Operators must treat
post-provisioning as potentially disruptive and must not make untracked manual
bindings. Source names must be unique across all enabled source kinds.

The rendered configuration is authoritative. If an external source is needed
temporarily, its owner must record the patch and expect it to be removed by
reprovisioning until the source is represented in the template.

### Latency and availability

Remote sources have independent latency and failure domains. Microsoft
documents that Work IQ can take 40-60 seconds and recommends a retrieval budget
of at least 120 seconds. Enabling it changes the end-to-end latency objective
and requires an explicit client, gateway, orchestrator, and Search timeout
review.

Per-source telemetry must distinguish:

- requested, bound, invoked, omitted, succeeded, timed out, and failed;
- OBO acquisition failure from source authorization denial;
- planner latency from source latency;
- zero authorized results from source unavailability; and
- partial grounding from complete grounding.

### Cost

Cost attribution must cover Search capacity and semantic operations, Foundry IQ
planning, remote Microsoft 365 or Fabric consumption, model tokens, ingestion,
and telemetry. A source is not ready for broad adoption until its per-request
or per-user cost can be estimated and alert thresholds are defined.

### Network isolation

Network-isolated deployments must validate every enabled source from the
deployed orchestrator and Search service. Private endpoint and DNS success for
Azure AI Search does not prove connectivity to Microsoft 365 or Fabric.
Unsupported egress requirements must fail deployment or keep the source
disabled; they must not cause an implicit public-network fallback.

## Compatibility and rollback

The public chat API and strategy contract remain unchanged when switching
between the two supported backends.

### Roll forward to Foundry IQ

1. Upgrade to an exact platform/component pin combination validated for the
   desired sources.
2. Keep all optional IQ sources disabled.
3. Provision the primary `azureBlob` or `searchIndex` source and Knowledge Base.
4. Validate citations, authorization, latency, and source telemetry.
5. Enable one optional remote source at a time and complete its identity and
   live canary gates.
6. Set `RETRIEVAL_BACKEND=foundry_iq` and restart the orchestrator.

### Roll back to direct Search

1. Confirm the direct Search index is current and authorization-equivalent.
2. Set `RETRIEVAL_BACKEND=ai_search` in App Configuration under the `gpt-rag`
   label.
3. Restart the orchestrator so the provider is rebuilt.
4. Run positive and negative authorization canaries.
5. Keep the Knowledge Base for diagnosis or disable optional source flags;
   deletion is not required for runtime rollback.

If no current direct Search corpus exists, this rollback is unavailable.
Operators choosing an `azureBlob`-only primary path must either accept that
recovery dependency or maintain a parallel Search corpus through ingestion.

### Version compatibility

Runtime source kinds are not forward-compatible merely because App
Configuration accepts their names. Release validation must bind the exact
platform template, orchestrator tag, ingestion tag, and preview API version.
Unsupported independent component upgrades must fail compatibility checks
rather than silently omit a source.

## Consequences

### Positive

- GPT-RAG has one explicit Microsoft IQ integration boundary.
- Direct Search remains a practical and tested escape hatch.
- Agent strategies share retrieval behavior instead of implementing
  source-specific tools.
- Remote-source authorization is explicitly user-delegated and fail-closed.
- Incomplete OneLake and ingestion-optional behavior can no longer be mistaken
  for end-to-end support.
- New sources have a concrete provisioning, runtime, security, documentation,
  and live-validation bar.

### Negative

- The platform must operate and test both Foundry IQ and direct Search.
- Maintaining rollback may require duplicate corpus processing and cost.
- Foundry IQ provisioning can be disruptive and is sensitive to preview API
  drift.
- Work and Fabric sources add consent, licensing, latency, network, and
  compliance work.
- Managed-identity service access and secret-backed OBO remain two distinct
  credential paths.
- The current platform has a documented mismatch between OneLake release claims
  and template reconciliation.

### Neutral

- This ADR records existing behavior; it does not change the platform default.
- Direct Agent Service IQ tools remain available for future evaluation.
- Ingestion remains deployed even when not used for the primary corpus.

## Adoption and migration

### Platform and orchestrator

1. Preserve the backend selector and public API while adding source features.
2. Extend `search.settings.j2`, `search.j2`, App Configuration seeding, and
   orchestrator typed settings together for every source.
3. Add both disabled and enabled template tests, Knowledge Base binding tests,
   name-collision tests, and runtime source-parameter tests.
4. Correct `indexedOneLake` only through an end-to-end change; do not add
   another script-only setting.
5. Keep direct Search validation in every umbrella release that changes
   retrieval, ingestion, identity, or Search schemas.

### Operators

1. Inventory current corpus producers, authorization fields, and rollback
   requirements.
2. Choose `azureBlob` for a Foundry IQ-managed primary corpus or `searchIndex`
   when custom ingestion behavior is required.
3. Establish a direct Search recovery corpus before relying on backend rollback.
4. Complete identity, tenant, consent, licensing, network, retention, and cost
   reviews for each optional source.
5. Enable and validate one source at a time.
6. Treat OneLake as external/experimental until the platform provisions it.

### Direct Agent Service tool evaluation

A future spike may compare direct Agent Service tools with the shared
Knowledge Base path. It must use the same test corpus and callers, and measure
authorization parity, citation fidelity, strategy parity, latency, cost,
auditability, network behavior, and rollback. No production migration follows
from the spike without a superseding ADR.

## Automated fitness functions

The following checks are release gates. Existing tests cover only a subset and
must be expanded as the implementation evolves.

| Fitness function | Automated evidence | Pass condition |
| --- | --- | --- |
| Exact pin compatibility | Manifest-driven CI checks out every pinned tag and runs integration tests | No test uses floating component branches |
| Backend selection | Orchestrator unit tests for missing, valid, and invalid `RETRIEVAL_BACKEND` | Platform value selects the intended provider; standalone fallback remains explicit |
| Source template completeness | Parameterized render tests for every source, enabled and disabled | Enabled source appears once and is bound once; disabled source is absent |
| OneLake end-to-end completeness | Render, provision, reprovision, and retrieve test | `indexedOneLake` remains bound after reprovision before its status becomes supported |
| Knowledge resource ordering | Mocked management API test | Cleanup is KB then KS; creation is KS then KB; partial failure fails provisioning |
| Unique names | Template test across all source kinds | Duplicate Knowledge Source names fail before destructive reconciliation |
| Work IQ consent behavior | Preflight unit test and live tenant canary | Missing/inconclusive consent cannot bind or invoke Work IQ and emits an observable omission |
| Remote-source fail-closed authorization | Negative tests with no token, wrong tenant, expired token, and unauthorized user | No remote result and no managed-identity fallback |
| Cross-user isolation | Two-user canary over disjoint Microsoft 365 and Fabric permissions | Each user receives only independently authorized content |
| Direct Search document authorization | Positive and negative index tests | Existing security filters deny unauthorized documents after upgrades |
| Secret and token hygiene | Telemetry/audit scan in CI | No bearer token, client secret, prompt excerpt, or source excerpt appears in default logs |
| Strategy parity | Common retrieval contract tests across supported agent strategies | Source inputs, citations, and authorization are strategy-independent |
| Rollback readiness | Deployment test switches to `ai_search` and restarts | Current authorization-equivalent corpus serves successful positive and negative canaries |
| Network isolation | Private deployment integration test per enabled source | Required endpoints resolve and connect without unintended public fallback |
| Latency budget | Per-source canaries and percentile alerts | Operator-approved p95/p99 and timeout budgets hold; Work IQ budget is at least its documented minimum |
| Cost budget | Tagged telemetry joined to Azure cost data | Per-source cost stays below operator-defined thresholds |
| Preview contract drift | Scheduled schema and live smoke tests | API version, source kind, headers, and response parsing remain compatible |
| Ingestion optionality | Two-topology deployment test, only after a separate change | No-ingestion deployment has no unresolved resource, FQDN, health, upload, or rollback dependency |
| Documentation consistency | CI verifies source keys and support status appear in operator docs | Docs distinguish supported, experimental, and future alternatives |

## Documentation impact

The existing `docs` branch already describes Foundry IQ and direct Search as
the two grounding approaches and contains source-specific operator guides.
This ADR adds the durable architecture boundary.

The next documentation synchronization must:

- label `indexedOneLake` as externally preprovisioned/experimental until the
  template gap is fixed, or fix the implementation and validate it;
- avoid describing `gpt-rag-ingestion` as deployment-optional;
- keep direct Agent Service IQ tools clearly separate from implemented GPT-RAG
  retrieval; and
- state the user OBO versus service managed-identity boundary for every source.

No user-visible behavior changes in this ADR-only change, so no deployment
guide is modified here.

## Review trigger

Review this decision by **2026-11-04**, or earlier when any of these events
occurs:

- a required Foundry IQ, Work IQ, Fabric IQ, or Agent Service preview API
  reaches GA, is retired, or changes its identity or request contract;
- direct Agent Service Work IQ or Fabric IQ tools reach a maturity level that
  justifies the comparison spike;
- managed-identity-backed user delegation becomes available;
- `indexedOneLake` platform reconciliation is implemented;
- ingestion becomes deployment-optional;
- a cross-user authorization defect or unexpected managed-identity fallback is
  found;
- remote-source p95 latency, error rate, or cost exceeds its approved budget;
- network isolation or regional/data-boundary requirements change; or
- the direct Search recovery corpus can no longer be kept
  authorization-equivalent.

A superseding decision must include migration and rollback evidence; editing
source flags alone is insufficient.

## Verified evidence

### GPT-RAG platform

- [Manifest at platform `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/manifest.json)
  pins orchestrator `v3.8.0`, ingestion `v2.5.0`, and AI Landing Zone `v2.3.0`.
- [`main.parameters.json` at `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/main.parameters.json)
  sets the fresh-deployment Foundry IQ configuration and still provisions the
  ingestion Container App.
- [`config/search/search.settings.j2` at `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/config/search/search.settings.j2)
  defines Work IQ and Fabric settings but has no `ONELAKE_*` settings.
- [`config/search/search.j2` at `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/config/search/search.j2)
  renders `azureBlob`, `searchIndex`, `workIQ`, `fabricOntology`, and
  `fabricDataAgent`, but not `indexedOneLake`.
- [`config/search/setup.py` at `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/config/search/setup.py)
  implements Work IQ preflight and KB/KS replacement ordering.
- [`test_foundry_iq_templates.py` at `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/config/search/tests/test_foundry_iq_templates.py)
  verifies default-off source rendering, Knowledge Base bindings, unique names,
  and Work IQ omission on failed or inconclusive consent.
- [`postProvision.ps1` at `v3.7.0`](https://github.com/Azure/GPT-RAG/blob/v3.7.0/scripts/postProvision.ps1)
  seeds the `ONELAKE_*` settings consumed by the orchestrator.
- [Platform release `v3.5.0`](https://github.com/Azure/GPT-RAG/releases/tag/v3.5.0)
  announced the OneLake settings and records that validation covered App
  Configuration wiring; it does not supply the missing platform template
  binding.

### Issues and pull requests

- [Issue #526: Foundry IQ](https://github.com/Azure/GPT-RAG/issues/526)
- [Issue #543: Add support to Work and Fabric IQ](https://github.com/Azure/GPT-RAG/issues/543)
- [Issue #508: authorization regression with RBAC enabled](https://github.com/Azure/GPT-RAG/issues/508)
- [Issue #551: missing Work/Fabric App Configuration seeding](https://github.com/Azure/GPT-RAG/issues/551)
- [PR #528: Foundry IQ retrieval configuration](https://github.com/Azure/GPT-RAG/pull/528)
- [PR #547: Work IQ](https://github.com/Azure/GPT-RAG/pull/547)
- [PR #549: Fabric ontology](https://github.com/Azure/GPT-RAG/pull/549)
- [PR #554: Fabric Data Agent](https://github.com/Azure/GPT-RAG/pull/554)
- [PR #559: indexed OneLake settings](https://github.com/Azure/GPT-RAG/pull/559)

### Pinned orchestrator `v3.8.0`

The annotated `v3.8.0` tag resolves to immutable commit
[`844fe14757d07a2cdc828189105fbce831f3c11d`](https://github.com/Azure/gpt-rag-orchestrator/commit/844fe14757d07a2cdc828189105fbce831f3c11d).

- [`src/util/retrieval_backend.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/844fe14757d07a2cdc828189105fbce831f3c11d/src/util/retrieval_backend.py)
  defines backend resolution and the direct Search fallback.
- [`src/connectors/foundry_iq.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/844fe14757d07a2cdc828189105fbce831f3c11d/src/connectors/foundry_iq.py)
  implements Knowledge Base retrieval and Work IQ, Fabric ontology, Fabric Data
  Agent, and OneLake source parameters.
- [`src/connectors/search.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/844fe14757d07a2cdc828189105fbce831f3c11d/src/connectors/search.py)
  implements the Search OBO exchange.
- [`tests/test_foundry_iq_onelake.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/844fe14757d07a2cdc828189105fbce831f3c11d/tests/test_foundry_iq_onelake.py)
  verifies the orchestrator-side `indexedOneLake` source parameters.
- [`src/strategies/maf_agent_service_strategy.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/844fe14757d07a2cdc828189105fbce831f3c11d/src/strategies/maf_agent_service_strategy.py)
  creates the prompt agent with `tools=None`.
- [`src/strategies/agent_strategy_factory.py`](https://github.com/Azure/gpt-rag-orchestrator/blob/844fe14757d07a2cdc828189105fbce831f3c11d/src/strategies/agent_strategy_factory.py)
  has no direct IQ-tool strategy.
- [Orchestrator release `v3.8.0`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v3.8.0)
  is the exact release pinned by the platform manifest.

### Microsoft service contracts

- [Foundry IQ overview](https://learn.microsoft.com/en-us/azure/search/agentic-retrieval-overview)
- [Create a Knowledge Base](https://learn.microsoft.com/azure/search/agentic-retrieval-how-to-create-knowledge-base)
- [Work IQ Knowledge Source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-work-iq)
- [Indexed OneLake Knowledge Source](https://learn.microsoft.com/azure/search/agentic-knowledge-source-how-to-onelake)
- [Document-level access control](https://learn.microsoft.com/en-us/azure/search/search-document-level-access-overview)
- [Foundry Agent Service Work IQ tool](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/work-iq)
- [Foundry Agent Service Fabric IQ tool](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/fabric-iq)

## Decision history

- **2026-08-04:** Accepted. Foundry IQ is the implemented Microsoft IQ
  boundary, direct Search remains the supported fallback, and incomplete
  OneLake, ingestion-optional, and direct-Agent-Service-tool paths are recorded
  explicitly.
