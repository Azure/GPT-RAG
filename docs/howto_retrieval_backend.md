# Retrieval backend selection

Use this guide when you need to decide whether GPT-RAG should retrieve from the
direct Azure AI Search index or from a Foundry IQ knowledge base.

Starting with GPT-RAG v3.0.2 and AI Landing Zone v2.1.2, new deployments use
Foundry IQ by default through a native Azure Blob Knowledge Source. The
deployment provisions the Knowledge Source and Knowledge Base automatically, and
Foundry IQ processes files directly from the `documents` container.

Existing deployments can keep using:

```text
RETRIEVAL_BACKEND=ai_search
```

If you need to keep using a custom GPT-RAG ingestion pipeline, use the
`searchIndex` pattern. In that mode, GPT-RAG ingestion processes the files and
writes the chunks to Azure AI Search, and Foundry IQ retrieves from that index
instead of processing the files directly.

## The two backends

| Backend | What it uses | Best for | Operator impact |
| --- | --- | --- | --- |
| `ai_search` | The GPT-RAG Azure AI Search index, usually `ragindex`. | Existing deployments that are not migrating yet, or deployments that intentionally keep all retrieval on the GPT-RAG index. | No migration required. This remains the rollback path. |
| `foundry_iq` | A Foundry IQ knowledge base hosted by Azure AI Search agentic retrieval. | New v3.0.2+ deployments and deployments that want Foundry IQ to own the retrieval path. | The default `azureBlob` path is provisioned automatically by AI Landing Zone v2.1.2+. |

```mermaid
flowchart LR
  User[User asks a question] --> Orchestrator[GPT-RAG orchestrator]
  Orchestrator --> Choice{RETRIEVAL_BACKEND}
  Choice -->|ai_search| Search[GPT-RAG Azure AI Search index]
  Choice -->|foundry_iq| KB[Foundry IQ knowledge base]
  KB --> SourceA[Pattern A: native Azure Blob source]
  KB --> SourceB[Pattern B: existing searchIndex]
```

## Pattern A and Pattern B

Foundry IQ still runs on Azure AI Search. The difference is who owns the source
and index lifecycle.

| Pattern | AILZ value | What it means | Use when |
| --- | --- | --- | --- |
| Pattern A: native Azure Blob source | `FOUNDRY_IQ_PATTERN=azureBlob` | Foundry IQ reads files directly from the `documents` container and owns source ingestion, chunking, vectorization, index creation, and refresh. | You want the default v3.0.2+ deployment path and do not need a custom GPT-RAG ingestion pipeline. |
| Pattern B: existing index | `FOUNDRY_IQ_PATTERN=searchIndex` | GPT-RAG ingestion processes files, writes chunks to Azure AI Search, and that existing index is registered as a Foundry IQ `searchIndex` knowledge source. | You need to keep using a custom GPT-RAG ingestion pipeline. |

Pattern B is for deployments that intentionally keep document processing outside
Foundry IQ. It keeps the current GPT-RAG ingestion pipeline and index schema
while routing retrieval through the Foundry IQ knowledge base.

## Security modes

There are two security mechanisms. They solve different problems and should not
be mixed up.

| Security mode | Used by | How it is enforced |
| --- | --- | --- |
| Native ingested permissions | Pattern A sources that ingest permissions, such as Azure Blob RBAC scope, ADLS Gen2 ACLs, SharePoint, OneLake/Fabric, or Purview labels. | The orchestrator forwards the user's delegated Search token in `x-ms-query-source-authorization`. Foundry IQ evaluates the ingested permissions. |
| GPT-RAG security fields | Pattern B with the existing GPT-RAG index. | The orchestrator sends an OData `filterAddOn` over GPT-RAG security fields. This is separate from the OBO header. |

Important rules:

- Plain Blob storage provides container-level RBAC for this purpose. Do not rely
  on it for per-document trimming unless you use Purview labels or an equivalent
  permission source.
- ADLS Gen2 ACLs, SharePoint, OneLake/Fabric, and Purview labels can support
  per-document permission trimming when native permission ingestion is
  configured.
- Pattern B uses the existing GPT-RAG index registered as a `searchIndex`
  knowledge source. GPT-RAG security fields are enforced through `filterAddOn`,
  not through `x-ms-query-source-authorization`.
- The `x-ms-query-source-authorization` header is for native ingested
  permissions.
- Per-user security uses the `2026-05-01-preview` Azure AI Search API.
- Security-enabled retrieval must fail closed. Missing token, filter, or
  permission configuration should be treated as an error, not as permission to
  run an unfiltered query.

## Configuration settings

All runtime settings are stored in Azure App Configuration with the `gpt-rag`
label, or supplied as container environment variables when you use the
`containerEnv` runtime mode.

