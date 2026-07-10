# Foundry IQ: Fabric IQ (planned)

Fabric IQ is a planned Foundry IQ Knowledge Source that grounds answers on
data in Microsoft Fabric and OneLake: semantic models, lakehouses, and
warehouses. It is **not yet available in GPT-RAG** as of v3.3.0. This page
exists so operators know what Fabric IQ is, what it will require, and why
they cannot enable it today.

If you have not read the [Grounding sources overview](howto_grounding_overview.md),
start there. Fabric IQ, like Work IQ, is a Knowledge Source on the Foundry
IQ Knowledge Base. It is not a separate retrieval backend.

## Status

Not shipped in GPT-RAG. Tracked as a follow-up to
[Azure/GPT-RAG#543](https://github.com/Azure/GPT-RAG/issues/543).

- Fabric IQ is not implemented in the orchestrator today.
- GPT-RAG deployment does not provision a Fabric IQ Knowledge Source.
- There are no supported configuration keys for Fabric IQ in App
  Configuration. Do not set imaginary values, they will not do anything.

Enable Work IQ today if you need a non-document grounding source. Fabric IQ
will follow in a future release.

## What Fabric IQ is

Fabric IQ lets Foundry IQ query Microsoft Fabric and OneLake artifacts as a
grounding source. Instead of indexing extracts of Fabric data into Azure AI
Search, Foundry IQ talks to Fabric directly and returns permission-trimmed
results based on the user's Fabric permissions.

Fabric IQ targets structured and semi-structured analytical data that lives
in Fabric:

- Fabric semantic models (Power BI datasets), for measures, dimensions, and
  aggregated business metrics.
- Lakehouses, for tables and files stored in OneLake.
- Warehouses, for relational data in Fabric.

The value in GPT-RAG will be the ability to answer questions like "what was
last quarter's revenue by region" from live Fabric data, blended with
documents from the same Knowledge Base, in one call.

## What GPT-RAG will need to enable it

When Fabric IQ ships in GPT-RAG, expect these prerequisites. These are
Fabric-side requirements, not GPT-RAG-side ones. They apply regardless of
which platform consumes Fabric IQ.

- **Fabric capacity.** An F-SKU Fabric capacity in the same tenant as the
  Foundry resource. Trials do not count for production.
- **Fabric artifacts.** At least one semantic model, lakehouse, or
  warehouse to ground on, with the appropriate Fabric workspace roles
  granted so the ingested permissions have something to evaluate.
- **Same-tenant Foundry.** The Foundry resource and the Fabric tenant must
  be in the same Entra tenant. Cross-tenant is not on the roadmap.
- **Signed-in users.** Fabric IQ will use delegated (OBO) authentication so
  Fabric can enforce per-user permissions. Anonymous chat will not be able
  to call Fabric IQ, for the same reason Work IQ cannot.
- **Foundry IQ API version.** Fabric IQ will require the Foundry IQ preview
  API that supports the Fabric Knowledge Source kind. The current
  `2026-05-01-preview` API is the baseline. A later preview may be
  required.

## Why it is not shipped yet

- The Fabric IQ Knowledge Source kind is still moving through preview on
  the Foundry IQ side.
- Enabling and testing Fabric IQ end to end requires a Fabric capacity in
  the test subscription. The GPT-RAG maintainers do not have that in the
  main development subscription today. Adding it is part of the follow-up
  work tracked in [Azure/GPT-RAG#543](https://github.com/Azure/GPT-RAG/issues/543).
- Until the maintainers can validate Fabric IQ against a real Fabric
  workspace, GPT-RAG will not ship configuration keys or provisioning
  steps for it. Documentation and defaults you can trust matter more than
  a half-tested toggle.

## What you can do today

- If your users need Microsoft 365 context (mail, meetings, files, chats,
  people), enable [Work IQ](howto_grounding_work_iq.md). Work IQ shipped
  in GPT-RAG v3.3.0 and follows the same "extra Knowledge Source on the
  Foundry IQ Knowledge Base" pattern that Fabric IQ will use.
- If you have analytical data in Fabric that users want to ask questions
  about today, keep it out of the GPT-RAG retrieval path for now. The
  NL2SQL orchestrator strategy (`AGENT_STRATEGY=nl2sql`) can be pointed at
  a SQL data source, and Fabric warehouses are queryable through the
  standard SQL endpoint. That is a separate integration from Fabric IQ.
- Subscribe to [Azure/GPT-RAG#543](https://github.com/Azure/GPT-RAG/issues/543)
  and the [What's New](whatisnew.md) page for updates.

## Related reading

- [Grounding sources overview](howto_grounding_overview.md)
- [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md)
- [Foundry IQ: Work IQ (Microsoft 365)](howto_grounding_work_iq.md)
