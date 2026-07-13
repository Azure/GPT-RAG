# Foundry IQ: OneLake (Microsoft Fabric lakehouse)

The `indexedOneLake` Foundry IQ knowledge source grounds answers on files
stored in a Microsoft Fabric OneLake lakehouse. Foundry IQ owns the
underlying Azure AI Search index for this source: it crawls the lakehouse,
chunks and embeds the content, keeps the index fresh, and serves retrieval
back to the orchestrator. The orchestrator only tells Foundry IQ that the
source is enabled and passes on the retrieved snippets to the LLM.

It runs next to your document knowledge source and (optionally) Work IQ,
the Fabric ontology source, and Fabric Data Agent on the same knowledge
base. It does not replace them.

If you have not read the [Grounding sources overview](howto_grounding_overview.md),
start there. In short: this knowledge source is not a separate retrieval
backend. It is registered on the Foundry IQ knowledge base, so a single
request can pull from documents, from Microsoft 365 (via Work IQ), and
from a OneLake lakehouse in one call.

!!! warning "Preview API"
    OneLake support uses a preview Foundry IQ API. GPT-RAG v3.5.0 pins the
    `2026-05-01-preview` baseline and uses `kind: indexedOneLake`. Behavior
    and configuration may change without notice. Do not depend on it for
    production workloads until it is generally available.

## When to use the OneLake source

Use the `indexedOneLake` knowledge source when:

- The content that should ground answers lives in a Fabric lakehouse
  (documents, extracts, curated datasets projected as files) and you want
  Foundry IQ to index it directly rather than mirroring it into Blob
  Storage or maintaining a parallel Azure AI Search index.
- Low-latency, snippet-style retrieval is what you want. Foundry IQ
  returns indexed snippets and file pointers, similar in feel to the
  document source.
- Anonymous chat is acceptable. Retrieval runs against a shared index
  owned by Foundry IQ, so there is no per-user OBO auth on this source
  and no per-user ACL enforcement inside GPT-RAG. Access to the lakehouse
  is granted once, to the Foundry IQ managed identity.

Do not use it when:

- You need per-user permissions to gate what each caller can see from the
  lakehouse. `indexedOneLake` grounds against a shared index; every
  authorized caller of the orchestrator effectively sees the same corpus.
  Use Fabric Data Agent (with OBO) if per-user Fabric permissions must be
  enforced end to end.
- The relevant content is not projected as files in the lakehouse (for
  example, only exposed through semantic models or a Data Agent). Prefer
  the Fabric ontology or Fabric Data Agent source in that case.

## OneLake vs Fabric Data Agent vs Fabric ontology

All three Foundry IQ knowledge sources can be enabled on the same
Knowledge Base. Pick the one that matches how your Fabric content is
exposed today.

| | OneLake (`indexedOneLake`) | Fabric Data Agent (`fabricDataAgent`) | Fabric ontology (`fabricOntology`) |
| --- | --- | --- | --- |
| What it grounds on | Files in a Fabric lakehouse, indexed by Foundry IQ. | A curated Fabric Data Agent that answers questions over Fabric data. | A Fabric ontology exposing semantic models, lakehouses, warehouses, KQL. |
| Mental model | Search over lakehouse files. Feels like the document source. | Virtual analyst. Hands the question to the Data Agent and gets an answer back. | Reasoning over entities and relationships in your business ontology. |
| Auth | App-only. Foundry IQ MI reads the lakehouse. | Per-user OBO. | Per-user OBO. |
| Best when | You have curated files in a lakehouse and want low-latency, snippet-style grounding. | You already invested in a Data Agent tuned for your business questions. | You have a modeled ontology and want the LLM to reason across it. |
| Response shape | Indexed snippets plus OneLake file references. | Natural-language answer plus tabular evidence. | Grounded facts derived from the ontology. |
| App Config prefix | `ONELAKE_*` | `FABRIC_DATA_AGENT_*` | `FABRIC_IQ_*` (historical name, configures `fabricOntology`) |

You can enable more than one on the same Knowledge Base. Start with the
one that matches how your Fabric content is already curated.

## Prerequisites

Work through these in order. All of them are hard blockers.

1. **A Microsoft Fabric workspace with a lakehouse.** The knowledge source
   binds to one lakehouse at a time, identified by the pair
   (`workspaceId`, `lakehouseId`). Content that should ground answers must
   already live under `Files/` in that lakehouse.
2. **Foundry IQ SKU that supports `indexedOneLake`.** Confirm your Foundry
   / Azure AI Search resource is on a plan that supports the preview
   OneLake knowledge source. If in doubt, check the resource in the Azure
   portal or open a support case before enabling.
