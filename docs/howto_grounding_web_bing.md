# Foundry IQ: Web (Grounding with Bing)

The `web` Foundry IQ knowledge source grounds answers on the public internet
using Grounding with Bing Search. It runs next to your document knowledge
source and (optionally) Work IQ, the Fabric ontology source, and the Fabric
Data Agent on the same knowledge base. It does not replace them.

If you have not read the [Grounding sources overview](howto_grounding_overview.md),
start there. In short: this knowledge source is not a separate retrieval
backend. It is registered on the Foundry IQ knowledge base, so a single
request can pull from documents, from Microsoft 365 (via Work IQ), and
from Bing in one call.

!!! warning "Preview, public internet, data leaves the Azure boundary"
    Web grounding uses a preview Foundry IQ API and calls Bing Search on the
    public internet. Requests and results route outside the Azure compliance
    boundary; operators must review this before enabling. Bing has its own
    per-call pricing and terms of use. Behavior and configuration may change
    without notice. Do not depend on it for production workloads until it
    is generally available.

> Complete the [Foundry IQ prerequisites](howto_grounding_foundry_iq_prereqs.md)
> first. The Prerequisites section below covers only what is specific to this
> source.

## When to use Web grounding

Use the Web knowledge source when:

- Users ask about topics that are inherently public and time-sensitive
  (news, market data, product releases, standards updates) and your indexed
  documents cannot keep up.
- You want to complement internal documents with fresh public context,
  without maintaining a separate crawler.
- You can accept Bing per-call pricing and public-internet data flow.

Do not use it when:

- Your compliance posture does not allow query terms or retrieved content
  to leave the Azure compliance boundary.
- The scenario is fully answerable from indexed enterprise content and
  adding web results would add noise rather than value.
- You need per-user ACL enforcement. Web results are public and have no
  access control. There is no on-behalf-of (OBO) flow for this source.

## Prerequisites

Work through these in order. All of them are hard blockers.

1. **Subscription feature enablement.** Web knowledge sources are gated by
   an Azure subscription feature on `Microsoft.Search`. Confirm the feature
   is enabled on the subscription that hosts your Search service. If the
   feature is not enabled, the knowledge source will fail to register with
   an `HTTP 400` from the Search control plane. Check with:

   ```sh
   az feature show --namespace Microsoft.Search --name WebKnowledgeSource
   ```

   Register it via `az feature register` and re-run `azd provision` if
   needed. Names and exact behavior are preview and may change.
2. **Bing Search terms of use.** Grounding with Bing is billed per call and
   subject to the Bing Search terms. An operator with authority to accept
   those terms must review them before enabling this source.
3. **Foundry IQ preview API.** The knowledge source requires the Foundry IQ
   preview API that supports `kind: web`. GPT-RAG v3.4+ pins the
   `2026-05-01-preview` baseline.

## Configure Web grounding

The Web source is opt-in and defaults to off. `azd provision` seeds the
four keys automatically under the `gpt-rag` label with
`WEB_GROUNDING_ENABLED=false` and the knowledge-source name plus domain
lists as empty strings. You do not have to create them by hand. To turn
it on for an existing environment, edit the values in the App
Configuration blade (or `az appconfig kv set --label gpt-rag --key ...`)
and restart the orchestrator; or set the same values as azd env vars and
re-run `azd hooks run postprovision` and `azd deploy`.

| Key | Value |
| --- | --- |
| `WEB_GROUNDING_ENABLED` | `true` to enable, `false` to disable. Default `false`. |
| `WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME` | Any name for the KS; must match on both provision and orchestrator. Example: `web-grounding-ks`. |
| `WEB_GROUNDING_ALLOWED_DOMAINS` | Optional. Comma, newline, or semicolon separated list of domains Bing is allowed to return. Example: `microsoft.com,learn.microsoft.com`. Empty means no allow-list filter. |
| `WEB_GROUNDING_BLOCKED_DOMAINS` | Optional. Comma, newline, or semicolon separated list of domains Bing must exclude. Empty means no block-list filter. |

