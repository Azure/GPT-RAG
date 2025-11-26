# Blob Data Source

The **Blob Data Source** ingests documents from Azure Blob Storage into Azure AI Search and keeps the index synchronized when files are updated or removed.

## How it Works

* **Indexing**
    * Scans the configured blob container (optionally filtered by `BLOB_PREFIX`)
    * Skips unchanged files
    * For each changed file:
          * Replaces existing chunks (by `parent_id`)
          * Uploads new chunks with stable, search-safe IDs
    * Each chunk document sets `source = "blob"` and, when available in blob metadata, includes `metadata_security_id`

* **Purging**
    * Compares storage parents with index parents (`source == "blob"`)
    * Deletes chunk documents for parents no longer present in storage
    * Waits briefly after deletion to ensure accurate document counts (Azure AI Search uses eventual consistency)

## Scheduling

Jobs are enabled through CRON expressions:

* `CRON_RUN_BLOB_INDEX`: runs the indexing job
* `CRON_RUN_BLOB_PURGE`: runs the purge job
* Leave unset to disable

The scheduler uses `SCHEDULER_TIMEZONE` (IANA format, e.g., `Europe/Berlin`), falling back to the host machine’s timezone if not specified.
On startup, if a CRON is configured, the corresponding job is scheduled and also triggered once immediately.

**Examples:**

* `0 * * * *` → hourly
* `*/15 * * * *` → every 15 minutes
* `0 0 * * *` → daily at midnight

## Settings

* `STORAGE_ACCOUNT_NAME` and `DOCUMENTS_STORAGE_CONTAINER`: source location
* `SEARCH_SERVICE_QUERY_ENDPOINT` and `SEARCH_RAG_INDEX_NAME`: target index
* `BLOB_PREFIX` *(optional)*: restricts the scan scope
* `JOBS_LOG_CONTAINER` *(default: jobs)*: container for logs
* `INDEXER_MAX_CONCURRENCY` and `INDEXER_BATCH_SIZE` *(optional)*: performance tuning; defaults: `4` (concurrency) and `500` (batch size)

>   
> `INDEXER_MAX_CONCURRENCY` controls how many files are processed in parallel (download → chunk → upload). `INDEXER_BATCH_SIZE` controls how many chunk documents are sent in each upload call to Azure AI Search. Increase these to raise throughput, but watch for throttling (HTTP 429), timeouts, and memory usage; lower them if you see retries or instability. The default batch size (500) follows common guidance to keep batches reasonable (typically ≤ 1000).

## Logs

Both jobs write logs to the configured jobs container. Logs are grouped by job type:

* **Indexer (`blob-storage-indexer`)**
    * Per-file logs and per-run summaries under `files/` and `runs/`
    * Summaries include: `sourceFiles`, `candidates`, `success/failed`, `totalChunksUploaded`

* **Purger (`blob-storage-purger`)**
    * Per-run summaries under `runs/`
    * Summaries include: `blobDocumentsCount`, `indexParentsCountBefore/After`, `indexChunkDocumentsBefore`, `indexParentsPurged`, `indexChunkDocumentsDeleted`

## Observability

The blob storage indexer emits structured Application Insights events (`RUN-*`, `ITEM-*`) with JSON payloads embedded in the `message` field.

### Latest Job Runs

View recent indexing jobs with key metrics:

```kql
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "RUN-COMPLETE" and message contains "blob-storage-indexer"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "RUN-COMPLETE"
| project timestamp,
          runId = tostring(payload.runId),
          status = tostring(payload.status),
          sourceFiles = toint(payload.sourceFiles),
          itemsDiscovered = toint(payload.itemsDiscovered),
          indexedItems = toint(payload.indexedItems),
          skippedNoChange = toint(payload.skippedNoChange),
          failed = toint(payload.failed),
          totalChunksUploaded = toint(payload.totalChunksUploaded),
          durationSeconds = todouble(payload.durationSeconds)
| order by timestamp desc
```

> If nothing returns, run `Logs | where message contains "blob-storage-indexer" | take 20` to inspect the raw log format.

### Items in Specific Run

List all files processed during a particular run:

```kql
let TargetRunId = '20251121T231125Z';
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "ITEM-COMPLETE" and message contains "blob-storage-indexer"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "ITEM-COMPLETE" and tostring(payload.runId) == TargetRunId
| project timestamp,
          blobName = tostring(payload.blobName),
          parentId = tostring(payload.parentId),
          status = tostring(payload.status),
          totalChunks = toint(payload.totalChunks),
          contentType = tostring(payload.contentType),
          fileUrl = tostring(payload.fileUrl)
| order by timestamp desc
```

### File Indexing History

Track processing history for a specific file:

```kql
let TargetParent = '/documents/employee_handbook.pdf';
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "ITEM-COMPLETE" and message contains "blob-storage-indexer"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "ITEM-COMPLETE" and tostring(payload.parentId) == TargetParent
| project timestamp,
          runId = tostring(payload.runId),
          blobName = tostring(payload.blobName),
          status = tostring(payload.status),
          totalChunks = toint(payload.totalChunks),
          contentType = tostring(payload.contentType),
          fileUrl = tostring(payload.fileUrl)
| order by timestamp desc
```

### Recent Errors

View recent warnings and errors:

```kql
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where severityLevel >= 3 and message contains "blob-storage-indexer"
| extend payload = parse_json(extract('\\{.*', 0, message))
| project timestamp,
          severityLevel,
          event = tostring(payload.event),
          runId = tostring(payload.runId),
          blobName = tostring(payload.blobName),
          parentId = tostring(payload.parentId),
          error = tostring(payload.error),
          message
| order by timestamp desc
```
