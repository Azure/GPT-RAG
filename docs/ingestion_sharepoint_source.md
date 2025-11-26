# SharePoint Data Source

The SharePoint connector keeps Azure AI Search synchronized with both structured list data and rich documents stored in SharePoint Online. It is designed for production-scale ingestion jobs where resiliency, incremental freshness, and search-ready chunking matter.

## Why This Connector

- **Unified coverage** – Mix generic lists (metadata-driven knowledge) and document libraries (files) in the same run.
- **Smart freshness** – Per-item timestamps (1 s tolerance) avoid reprocessing unchanged bodies or files.
- **Parallel but safe** – Unlimited collection discovery with controlled workers and AOAI throttling maximizes throughput.
- **Document-first search** – Files are chunked with Document Intelligence, embeddings generated, and zero-based chunk IDs ensure incremental updates compare correctly.
- **Security trimming** – Each item resolves Microsoft Graph permissions and stores Entra object IDs for search filtering.
- **Operational insight** – Detailed run summaries (`documentLibraryStats`, `itemsDiscovered`, ...) plus optional per-item blob logs.

Choose this connector when:

- SharePoint is the source of truth for policies, contracts, or curated knowledge lists.
- You need incremental crawls several times a day without flooding Azure OpenAI or AI Search.
- Governance requires honoring SharePoint ACLs inside the search index.


## What Gets Ingested

### Generic Lists
- Item fields are read from Graph (`fields` payload).
- Optional `includeFields` controls what is embedded.
- Lookup columns are resolved (cached per list) unless they target hidden system lists (e.g., `AppPrincipals`, `UserInfo`, taxonomy caches).
- Attachments in generic lists are **not** downloaded.

### Document Libraries
- Files (default extensions: `pdf, docx, pptx`) are downloaded and chunked through Document Intelligence.
- Chunk IDs now start at 0, enabling `_get_body_lastmod_by_id` to detect unchanged files accurately.
- Freshness compares SharePoint `lastModifiedDateTime` vs. the indexed parent; stale files land in `documentLibraryStats.skippedNotNewer`.

### Permissions
- Each item calls `get_item_permission_object_ids` (Graph **beta** `/permissions`) to capture explicit Entra user/group IDs.
- Only GUID-backed identities (users/groups/app registrations/devices) are stored.

## Configuration

For detailed setup instructions, including app registration, permissions, and data source configuration, see the [SharePoint Connector Setup Guide](howto_sharepoint_connector.md).


## Processing Pipeline

The indexer uses **three tiers of parallelism** to balance speed and service limits:

### 1. Collection Discovery (Unlimited Parallelism)

<div class="no-wrap">
```
┌───────────────────────────────────────────────────────────────┐
│  Cosmos datasources (type: sharepoint_site)                   │
└───────────┬────────────────────────┬───────────────────┬──────┘
            │                        │                   │
            ▼                        ▼                   ▼
      ┌──────────┐             ┌──────────┐         ┌──────────┐
      │  List A  │             │  List B  │   ...   │  List N  │   ← All lists start simultaneously
      └─────┬────┘             └─────┬────┘         └─────┬────┘
            │                        │                    │
            └────────────────────────┴────────────────────┘
                             │
                             ▼ (fetch items via Graph API)
```
</div>


### 2. Item Processing (Controlled: ≤ 8 Workers)

<div class="no-wrap">
```
┌──────────────────────────────────────────────────────────────────┐
│  Global Worker Pool (INDEXER_MAX_CONCURRENCY = 4)                │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                 │
│  │Worker 1 │ │Worker 2 │ │Worker 3 │ │  ...4   │                 │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘                 │
└───────┼───────────┼───────────┼───────────┼──────────────────────┘
        │           │           │           │
        ▼           ▼           ▼           ▼
   ┌─────────────────────────────────────────────────────────┐
   │ Per-Item: freshness → process → upload                  │
   │ • Body (generic lists): list fields → text → embedding  │
   │ • Files (document libraries): download → chunk → embed  │
   └─────────────────────────────────────────────────────────┘
```
</div>

