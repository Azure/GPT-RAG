The **GPT-RAG Data Ingestion** service automates the processing of diverse document types, such as PDFs, images, spreadsheets, transcripts, and SharePoint files, preparing them for indexing in Azure AI Search. It uses intelligent chunking strategies tailored to each format, generates text and image embeddings, and enables rich, multimodal retrieval experiences for agent-based RAG applications.

## Key Features

- **Multi-Format Processing**: Handles PDFs, images, spreadsheets, transcripts, and SharePoint content
- **Intelligent Chunking**: Format-specific chunking strategies for optimal retrieval
- **Multimodal Embeddings**: Generates both text and image embeddings
- **Automated Workflows**: Scans sources, processes content, and indexes documents automatically
- **Scheduled Execution**: CRON-based scheduler for continuous data ingestion
- **Multiple Data Sources**: Supports Blob Storage, SharePoint, and NL2SQL metadata

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

Monitor ingestion job execution and performance using Application Insights. The following query retrieves detailed metrics for completed ingestion runs, including indexing and purging operations.

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

