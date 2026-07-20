# Foundry IQ: Fabric Data Agent (Microsoft Fabric)

The `fabricDataAgent` Foundry IQ knowledge source grounds answers on a
Microsoft Fabric Data Agent. A Fabric Data Agent acts as a virtual analyst:
it runs queries over Fabric data (semantic models, lakehouses, warehouses,
KQL databases) and returns natural-language answers plus tabular evidence.
It runs next to your document knowledge source and (optionally) Work IQ and
the Fabric ontology source on the same knowledge base. It does not replace
them.

If you have not read the [Grounding sources overview](howto_grounding_overview.md),
start there. In short: this knowledge source is not a separate retrieval
backend. It is registered on the Foundry IQ knowledge base, so a single
request can pull from documents, from Microsoft 365 (via Work IQ), and
from a Fabric Data Agent in one call.

!!! warning "Preview, per-user auth, data leaves the Azure boundary"
    Fabric Data Agent support uses a preview Foundry IQ API and requires an
    on-behalf-of (OBO) token for the signed-in user. Requests and
    intermediate data may route outside the Azure compliance boundary;
    operators must review this before enabling. Behavior and configuration
    may change without notice. Do not depend on it for production workloads
    until it is generally available.

> Complete the [Foundry IQ prerequisites](howto_grounding_foundry_iq_prereqs.md)
> first. The Prerequisites section below covers only what is specific to this
> source.

## When to use Fabric Data Agent

Use the Fabric Data Agent knowledge source when:

- Users sign in to the GPT-RAG UI (or another authenticated client), so the
  orchestrator can obtain a delegated (OBO) token for the user.
- A Fabric Data Agent has already been curated to answer the questions
  end users typically ask (revenue trends, cohort analysis, warehouse
  metrics, and so on) and you want the LLM to hand those questions off to
  the Data Agent rather than re-implement the query logic.
- All target users have Fabric licenses and access to the Data Agent
  workspace.

Do not use it when:

- The deployment allows anonymous chat. It requires a signed-in user and
  cannot fall back to managed identity or app-only auth.
