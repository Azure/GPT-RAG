The **GPT-RAG Data Ingestion** service automates the processing of diverse document types, such as PDFs, images, spreadsheets, transcripts, and SharePoint files, preparing them for indexing in Azure AI Search. It uses intelligent chunking strategies tailored to each format, generates text and image embeddings, and enables rich, multimodal retrieval experiences for agent-based RAG applications.

!!! note "Develop adoption, not a release"
    [Adoption status and approval scope](contributing.md#develop-adoption-status)
    supersede the historical “unmerged” and pending-exception labels below.
    Source pins remain implementation evidence; released manifest pins are unchanged.
    See that record for active rules, reference runs and remaining validation gaps.

## Key Features

- **Multi-Format Processing**: Handles PDFs, images, spreadsheets, transcripts, and SharePoint content
- **Intelligent Chunking**: Format-specific chunking strategies for optimal retrieval
- **Multimodal Embeddings**: Generates both text and image embeddings
- **Automated Workflows**: Scans sources, processes content, and indexes documents automatically
- **Scheduled Execution**: CRON-based scheduler for continuous data ingestion
- **Multiple Data Sources**: Supports Blob Storage, SharePoint, and NL2SQL metadata
- **Custom Metadata Tagging**: Blob metadata is automatically indexed into the `custom_metadata` field so documents can be filtered and faceted by tag. See [Custom blob metadata](ingestion_blob_data_source.md#custom-blob-metadata).

## Data sources

- [Blob Storage](ingestion_blob_data_source.md)
- [NL2SQL Metadata](ingestion_nl2sql_data_source.md)
- [SharePoint](ingestion_sharepoint_source.md)

## How to deploy the data ingestion service

**Prerequisites**

Provision the infrastructure first by following the [Deployment Guide](deploy.md). This ensures all required Azure resources (e.g., Container App, Storage, AI Search) are in place before deploying the data ingestion service.

**Required Tools:**

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) (optional, if using azd)
- [Git](https://git-scm.com/downloads)
- [Python 3.12](https://www.python.org/downloads/release/python-3120/)
- [Docker CLI](https://docs.docker.com/get-docker/)
- [VS Code](https://code.visualstudio.com/download) (recommended)

**Required Permissions (for customization):**

| Resource                | Role                                | Description                              |
| ----------------------- | ----------------------------------- | ---------------------------------------- |
| App Configuration Store | App Configuration Data Owner        | Full control over configuration settings |
| Container Registry      | AcrPush                             | Push and pull container images           |
| AI Search Service       | Search Index Data Contributor       | Read and write index data                |
| Storage Account         | Storage Blob Data Contributor       | Read and write blob data                 |
| Cosmos DB               | Cosmos DB Built-in Data Contributor | Read and write documents in Cosmos DB    |

**Required Permissions (for deployment):**

| Resource            | Role                             | Description           |
| ------------------- | -------------------------------- | --------------------- |
| App Configuration   | App Configuration Data Reader    | Read config           |
| Container Registry  | AcrPush                          | Push images           |
| Container App       | Azure Container Apps Contributor | Manage Container Apps |

**Deployment steps**

Make sure you're logged in to Azure before anything else:

```bash
az login
```

Clone this repository.

**If you used `azd provision`**

Just run:

```shell
azd env refresh
azd deploy 
```

> 
> Make sure you use the **same** subscription, resource group, environment name, and location from `azd provision`.

**If you did **not** use `azd provision`**

You need to set the App Configuration endpoint and run the deploy script.

**Bash (Linux/macOS):**

```bash
export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
./scripts/deploy.sh
```

**PowerShell (Windows):**

```powershell
$env:APP_CONFIG_ENDPOINT = "https://<your-app-config-name>.azconfig.io"
.\scripts\deploy.ps1
```

## Observability

!!! warning "Unmerged configuration fallback and overview follow-up"
    [Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296)
    at [`eb42bbb`](https://github.com/Azure/gpt-rag-ingestion/commit/eb42bbb155613ba570f891b67366967387735e32)
    makes configured fallback diagnostics explicit (H1). `APP_CONFIG_ENDPOINT`
    remains required. Endpoint loading uses managed identity then Azure CLI
    credentials; only an explicitly configured
    `AZURE_APPCONFIG_CONNECTION_STRING` is tried next. Both provider paths
    select wildcard keys for `gpt-rag-ingestion`,
    `gpt-rag`, then no label, with the last selected value winning.
    Key Vault credentials, selectors and source order remain unchanged.
    With no connection string, environment-only recovery requires the existing
    `allow_environment_variables` opt-in. Its nonempty-string semantics are
    unchanged: even `"false"` or `"0"` enables it; unset or empty disables it.
    Successful fallback emits a safe source diagnostic without configuration
    values or exception payloads. With no enabled fallback the endpoint error
    propagates; a connection-string load failure also propagates, rather than
    proceeding to environment reads. Missing required settings still fail.
    Investigate the endpoint, credential access and configured source health;
    restore that source or deliberately configure an allowed fallback and
    retry startup. Do not enable environment overrides merely to mask failure.

    The legacy `/api/panel/overview` adds `feedback.available` (H2).
    A complete feedback read sets it to `true`, including a genuine zero
    result. Feedback read or aggregation failure still returns HTTP 200 with
    jobs/files, but sets it to `false` and resets `totalRecords`, `upCount`
    and `downCount` to integer zero placeholders, discarding partial counts.
    Consumers must check availability before interpreting those integers.
    Inspect the safe server warning, restore feedback-store access or repair
    malformed feedback data, then retry; only `available=true` establishes a
    complete summary. The separate frontend `/panel/overview/metrics` and its
    privacy-suppressed null counts are unchanged, as is authorization.
    These are unmerged source-specific outcomes, not handler approvals,
    released behavior or changes to the shipped manifest.

!!! warning "Unmerged P2 unblock error correction"
    Ingestion [`34a6043`](https://github.com/Azure/gpt-rag-ingestion/commit/34a6043ea3b6c563e528aad69c0ae70e3be32ff4)
    distinguishes a confirmed missing file log (`ResourceNotFoundError`, HTTP
    404) from other download/read failures (generic HTTP 500). Invalid JSON or
    a non-object log returns a separate generic integrity 500. These failures
    neither upload a replacement log nor invalidate the files cache. A 500 is
    not evidence that the file is absent or unblocked; inspect service health
    or log integrity before retrying. Existing authorization and successful
    unblock writes remain unchanged. This is an offline-tested candidate in
    [#296](https://github.com/Azure/gpt-rag-ingestion/pull/296), not released behavior.

Monitor ingestion job execution and performance using Application Insights. The following query retrieves detailed metrics for completed ingestion runs, including indexing and purging operations.

Interpret run summaries together with per-document errors and item status.
A `RUN-COMPLETE` marker or nonempty chunk output alone does not prove that every
document was indexed successfully. Optional figure or caption fallbacks are
separate from failures of required document processing. Chunking-only results
also do not establish successful writes to Azure AI Search.

!!! warning "Unmerged chunking failure-handling preview"
    [Azure/gpt-rag-ingestion#296](https://github.com/Azure/gpt-rag-ingestion/pull/296)
    checkpoint [`26358cb`](https://github.com/Azure/gpt-rag-ingestion/commit/26358cb8f57c982e3c80171bf8dc6b154491388d)
    retains per-document failures in the existing `errors` list using generic
    messages rather than upstream exception details. Cancellation and process
    interrupts are no longer suppressed by a return in `finally`.
    Analysis retries are bounded and apply to declared SDK/Requests failures,
    not arbitrary implementation defects. Cleanup is attempted for owned
    PDF resources and temporary files on success and failure; cleanup warnings
    do not prove deletion or turn a failed primary operation into success.

    Successful chunk IDs, order, content, schemas and ACL metadata are
    unchanged. These corrections apply to GPT-RAG's custom ingestion path,
    not Foundry IQ's managed `azureBlob` pipeline. The checkpoint has offline
    chunker/parser and CI evidence, not live source-to-Search integration,
    released behavior or approval of its proposed exception.
    See the [multimodal enrichment boundary](howto_multimodality.md#ingestion)
    for optional figure and caption outcomes.

!!! warning "Unmerged worker and purge outcome corrections"
    At checkpoint [`0f7b1ce`](https://github.com/Azure/gpt-rag-ingestion/commit/0f7b1cea85078c7ee4260a20fe4f66255976cb12),
    Blob metadata and SharePoint permission lookup failures produce failed items
    instead of indexing with empty fallback ACLs. Successful ACL fields and
    normalization are unchanged; a failed lookup is not a valid empty result.
    Search writes require matching SDK confirmations. SharePoint purge retains
    confirmed partial deletion counts, but failed scans, counts or unconfirmed
    deletions cannot produce a successful `finished` outcome.

    Image purging completes and validates all pages of `relatedImages` before
    any asynchronous Blob deletion; a failed scan cannot become an empty
    reference set. Worker-owned child tasks are cancelled and observed on
    source failure or timeout. Owned resource cleanup is attempted on partial
    initialization, failure and cancellation, with explicit cleanup diagnostics.
    These are unmerged corrections, not a snapshot-isolation guarantee for
    changing sources, live integration evidence or active exception approvals.
    Code rollback does not restore already deleted data or undo persisted
    configuration writes. Existing public metric and event names are retained.

!!! warning "Unmerged P1 finalization corrections"
    Candidate ingestion commit: `926a08d6b1ad75254fed4447a3e72e17c0bf8703`.

    Retrieval query failures retain their sanitized `502` response, and query
    cancellation propagates, even if Search cleanup fails. Without a prior
    query failure, cleanup failure still propagates. Blob terminal-summary
    failures cannot replace an established run failure or cancellation;
    summary failure after an otherwise completed pipeline still propagates.
    Summary persistence and resource cleanup remain attempts, not guarantees,
    with bounded failure diagnostics.

    NL2SQL child cancellation propagates through the run/audit wrapper rather
    than becoming a `finished` run with an ordinary failed-document count.
    Ordinary document errors retain their per-record behavior. These unmerged
    changes do not alter public event schemas or make optional audit export
    authoritative for primary-operation success.

**Application Insights Query**

Navigate to your Application Insights resource in the Azure Portal, go to **Logs**, and run the following query:

```kusto
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "RUN-COMPLETE"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "RUN-COMPLETE"
| extend indexerType = extract('\\[([^\\]]+)\\]', 1, message)
| project timestamp,
          indexerType,
          runId = tostring(payload.runId),
          status = tostring(payload.status),
          collectionsSeen = toint(payload.collectionsSeen),
          // Indexer columns (work on items)
          itemsDiscovered = toint(payload.itemsDiscovered),
          itemsIndexed = toint(payload.itemsIndexed),
          itemsFailed = toint(payload.itemsFailed),
          // Purger columns (work on chunks)
          chunksChecked = toint(payload.chunksChecked),
          chunksDeleted = toint(payload.chunksDeleted),
          chunksFailedDelete = toint(payload.chunksFailedDelete),
          // Common
          durationSeconds = todouble(payload.durationSeconds)
| order by timestamp desc
```

**Query Fields**

This query returns the following metrics for each ingestion run:

| Column | Description |
|--------|-------------|
| `timestamp` | When the job completed |
| `indexerType` | Type of indexer (e.g., Blob, SharePoint, NL2SQL) |
| `runId` | Unique identifier for the run |
| `status` | Job completion status |
| `collectionsSeen` | Number of collections processed |
| `itemsDiscovered` | Total items found during scan |
| `itemsIndexed` | Items successfully indexed |
| `itemsFailed` | Items that failed to index |
| `chunksChecked` | Chunks verified during purge |
| `chunksScanned` | Total chunks scanned |
| `chunksDeleted` | Chunks removed from index |
| `chunksFailedDelete` | Chunks that failed deletion |
| `searchPages` | Number of search result pages processed |
| `durationSeconds` | Total execution time in seconds |
