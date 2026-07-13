# Ground answers on SharePoint (remote, Copilot Retrieval API)

This how-to describes the **SharePoint remote** grounding option in GPT-RAG.
It is the fifth Foundry IQ knowledge source kind, alongside `searchIndex`,
`workIQ`, `fabricOntology`, and `fabricDataAgent`.

SharePoint remote does not ingest content into the platform. It queries
SharePoint at retrieval time via the Microsoft 365 **Copilot Retrieval API**,
using the calling user's identity (delegated on-behalf-of, OBO). Item-level
permissions are enforced natively by Microsoft 365; each user only sees
citations for SharePoint items they can already open.

Use this when:

- The authoritative content already lives in SharePoint and you do not want a
  second copy in an Azure index.
- You need item-level ACL to stay with the source, not be replicated.
- Fresh (near real-time) content is more important than sub-second latency.

## Overview

At retrieve time the orchestrator adds a `remoteSharePoint` knowledge source
to the Foundry IQ knowledge base retrieve call. The Copilot Retrieval API
searches the user's authorized SharePoint content and returns references with
a `webUrl` deep link, item metadata, and text extracts. The orchestrator
normalizes each hit into the shared `{title, link, content}` citation shape
so SharePoint results appear alongside `azureBlob`, `searchIndex`, `workIQ`,
`fabricOntology`, and `fabricDataAgent` citations.

The `remoteSharePoint` source runs under the user's OBO token forwarded via
`x-ms-query-source-authorization`. The service managed identity is never
substituted for this source: if no OBO token is available on a request, the
SharePoint remote entry is skipped and the other configured knowledge
sources run normally.

## Prerequisites

Before enabling SharePoint remote, confirm the following are in place:

- **Microsoft 365 tenant** with SharePoint Online and the users you want to
  serve.
- **Microsoft 365 Copilot** license coverage for the calling users, as
  required by the Copilot Retrieval API.
- **Admin consent** for the delegated permission scopes needed by the Copilot
  Retrieval API for your Foundry IQ application registration. Consult the
  Foundry IQ documentation for the exact scope names, then grant consent in
  Microsoft Entra ID.
- **A registered `remoteSharePoint` knowledge source** on the Foundry IQ
  knowledge base used by GPT-RAG. Registration is done outside this how-to
  (via the Foundry IQ knowledge-base API or authoring tools). Record the
  knowledge source name; you will use it in the configuration step below.
- **OBO plumbing** in the orchestrator front-end. The web app is expected to
  pass a user-scoped token to the orchestrator so it can be forwarded as
  `x-ms-query-source-authorization`. This is the same mechanism used by the
  Work IQ and Fabric ontology knowledge sources.

No Azure infrastructure is provisioned for SharePoint remote. There is no
index, no ingestion pipeline, no storage account. All configuration is App
Configuration keys plus the KS registration on the knowledge base.

## Configuration keys

The following App Configuration keys drive SharePoint remote. All keys use
the `gpt-rag` label and are seeded (idempotently) by
`scripts/postProvision.ps1`.

| Key | Default | Description |
| --- | --- | --- |
| `SHAREPOINT_REMOTE_ENABLED` | `false` | Master switch. When `true` and a knowledge source name is set, the retrieve call adds a `remoteSharePoint` entry to `knowledgeSourceParams`. |
| `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME` | *(empty)* | Name of the `remoteSharePoint` knowledge source registered on the Foundry IQ knowledge base. Required when the feature is enabled. |
| `SHAREPOINT_REMOTE_FILTER_EXPRESSION_ADD_ON` | *(empty)* | Optional KQL scope forwarded verbatim as `filterExpressionAddOn`. Use it to restrict results to a site, path, or content type. Leave empty for no additional filter. |

The orchestrator never emits a `filterAddOn` for `remoteSharePoint`. ACL is
enforced natively by SharePoint through the user's OBO token; no
security-trimming clause is added or needed on the retrieve side.

## How to enable