- The users do not have Fabric licenses or workspace access.
- Your compliance posture does not allow data flow outside the Azure
  compliance boundary. See the [data egress caveat](#data-egress-caveat)
  below.

## Fabric Data Agent vs Fabric ontology

Both knowledge sources ground on Microsoft Fabric data, and both can be
enabled on the same Knowledge Base. Pick the one that matches how your
Fabric content is exposed today.

| | Fabric Data Agent (`fabricDataAgent`) | Fabric ontology (`fabricOntology`) |
| --- | --- | --- |
| What it grounds on | A curated Fabric Data Agent that answers questions over your data. | A Fabric ontology exposing semantic models, lakehouses, warehouses, KQL. |
| Mental model | Virtual analyst. Hands the question to the Data Agent and gets an answer back. | Reasoning over entities and relationships in your business ontology. |
| Best when | You already invested in a Data Agent tuned for your business questions. | You have a modeled ontology and want the LLM to reason across it. |
| Response shape | Natural-language answer plus tabular evidence. | Grounded facts derived from the ontology. |
| App Config prefix | `FABRIC_DATA_AGENT_*` | `FABRIC_IQ_*` (historical name, configures `fabricOntology`) |

If both fit, start with the one your team already uses in Fabric. You can
add the other later on the same Knowledge Base.

## Prerequisites

Work through these in order. All of them are hard blockers.

1. **A Microsoft Fabric workspace with a Data Agent item.** The knowledge
   source binds to one Data Agent at a time, identified by the pair
   (`workspaceId`, `dataAgentId`).
2. **Tenant enablement.** The Fabric Data Agent feature must be enabled at
   the tenant level by a Fabric admin.
3. **Fabric-licensed end users** with access to the workspace and the
   Data Agent item. Fabric enforces per-user permissions natively over the
   OBO token; GPT-RAG does not add its own ACL layer for this source.
4. **Same Entra tenant.** The Fabric tenant, the Foundry / Search resource,
   and the GPT-RAG orchestrator must all be in the same Entra tenant.
   Cross-tenant is not supported.
5. **Foundry IQ preview API.** The knowledge source requires the Foundry IQ
   preview API that supports `kind: fabricDataAgent`. GPT-RAG v3.4.3 pins
   the `2026-05-01-preview` baseline.

## Configure Fabric Data Agent

The Fabric Data Agent source is opt-in and defaults to off. `azd provision`
(v3.4.3+) seeds the four keys automatically under the `gpt-rag` label with
`FABRIC_DATA_AGENT_ENABLED=false` and the workspace, data agent, and
knowledge-source name as empty strings. You do not have to create them by
hand. To turn it on for an existing environment, edit the values in the
App Configuration blade (or `az appconfig kv set --label gpt-rag --key
...`) and restart the orchestrator; or set the same values as azd env vars
and re-run `azd hooks run postprovision` and `azd deploy`.

| Key | Value |
| --- | --- |
| `FABRIC_DATA_AGENT_ENABLED` | `true` |
| `FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME` | Any name for the KS; must match on both provision and orchestrator. Example: `fabric-data-agent-ks`. |
| `FABRIC_DATA_AGENT_WORKSPACE_ID` | GUID of the Fabric workspace that owns the Data Agent. |
| `FABRIC_DATA_AGENT_DATA_AGENT_ID` | GUID of the Data Agent item within that workspace. |

At the API level the knowledge source is registered with `kind:
fabricDataAgent` and:

```json
{
  "kind": "fabricDataAgent",
  "fabricDataAgentParameters": {
    "workspaceId": "<FABRIC_DATA_AGENT_WORKSPACE_ID>",
    "dataAgentId": "<FABRIC_DATA_AGENT_DATA_AGENT_ID>"
  }
}
```

`azd provision` renders the search resources and registers the Fabric
Data Agent knowledge source on the Foundry IQ knowledge base. `azd deploy`
restarts the orchestrator so it picks up the enable flag and knowledge
source name.

The four keys must all be set for the knowledge source to be registered.
If any of `FABRIC_DATA_AGENT_KNOWLEDGE_SOURCE_NAME`,
`FABRIC_DATA_AGENT_WORKSPACE_ID`, or `FABRIC_DATA_AGENT_DATA_AGENT_ID` is
empty, GPT-RAG skips the source and continues with document grounding
(and Work IQ / Fabric ontology, if enabled).

## How it works at runtime

When the source is enabled and a signed-in user asks a question:

1. The orchestrator obtains an OBO token for the user, the same way it does
   for Work IQ and the Fabric ontology source.
2. The Foundry IQ retrieve call includes the Fabric Data Agent knowledge
   source in `knowledgeSourceParams` and forwards the OBO token as the
   `x-ms-query-source-authorization` header.
3. Fabric evaluates the user permissions and hands the question to the
   Data Agent, which runs one or more queries over the underlying Fabric
   data.
4. The response comes back with a natural-language answer and a tabular
   extract. The orchestrator normalizes both into the standard reference
   shape and hands them to the LLM alongside document references.

Local Foundry IQ document sources always serve the request. If the OBO
token is missing (for example, a background job), the Fabric Data Agent
source is skipped with a warning and only local sources contribute.
Managed identity is never used to reach this source, by design.

## Data egress caveat

Fabric Data Agent forwards the caller OBO token to Microsoft Fabric and
returns grounded answers plus tabular evidence from Fabric data back to
the orchestrator. Operators enabling Fabric Data Agent should determine
whether this data flow is permitted by their tenant data-boundary and
Fabric-workspace access policies before turning the flag on. Grounded
content still ends up in orchestrator responses and, transitively, in
downstream telemetry and chat history.

## Troubleshooting

- **No Fabric Data Agent answers in responses.** Confirm all four App
  Configuration keys are set. Check the orchestrator logs for a "Fabric
  Data Agent knowledge source skipped" warning; that usually points at a
  missing OBO token, an empty knowledge source name, or an empty
  workspace / data agent id.
- **`403` or empty results from Fabric.** Verify the signed-in user has
  access to the Fabric workspace and the Data Agent item. Fabric enforces
  per-user permissions, so an OBO token for a user without Data Agent
  access will return an empty result.
- **`400` on knowledge source registration.** Confirm the Foundry IQ
  preview API version pinned by GPT-RAG matches your Foundry resource.
  The Fabric Data Agent source requires `2026-05-01-preview` at minimum.

## Related reading

- [Grounding sources overview](howto_grounding_overview.md)
- [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md)
- [Foundry IQ: Work IQ (Microsoft 365)](howto_grounding_work_iq.md)
- [Foundry IQ: Fabric ontology](howto_grounding_fabric_ontology.md)