### 3. Embedding Generation (Throttled: ≤ 2 Concurrent)

<div class="no-wrap">
```
┌────────────────────────────────────────────────────────┐
│  AOAI Embedding Gate (AOAI_MAX_CONCURRENCY = 2)        │
│  ┌──────────┐ ┌──────────┐                             │
│  │  Slot 1  │ │  Slot 2  │  ← Only 2 embeddings run    │
│  └──────────┘ └──────────┘     at the same time        │
└────────────────────────────────────────────────────────┘
         ▲              ▲
         │              │
    Workers queue here when embedding is needed
    (workers skip this if freshness = unchanged)
```
</div>

**Why this design?**

- **Unlimited collections**: Graph API paging is fast and cheap.
- **8 item workers**: Balances SharePoint/AI Search load with throughput.
- **2 embedding slots**: Prevents Azure OpenAI rate limits (429 errors) while keeping other workers busy with downloads, freshness checks, and chunking.
    
    
### Parallelism At a Glance

| Layer | Control | Default | Notes |
|-------|---------|---------|-------|
| Collection enumeration | `asyncio.gather` | Unlimited | Each list runs independently.
| Item workers | Semaphore | `INDEXER_MAX_CONCURRENCY = 4` | Covers body + file work.
| Embeddings | Semaphore | `AOAI_MAX_CONCURRENCY = 2` | Applies to both bodies and files.
| Item timeout | `asyncio.wait_for` | 600 s | Cancels sluggish items.
| Collection timeout | `asyncio.wait_for` | 7200 s | Cancels stuck lists.


## Freshness & Deduplication

- **Body documents (generic lists)**: Fetches chunk `c00000` from the index. If SharePoint's `Modified` timestamp isn't newer, the item is skipped (`skippedNoChange`) without reprocessing.
- **Document library files**: Each file gets a parent key with the file name; chunk `0` stores the file's last modified time. Unchanged files increment `documentLibraryStats.skippedNotNewer`.
- **1-second tolerance**: An item is reindexed only if SharePoint's timestamp is >1 second newer than the index. This prevents unnecessary work when clocks differ slightly between SharePoint and Azure AI Search.


## Settings Cheat Sheet

| Category | Setting | Default | Purpose |
|----------|---------|---------|---------|
| Concurrency | `INDEXER_MAX_CONCURRENCY` | 4 | Item workers across all lists.
|  | `AOAI_MAX_CONCURRENCY` | 2 | Embedding throttle.
|  | `INDEXER_BATCH_SIZE` | 500 | Upload/delete batch size in AI Search.
| Timeouts | `INDEXER_ITEM_TIMEOUT_SECONDS` | 600 | Per-item budget.
|  | `LIST_GATHER_TIMEOUT_SECONDS` | 7200 | Per-list budget.
|  | `HTTP_TOTAL_TIMEOUT_SECONDS` | 120 | Graph calls.
|  | `BLOB_OP_TIMEOUT_SECONDS` | 20 | Blob writes.
| Retries | `AOAI_BACKOFF_MAX_SECONDS` | 60 | Max wait between AOAI retries.
|  | `AOAI_MAX_RATE_LIMIT_ATTEMPTS` | 8 | Rate limit (429) retries for embeddings.
|  | `AOAI_MAX_TRANSIENT_ATTEMPTS` | 8 | Network/timeout retries for embeddings.
| Documents | `SHAREPOINT_FILES_FORMAT` | `pdf,docx,pptx` | Allowed extensions.
| Logging | `JOBS_LOG_CONTAINER` | `jobs` | Blob container for logs.
|  | `DISABLE_STORAGE_LOGS` | unset | Set to `true/1` to skip blob logging.

> Tune `AOAI_MAX_CONCURRENCY` only if you confirmed higher TPM quotas. If Graph throttles (429), reduce `INDEXER_MAX_CONCURRENCY`.


## Error Handling & Retries