1. Register a `remoteSharePoint` knowledge source on your Foundry IQ
   knowledge base and note its name.
2. Set the App Configuration keys (label `gpt-rag`):
   - `SHAREPOINT_REMOTE_ENABLED` = `true`
   - `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME` = *(your KS name)*
   - `SHAREPOINT_REMOTE_FILTER_EXPRESSION_ADD_ON` = *(optional KQL, or leave
     empty)*
3. Ensure the orchestrator front-end is forwarding an OBO token on user
   requests (same requirement as Work IQ / Fabric ontology).
4. Send a user question. On the retrieve call the orchestrator will now
   include a `remoteSharePoint` entry in `knowledgeSourceParams` and the
   Copilot Retrieval API will return SharePoint references.

To disable, set `SHAREPOINT_REMOTE_ENABLED` back to `false`. Other knowledge
sources continue to work unchanged; the retrieve payload is byte-identical to
its pre-enablement shape when SharePoint remote is off.

## How results appear

SharePoint remote results share the same `{title, link, content}` citation
shape as every other knowledge source. Concretely:

- **Title** comes from `resourceMetadata.Title` (with `Name` / `FileName`
  fallbacks). If none is present, the orchestrator falls back to the last
  segment of the SharePoint URL, and finally to a generic `SharePoint item`
  label so an empty hit is never surfaced as a bare `reference`.
- **Link** is the SharePoint `webUrl` deep link. Clicking it opens the item
  in SharePoint under the user's own identity, so any additional ACL checks
  (site membership, sensitivity label handling, etc.) apply as usual.
- **Content** is the concatenation of `extracts[].text` snippets returned by
  the Copilot Retrieval API. When extracts are absent the orchestrator falls
  back to a flat `text` / `content` / `snippet` field. Hits with no
  recoverable text are dropped rather than surfaced as empty citations.

SharePoint hits are visible in the model's grounded context and in the
citation list rendered by the front-end. They coexist with any other enabled
knowledge sources; ordering follows what the retrieve API returns.

## Troubleshooting

**SharePoint remote is enabled but no SharePoint citations appear.**

- Confirm `SHAREPOINT_REMOTE_KNOWLEDGE_SOURCE_NAME` matches the name of the
  `remoteSharePoint` KS actually registered on the knowledge base. A missing
  or mistyped name causes the orchestrator to log a warning and skip the
  source.
- Confirm the front-end is forwarding an OBO token. If the request reaches
  the orchestrator without a user token, the SharePoint remote entry is
  skipped by design and a warning is logged. Managed-identity fallback is
  never used for this kind.
- Confirm the calling user actually has SharePoint items that match the
  query. Item-level ACL is enforced by M365; a user with no access to
  matching items will get no SharePoint citations even though the source is
  configured correctly.
- Confirm admin consent has been granted for the delegated scopes required
  by the Copilot Retrieval API. Without consent the API will reject the
  call.

**SharePoint citations appear but the wrong scope is returned.**

- Consider setting `SHAREPOINT_REMOTE_FILTER_EXPRESSION_ADD_ON` to a KQL
  expression that narrows the scope (for example, a specific site path or
  content type). The value is forwarded verbatim as `filterExpressionAddOn`.

**The retrieve call is slow or times out.**

- Remote knowledge sources can take longer than local sources because they
  fan out to M365. GPT-RAG already emits a `maxRuntimeInSeconds` ceiling
  whenever any remote kind (Work IQ, Fabric ontology, Fabric Data Agent,
  SharePoint remote) is enabled. Tune it via `FOUNDRY_IQ_MAX_RUNTIME_SECONDS`
  if your workload needs more headroom.

**A user reports seeing a SharePoint item they should not see.**

- SharePoint remote does not add ACL of its own. If a citation surfaces, the
  M365 permissions on the item allowed it. Fix the ACL at the source in
  SharePoint; do not attempt to add a `filterAddOn` here, and do not fall
  back to the service managed identity for this source.