3. **Fabric RBAC for the Foundry IQ managed identity.** The Foundry IQ MI
   must have at least `Contributor` on the target Fabric workspace so it
   can list and read files. See [Fabric RBAC step](#fabric-rbac-step)
   below. This is a manual operator action; GPT-RAG postProvision does
   not attempt it, because the Fabric REST API requires Fabric admin
   rights that the deploying identity typically does not hold.
4. **Same Entra tenant.** The Fabric tenant, the Foundry / Search resource,
   and the GPT-RAG orchestrator must all be in the same Entra tenant.
   Cross-tenant is not supported.
5. **Foundry IQ preview API.** The knowledge source requires the Foundry
   IQ preview API that supports `kind: indexedOneLake`. GPT-RAG v3.5.0
   pins the `2026-05-01-preview` baseline.

## Configure the OneLake source

The `indexedOneLake` source is opt-in and defaults to off. `azd provision`
(v3.5.0+) seeds the four keys automatically under the `gpt-rag` label with
`ONELAKE_KS_ENABLED=false` and the knowledge source name, workspace, and
lakehouse ids as empty strings. You do not have to create them by hand.
To turn it on for an existing environment, edit the values in the App
Configuration blade (or `az appconfig kv set --label gpt-rag --key ...`)
and restart the orchestrator; or set the same values as azd env vars and
re-run `azd hooks run postprovision` and `azd deploy`.

| Key | Value |
| --- | --- |
| `ONELAKE_KS_ENABLED` | `true` |
| `ONELAKE_KNOWLEDGE_SOURCE_NAME` | Any name for the KS; must match the name registered on the Foundry IQ knowledge base. Example: `onelake-indexed-ks`. |
| `ONELAKE_WORKSPACE_ID` | GUID of the Fabric workspace that owns the lakehouse. |
| `ONELAKE_LAKEHOUSE_ID` | GUID of the lakehouse item within that workspace. |

At the API level the knowledge source is registered with `kind:
indexedOneLake` and workspace / lakehouse ids bound at registration time.
The retrieve call itself only carries the knowledge source name, the
kind, and the standard reference / snippet flags; workspace and lakehouse
ids are captured in App Configuration for observability and for the
Fabric RBAC step below, they are not sent again on every retrieve.

```json
{
  "kind": "indexedOneLake",
  "knowledgeSourceName": "<ONELAKE_KNOWLEDGE_SOURCE_NAME>",
  "includeReferences": true,
  "includeReferenceSourceData": true
}
```

The four keys must all be set for the source to be used at retrieval. If
`ONELAKE_KS_ENABLED` is `false`, or `ONELAKE_KNOWLEDGE_SOURCE_NAME` is
empty, GPT-RAG skips the source and continues with document grounding
(and Work IQ / Fabric ontology / Fabric Data Agent, if enabled).

## Fabric RBAC step

Foundry IQ reads the lakehouse as its own managed identity, not as the
signed-in user. That identity must be granted `Contributor` on the target
Fabric workspace before enabling the source. Do this once per workspace,
manually, using a Fabric admin identity:

```powershell
# Replace with the target workspace id and the Foundry IQ MI object id
$workspaceId  = "<ONELAKE_WORKSPACE_ID>"
$principalId  = "<FOUNDRY_IQ_MANAGED_IDENTITY_OBJECT_ID>"

az rest `
  --method POST `
  --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/roleAssignments" `
  --body (@{
    principal = @{ id = $principalId; type = "ServicePrincipal" }
    role      = "Contributor"
  } | ConvertTo-Json -Depth 5)
```

If this call returns `403`, the caller lacks Fabric admin rights on the
workspace. Ask a Fabric workspace admin to run the assignment, or grant
the role in the Fabric portal (`Workspace > Manage access > Add people or
groups`). GPT-RAG postProvision does not attempt this assignment; a
silent 403 there would be misleading.

## How results appear

When the source is enabled and a question comes in:

1. The orchestrator includes the OneLake knowledge source in the Foundry
   IQ retrieve call alongside any other enabled sources.
2. Foundry IQ serves retrieval from its internal AI Search index over the
   lakehouse and returns indexed snippets plus OneLake file pointers.
3. The orchestrator normalizes each reference into the standard
   `{title, link, content}` shape used by all knowledge sources and hands
   them to the LLM alongside document references.

Titles include the file name and, when available, an annotation with the
workspace and lakehouse ids so operators can trace snippets back to their
origin. Links resolve to the OneLake file path so authorized users can
open the underlying file in Fabric.

Because the source is native to Foundry IQ, the orchestrator does not
bump `maxRuntimeInSeconds` when only OneLake is enabled, and it does not
emit `filterAddOn` for it. Filtering and ACL are enforced by Foundry IQ
against the AI Search index it owns.

## Troubleshooting

- **No OneLake references in responses.** Confirm all four App
  Configuration keys are set, restart the orchestrator, and check its
  logs for an "OneLake knowledge source skipped" warning. That usually
  points at `ONELAKE_KS_ENABLED=false` or an empty knowledge source name.
- **`403` or empty results from Foundry IQ over OneLake.** The Foundry IQ
  MI is missing `Contributor` on the target Fabric workspace. Complete
  the [Fabric RBAC step](#fabric-rbac-step) and wait a few minutes for
  the role to propagate before retesting.
- **`400` on knowledge source registration.** Confirm the Foundry IQ
  preview API version pinned by GPT-RAG matches your Foundry resource.
  The OneLake source requires `2026-05-01-preview` at minimum. If you
  are on an earlier preview, either upgrade or wait for the GA-track
  kind name to stabilize.
- **Stale snippets.** Foundry IQ owns the crawl schedule for the
  underlying AI Search index. There is no gpt-rag-side indexer knob;
  freshness is controlled by Foundry IQ configuration on the knowledge
  source itself.

## Related reading

- [Grounding sources overview](howto_grounding_overview.md)
- [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md)
- [Foundry IQ: Work IQ (Microsoft 365)](howto_grounding_work_iq.md)
- [Foundry IQ: Fabric ontology](howto_grounding_fabric_ontology.md)
- [Foundry IQ: Fabric Data Agent](howto_grounding_fabric_data_agent.md)