- **Azure OpenAI**: Rate limit errors (429) retry up to `AOAI_MAX_RATE_LIMIT_ATTEMPTS` (default: 8) respecting `Retry-After` headers; transient errors (network/timeout) retry up to `AOAI_MAX_TRANSIENT_ATTEMPTS` (default: 8) with exponential backoff + jitter; fatal errors bubble immediately.
- **Azure AI Search**: Upload/delete operations retry up to eight times (1 s → 30 s backoff) and honor `Retry-After`.
- **Microsoft Graph**: `GET` helper retries 6 times for throttling or transient failures, max 30 s backoff; client errors surface immediately.
- **Document Intelligence**: Chunker performs best-effort retries internally; if it fails (e.g., 503), the item is marked failed and can be retried on the next job run.
- **Timeouts**: Item-level timeouts cancel stuck workers; collection timeout aborts the entire list.


## Logging & Observability

The indexer writes logs to **two destinations**: **Application Insights** (always active) and **Azure Blob Storage** (optional).

### Application Insights

All indexer activity flows to Application Insights automatically. Below are the four most requested queries:

#### 1. Latest indexer runs
```kql
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "RUN-COMPLETE" and message contains "sharepoint-indexer"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "RUN-COMPLETE"
| extend indexerType = extract('\\[([^\\]]+)\\]', 1, message)
| where indexerType endswith "-indexer"  // Filtra apenas indexers
| project timestamp,
          indexerType,
          runId = tostring(payload.runId),
          status = tostring(payload.status),
          itemsDiscovered = toint(payload.itemsDiscovered),
          itemsIndexed = toint(payload.itemsIndexed),
          itemsFailed = toint(payload.itemsFailed),
          durationSeconds = todouble(payload.durationSeconds)
| order by timestamp desc
```

#### 2. All items indexed in a specific run
```kql
let TargetRunId = '20251121T212623Z';
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "ITEM-COMPLETE"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "ITEM-COMPLETE" and tostring(payload.runId) == TargetRunId
| project timestamp,
          collection = tostring(payload.collection),
          itemId = tostring(payload.itemId),
          parentId = tostring(payload.parentId),
          status = tostring(payload.status),
          attachmentChunks = toint(payload.attachmentChunks),
          totalChunks = toint(payload.totalChunks),
          webUrl = tostring(payload.webUrl)
| order by timestamp desc
```

#### 3. Indexing history for a specific item with details
```kql
let TargetParent = '/m365x03100047.sharepoint.com/SalesAndMarketing/1be0da74-2b71-45e0-a9d3-1ffafa7d0ba7/15';
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where message contains "ITEM-COMPLETE"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where tostring(payload.event) == "ITEM-COMPLETE" and tostring(payload.parentId) == TargetParent
| project timestamp,
          runId = tostring(payload.runId),
          collection = tostring(payload.collection),
          status = tostring(payload.status),
          attachmentChunks = toint(payload.attachmentChunks),
          totalChunks = toint(payload.totalChunks),
          webUrl = tostring(payload.webUrl)
| order by timestamp desc
```

#### 4. Recent errors (all error events)
```kql
let Logs = union isfuzzy=true traces, AppTraces;
Logs
| where severityLevel >= 3  // 3=Warning, 4=Error
| where message contains "sharepoint-indexer"
| extend payload = parse_json(extract('\\{.*', 0, message))
| where isnotempty(tostring(payload.event))
| project timestamp,
          severityLevel,
          event = tostring(payload.event),
          runId = tostring(payload.runId),
          collection = tostring(payload.collection),
          itemId = tostring(payload.itemId),
          parentId = tostring(payload.parentId),
          error = tostring(payload.error),
          message
| order by timestamp desc
```

### Blob Storage Logs (Optional)

Blob logging is **enabled by default** but gracefully degrades if unavailable. To disable, set the **app setting** (not environment variable):
```
DISABLE_STORAGE_LOGS = true
```

> **Note**: Azure Functions/Container Apps use **Application Settings**, not shell environment variables. Set this in the Azure Portal under Configuration → Application Settings.

When enabled, logs are written to the blob container specified by the `JOBS_LOG_CONTAINER` app setting (default: `jobs`):