At the API level the knowledge source is registered with `kind: web` and:

```json
{
  "kind": "web",
  "webParameters": {
    "domains": {
      "allowedDomains": ["microsoft.com", "learn.microsoft.com"],
      "blockedDomains": []
    }
  }
}
```

`azd provision` renders the search resources and registers the Web
knowledge source on the Foundry IQ knowledge base. `azd deploy` restarts
the orchestrator so it picks up the enable flag and knowledge source name.

If `WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME` is empty, GPT-RAG skips the
source and continues with document grounding (and Work IQ / Fabric
ontology / Fabric Data Agent, if enabled).

## How it works at runtime

When the source is enabled and a user asks a question:

1. The orchestrator adds the Web knowledge source to `knowledgeSourceParams`
   on the Foundry IQ retrieve call. No OBO token is attached; the source
   is public and has no ACL.
2. Foundry IQ calls Bing Search with the query and, if configured, the
   allow/block domain filter.
3. Bing returns results, which Foundry IQ folds into the retrieve response
   alongside document and Work IQ hits.
4. The orchestrator normalizes each web reference into the standard
   reference shape (`{title, link, content}`) and hands them to the LLM
   alongside internal references.

Local Foundry IQ document sources always serve the request. If Bing
fails or returns nothing, the Web source is skipped and only local
sources contribute.

## Cost and data flow

Bing Grounding is billed per call, separately from Azure AI Search and
Foundry IQ. Enabling this source will add a Bing charge on every
retrieval that includes web grounding, even when Bing returns no useful
hits.

Query terms are sent to Bing and web page snippets are returned to the
orchestrator. Both cross the public internet and land outside the Azure
compliance boundary. Grounded snippets still end up in orchestrator
responses and, transitively, in downstream telemetry and chat history.
Operators enabling Web grounding should determine whether this data flow
is permitted by their tenant data-boundary policies before turning the
flag on.

## Citations shape

Each web reference is normalized to the standard reference contract used
by the other Foundry IQ sources:

- `title`: page title from Bing (or the URL host as a fallback).
- `link`: absolute URL of the page.
- `content`: snippet or short summary Bing returned for the page.

The LLM sees these alongside document and Work IQ references and cites
them the same way. If Bing returns a result without a title, the
orchestrator falls back to the URL host so that citations always have
something displayable.

## Troubleshooting

- **`400` on knowledge source registration mentioning `WebKnowledgeSource`
  or a similar feature name.** The subscription feature is not enabled.
  Register it with `az feature register --namespace Microsoft.Search
  --name WebKnowledgeSource` and re-run `azd provision`.
- **No web citations in responses.** Confirm `WEB_GROUNDING_ENABLED=true`
  and `WEB_GROUNDING_KNOWLEDGE_SOURCE_NAME` is non-empty. Restart the
  orchestrator so it picks up the App Config change.
- **Unexpected or missing domains.** Check the parsing of
  `WEB_GROUNDING_ALLOWED_DOMAINS` and `WEB_GROUNDING_BLOCKED_DOMAINS`.
  The values accept comma, newline, or semicolon as separators; entries
  are lowercased and de-duplicated. An empty list means no filter, not
  an implicit block.
- **Answers still favor internal documents.** Expected. Foundry IQ ranks
  across all knowledge sources; if internal documents match strongly,
  they may outrank web results. Tighten the query or narrow with an
  allow-list to bias toward web sources.

## Related reading

- [Grounding sources overview](howto_grounding_overview.md)
- [Foundry IQ: Documents](howto_grounding_foundry_iq_documents.md)
- [Foundry IQ: Work IQ (Microsoft 365)](howto_grounding_work_iq.md)
- [Foundry IQ: Fabric ontology](howto_grounding_fabric_ontology.md)
- [Foundry IQ: Fabric Data Agent](howto_grounding_fabric_data_agent.md)