| Setting | Default | Used when | Purpose |
| --- | --- | --- | --- |
| `RETRIEVAL_BACKEND` | `foundry_iq` for new v3.0.2+ deployments | Always | Selects `ai_search` or `foundry_iq`. Existing deployments can keep `ai_search` until they migrate. |
| `KNOWLEDGE_BASE_NAME` | Generated during deployment | `foundry_iq` | Foundry IQ knowledge base name. |
| `KNOWLEDGE_BASE_ENDPOINT` | Generated during deployment | `foundry_iq` | Azure AI Search endpoint that hosts the knowledge base. |
| `KNOWLEDGE_BASE_CONNECTION_ID` | Generated during deployment | `foundry_iq` | Dedicated AI Foundry connection ID for the knowledge base. Do not reuse `SEARCH_CONNECTION_ID`. |
| `FOUNDRY_IQ_API_VERSION` | `2026-05-01-preview` | `foundry_iq` | Required for native per-user permissions and Pattern B `filterAddOn`. |
| `FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN` | `free` | Provisioning and post-provision | Azure AI Search `knowledgeRetrieval` billing plan. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME` | Generated during deployment | `foundry_iq` | Name of the Foundry IQ knowledge source. |
| `FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND` | `azureBlob` | `foundry_iq` | Knowledge Source kind sent to Foundry IQ. Use `searchIndex` only for Pattern B. |
| `FOUNDRY_IQ_STORAGE_CONTAINER_NAME` | `documents` | Pattern A | Storage container that Foundry IQ reads directly. |
| `FOUNDRY_IQ_INGESTION_PERMISSION_OPTIONS` | `["rbacScope"]` | Pattern A | Permission metadata ingested by the native Azure Blob Knowledge Source. |
| `FOUNDRY_IQ_FILTER_ADD_ON_ENABLED` | `false` | Pattern B | Enables query-time GPT-RAG security filtering through `filterAddOn`. |
| `FOUNDRY_IQ_SECURITY_FIELD_NAME` | `metadata_security_id` | Pattern B | Field used to build the GPT-RAG security filter. |
| `FOUNDRY_IQ_MAX_OUTPUT_DOCUMENTS` | `5` | `foundry_iq` | Caps the number of documents returned by the knowledge base. |

The AI Landing Zone also stamps Pattern A and Pattern B setup values used by the
post-provision script:

| Setting | Purpose |
| --- | --- |
| `FOUNDRY_IQ_PATTERN` | `azureBlob` for Pattern A or `searchIndex` for Pattern B. |
| `FOUNDRY_IQ_SEARCH_INDEX_NAME` | Existing Azure AI Search index registered as the Pattern B knowledge source. |
| `FOUNDRY_IQ_SEMANTIC_CONFIGURATION_NAME` | Semantic configuration on the existing index. |
| `FOUNDRY_IQ_SOURCE_DATA_FIELDS` | Source fields exposed by the knowledge source. |
| `FOUNDRY_IQ_SEARCH_FIELDS` | Searchable fields used by the knowledge source. |
| `FOUNDRY_IQ_BASE_FILTER` | Optional persisted filter on the knowledge source. |

## Billing choice

Foundry IQ retrieval uses Azure AI Search agentic retrieval billing through the
Search service `knowledgeRetrieval` plan.

| Plan | Use when |
| --- | --- |
| `free` | You want to stay within the included allowance. Retrieval can fail when the allowance is exhausted. |
| `standard` | You explicitly opt in to pay-as-you-go retrieval after the included allowance. |

Set the plan before provisioning or before running the Foundry IQ post-provision
script:

```powershell
azd env set FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN free
```

Use `standard` only when the operator has approved the billing change.

## Default Foundry IQ deployment

For new GPT-RAG v3.0.2+ deployments with AI Landing Zone v2.1.2+, no manual
backend configuration is required. The default configuration is:

```text
RETRIEVAL_BACKEND=foundry_iq
FOUNDRY_IQ_PATTERN=azureBlob
FOUNDRY_IQ_KNOWLEDGE_SOURCE_KIND=azureBlob
FOUNDRY_IQ_STORAGE_CONTAINER_NAME=documents
```

The deployment creates a native Foundry IQ Azure Blob Knowledge Source and a
Knowledge Base. Foundry IQ processes files directly from the `documents`
container.

## Use Foundry IQ with a custom GPT-RAG ingestion pipeline

Use Pattern B only when you need to keep using a custom GPT-RAG ingestion
pipeline.

1. Start from a working `ai_search` deployment.
2. Set the Foundry IQ parameters before provisioning:

    ```powershell
    azd env set RETRIEVAL_BACKEND foundry_iq
    azd env set FOUNDRY_IQ_PATTERN searchIndex
    azd env set FOUNDRY_IQ_API_VERSION 2026-05-01-preview
    azd env set FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN free
    azd env set FOUNDRY_IQ_FILTER_ADD_ON_ENABLED true
    ```

3. Run `azd provision`.
4. Deploy or restart the orchestrator so it reads the backend selector at startup.

## Roll back to Azure AI Search

Rollback is intentionally simple.

1. Set the backend selector back to Azure AI Search:

    ```powershell
    az appconfig kv set `
      --name <app-config-name> `
      --key RETRIEVAL_BACKEND `
      --value ai_search `
      --label gpt-rag `
      --yes
    ```

2. Restart the orchestrator Container App so the startup selector is re-read.
3. Ask a known retrieval question and confirm citations come from the GPT-RAG
   Azure AI Search index.

You do not need to delete the knowledge base to roll back. Leave it in place
while you investigate.

## Migration guidance

- New GPT-RAG v3.0.2+ deployments use Foundry IQ Pattern A by default.
- Existing deployments can stay on `ai_search` until you explicitly migrate.
- Use Pattern B if you need to keep using a custom GPT-RAG ingestion pipeline.
- Do not claim per-document security for plain Blob unless you use Purview
  labels or another per-document permission source. The default Blob path uses
  RBAC scope permissions.
- Keep the rollback command ready during the first production change window.

## Known limitations

- Multimodal Pattern A captioning parity is deferred. Keep multimodal on
  `ai_search` or Pattern B until the native Foundry IQ output is proven
  equivalent.
- Runtime document uploads still need the self-managed GPT-RAG index for
  low-latency searchability. Use Pattern B for that path.
- Pattern A source refresh can take seconds to minutes. It is not a low-latency
  upload path.
- Pattern B requires the existing index to have a semantic configuration. Vector
  fields must have the expected vectorizer setup.
- The knowledge base and Pattern B index must live on the same Search service.
- Per-user security and `filterAddOn` require `2026-05-01-preview`.