#### Per-Item Logs: `jobs/sharepoint-indexer/files/{sanitized_parent_id}.json`

Each processed item generates a JSON log with:

- **Status**: `success`, `skipped-no-change`, or `error`

- **Freshness details**: `incomingLastMod`, `existingLastMod`, `freshnessReason`

- **Document library metadata**: `documentLibraryFileName`, `documentLibraryUrl` (if applicable)

- **Chunks processed**: Count of chunks uploaded for this item

- **Errors**: Full exception details if the item failed

Example:
```json
{
  "indexerType": "sharepoint-indexer",
  "collection": "contoso.sharepoint.com/sites/engineering/Documents",
  "itemId": "42",
  "parent_id": "contoso_engineering_abc123_42",
  "runId": "20251121T143022Z",
  "status": "success",
  "incomingLastMod": "2025-11-21T14:30:22Z",
  "existingLastMod": "2025-11-20T10:15:00Z",
  "freshnessReason": "newer-by-ms=102382000",
  "chunks": 3
}
```

#### Run Summaries: `jobs/sharepoint-indexer/runs/{runId}.{status}.json`
Each job execution creates stage-specific snapshots:
- **`{runId}.started.json`**: Job initialization (collections count, start time)
- **`{runId}.finishing.json`**: Mid-execution snapshot with partial stats
- **`{runId}.finished.json`**: Final authoritative summary (or `.failed.json`/`.cancelled.json`)
- **`latest.json`**: Pointer to the most recent run (best-effort; may lag on immutable containers)

Example final summary:
```json
{
  "indexerType": "sharepoint-indexer",
  "runId": "20251121T143022Z",
  "runStartedAt": "2025-11-21T14:30:22Z",
  "runFinishedAt": "2025-11-21T14:35:18Z",
  "status": "finished",
  "collections": 3,
  "itemsDiscovered": 84,
  "candidateItems": 12,
  "indexedItems": 12,
  "skippedNoChange": 72,
  "failed": 0,
  "documentLibraryStats": {
    "candidates": 9,
    "skippedNotNewer": 6,
    "skippedExtNotAllowed": 3,
    "uploadedChunks": 18
  }
}
```


## Metrics Reference

| Counter | Meaning | Source |
|---------|---------|--------|
| `items_discovered` | Items enumerated from SharePoint | Run summary + App Insights
| `items_candidates` | Items deemed newer than index | Run summary + App Insights
| `items_indexed` | Body documents uploaded | Run summary + App Insights
| `items_skipped_nochange` | Bodies skipped by freshness | Run summary + App Insights
| `items_failed` | Errors/timeouts | Run summary + App Insights
| `body_docs_uploaded` | Count of body documents uploaded (≤ items_indexed) | Run summary
| `att_candidates` | Document-library files considered | `documentLibraryStats.candidates`
| `att_skipped_not_newer` | Files skipped (index already has newer/equal version) | `documentLibraryStats.skippedNotNewer`
| `att_skipped_ext_not_allowed` | Files ignored due to extension filter | `documentLibraryStats.skippedExtNotAllowed`
| `att_uploaded_chunks` | Total chunks pushed for document libraries | `documentLibraryStats.uploadedChunks`

**Where to find them:**

- **Blob storage**: `jobs/sharepoint-indexer/runs/latest.json` for the most recent run.

- **Application Insights**: Query `traces` (run-level) or `customMetrics` (time-series) for historical analysis.

- **Dashboards**: Combine `items_discovered`, `items_indexed`, and `documentLibraryStats` to visualize workload vs. actual changes each run.


## Operational Tips

- Re-run jobs freely: unchanged content is cheap thanks to freshness checks and chunk-0 comparisons.
- Watch `documentLibraryStats.skippedNotNewer` to confirm zero-based chunking is working (high number = steady state).
- If you see repeated lookup fetch 404s in logs, verify your list doesn’t target additional hidden lists and extend the skip allowlist if necessary.
- For persistent Document Intelligence 503s, capture `apim-request-id` from logs and open an Azure support ticket.
