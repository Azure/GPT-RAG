# Foundry IQ: Fabric IQ (Microsoft Fabric)

Fabric IQ is a Foundry IQ Knowledge Source that grounds answers on data in a
Microsoft Fabric ontology: semantic models, lakehouses, warehouses, and KQL
databases exposed through that ontology. It runs next to your document
Knowledge Source and (optionally) Work IQ on the same Knowledge Base. It
does not replace them.

If you have not read the [Grounding sources overview](howto_grounding_overview.md),
start there. In short: Fabric IQ is not a separate retrieval backend. It is
a Knowledge Source registered on the Foundry IQ Knowledge Base, so a single
request can pull from documents, from Microsoft 365 (via Work IQ), and from
Fabric analytical data in one call.

!!! warning "Preview, per-user auth, data leaves the Azure boundary"
    Fabric IQ uses a preview Foundry IQ API and requires an on-behalf-of
    (OBO) token for the signed-in user. Fabric IQ may route requests and
    intermediate data outside the Azure compliance boundary; operators must
    review this before enabling. Behavior and configuration may change
    without notice. Do not depend on Fabric IQ for production workloads
    until it is generally available.

## When to use Fabric IQ

Use Fabric IQ when:

- Users sign in to the GPT-RAG UI (or another authenticated client), so the
  orchestrator can obtain a delegated (OBO) token for the user.
- Answers benefit from live analytical data that lives in Fabric: revenue
  by region, headcount by team, warehouse metrics, or facts and dimensions
  a semantic model exposes.
- All target users have Fabric licenses and workspace access to the
  ontology.

Do not use Fabric IQ when:

- The deployment allows anonymous chat. Fabric IQ requires a signed-in user
  and cannot fall back to managed identity or app-only auth.
- The users do not have Fabric licenses or workspace access.
- Your compliance posture does not allow data flow outside the Azure
  compliance boundary. See the [data egress caveat](#data-egress-caveat)
  below.

## Prerequisites

Work through these in order. All of them are hard blockers.

1. **A Microsoft Fabric workspace with an ontology item.** Fabric IQ binds
   to one ontology at a time, identified by the pair (`workspaceId`,
   `ontologyId`). The ontology exposes the underlying semantic model,
   lakehouse, warehouse, or KQL data.
2. **Tenant enablement.** The Fabric ontology feature must be enabled at
   the tenant level by a Fabric admin.
3. **Fabric-licensed end users** with access to the workspace and the
   ontology. Fabric enforces per-user permissions natively over the OBO
   token; GPT-RAG does not add its own ACL layer for Fabric IQ.
4. **Same Entra tenant.** The Fabric tenant, the Foundry / Search resource,
   and the GPT-RAG orchestrator must all be in the same Entra tenant.
   Cross-tenant is not supported.
5. **Foundry IQ preview API.** Fabric IQ requires the Foundry IQ preview
   API that supports `kind: fabricOntology`. GPT-RAG v3.4.0 pins the
   `2026-05-01-preview` baseline.

## Configure Fabric IQ

Fabric IQ is opt-in and defaults to off. Set the following App
Configuration values (label `gpt-rag`) before you run `azd provision` or
`azd deploy`:

| Key | Value |
| --- | --- |
| `FABRIC_IQ_ENABLED` | `true` |
| `FABRIC_IQ_KNOWLEDGE_SOURCE_NAME` | Any name for the KS; must match on both provision and orchestrator. Example: `fabric-iq-ks`. |
| `FABRIC_IQ_WORKSPACE_ID` | GUID of the Fabric workspace that owns the ontology. |
| `FABRIC_IQ_ONTOLOGY_ID` | GUID of the ontology item within that workspace. |

`azd provision` renders the search resources and registers the Fabric IQ
knowledge source on the Foundry IQ Knowledge Base. `azd deploy` restarts
the orchestrator so it picks up the enable flag and knowledge source name.

The four keys must all be set for the knowledge source to be registered.
If any of `FABRIC_IQ_KNOWLEDGE_SOURCE_NAME`, `FABRIC_IQ_WORKSPACE_ID`, or
`FABRIC_IQ_ONTOLOGY_ID` is empty, GPT-RAG skips the Fabric IQ knowledge
source and continues with document grounding (and Work IQ, if enabled).

## How it works at runtime

When Fabric IQ is enabled and a signed-in user asks a question:

1. The orchestrator obtains an OBO token for the user, the same way it does
   for Work IQ.
2. The Foundry IQ retrieve call includes the Fabric IQ knowledge source in
   `knowledgeSourceParams` and forwards the OBO token as the
   `x-ms-query-source-authorization` header.
3. Fabric evaluates the user's ontology permissions and runs the underlying
   query on the semantic model, lakehouse, warehouse, or KQL database.
4. The response comes back with `fabricAnswer` (natural language) and
   `fabricRawData` (a CSV-style extract). The orchestrator normalizes both
   into the standard reference shape and hands them to the LLM alongside
   document references.

Local Foundry IQ document sources always serve the request. If the OBO
token is missing (for example, a background job), the Fabric IQ source is
skipped with a warning and only local sources contribute. Managed identity
is never used to reach Fabric IQ, by design.

## Data egress caveat

Fabric IQ may route request data and intermediate answers to Fabric
endpoints that are not part of the Azure compliance boundary you selected
for the Foundry / Search resource. Review this with your compliance team
before enabling Fabric IQ on any tenant with data residency, sovereign
cloud, or regulated-data constraints. If Fabric egress is not acceptable,
do not enable Fabric IQ; document grounding and Work IQ are unaffected.

## Troubleshooting

- **No Fabric answers in responses.** Confirm all four App Configuration
  keys are set. Check the orchestrator logs for a "Fabric IQ knowledge
  source skipped" warning; that usually points at a missing OBO token, an
  empty knowledge source name, or an empty workspace / ontology id.
- **`403` or empty results from Fabric.** Verify the signed-in user has
  access to the Fabric workspace and the ontology item. Fabric enforces
  per-user permissions, so an OBO token for a user without ontology access
  will return an empty result.
- **`400` on knowledge source registration.** Confirm the Foundry IQ
  Preview API version pinned by GPT-RAG matches your Foundry resource.
  Fabric IQ requires `2026-05-01-preview` at minimum.

## Related reading

- [Grounding sources overview](howto_grounding_overview.md)
- [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md)
- [Foundry IQ: Work IQ (Microsoft 365)](howto_grounding_work_iq.md)
