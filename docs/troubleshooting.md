This page covers common issues, debugging tools, and how to inspect logs in GPT-RAG.

!!! note "Develop adoption, not a release"
    [Adoption status and approval scope](contributing.md#develop-adoption-status)
    supersede the historical “unmerged” and pending-exception labels below.
    Source pins remain implementation evidence; released manifest pins are unchanged.
    Required-check activation and reference-green evidence are not yet confirmed.

!!! warning "Unmerged orchestrator candidate: recovery and compatibility"
    The following guidance is pinned to orchestrator
    [`ea61bc7cd7b2ac21c957bee5db959337fedd8760`](https://github.com/Azure/gpt-rag-orchestrator/commit/ea61bc7cd7b2ac21c957bee5db959337fedd8760),
    not a shipped release:

    - **Retrieval now fails where it previously answered:** required-user
      MAF/multimodal retrieval fails closed on missing/failed OBO, including
      mixed sources. Restore trusted token forwarding, audiences, consent and
      source permissions. Do not strip the authorization header, enable
      anonymous mode to bypass a user-only source, or substitute application
      identity. Eligible service-only requests remain. Scopes do not prove live
      ACLs; test allowed and denied principals. See
      [provider policy](services_orchestrator.md#candidate-retrieval-authorization).
    - **Personalization disappeared:** automatic profile access and extraction
      are completely suspended for unverifiable owner keys, including
      valid-looking keys and cached profiles. No extraction model calls or
      automatic profile storage access occur; records are not deleted or
      migrated. Do not backfill keys or repair the adapter as a bypass.
      Restoration needs a proven trusted owner binding and reviewed privacy
      decision. Ordinary chat/history continues; review custom prompts for
      persistent-profile promises.
    - **Answer completed but history is missing:** ordinary classic writes
      remain best effort. Restore Cosmos access for future writes and inspect
      unconfirmed-persistence diagnostics. SSE completion is not a durable
      receipt; there is no automatic replay after process loss. See
      [history limits](services_orchestrator.md#conversation-history-and-retrieval-controls).
    - **Old API key still works during configuration failure:** H1 retains
      the environment `ORCHESTRATOR_APP_APIKEY` fallback. Rotate/remove both
      configured and environment keys and update callers/deployed revisions;
      restore App Configuration access. No new auth-path opt-in exists.
      Missing/mismatched keys still return 401; Dapr and `DISABLE_AUTH`
      precedence is unchanged. See [H1 recovery](howto_authentication.md#legacy-api-key-recovery-h1).

    Prefer a forward fix or operationally disable affected retrieval routes.
    Rolling back to `25f1986` reintroduces permissive authorization and profile
    extraction paths; it is not a safe security remedy or recovery of lost data.

!!! warning "Unmerged bridge teardown correction"
    [Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110),
    checkpoint [`b8318dc`](https://github.com/Azure/gpt-rag-ui/commit/b8318dccdc3ac67c8e30abc85e5dbe2968af554a),
    invalidates bridge socket associations before the transport disconnect
    callback. Messages and racing admissions through those associations are
    denied even while Engine.IO is still closing the transport.

    If namespace enumeration, socket lookup, or manager cleanup fails, the
    unresolved Socket.IO binding stays inactive and counts against socket
    capacity until successful cleanup reconciles it. Independent namespace
    cleanup continues where possible. Releasing the separate Engine.IO
    reservation does not prove physical transport termination or free an
    unresolved Socket.IO binding. Repeated cleanup failures can therefore
    exhaust available capacity; automatic reclamation is not guaranteed.
    These are candidate behavior notes, not a released or browser/TCP
    termination guarantee.

!!! warning "Unmerged upload, OpenAPI and panel failure corrections"
    The follow-up in [Azure/gpt-rag-ui#110](https://github.com/Azure/gpt-rag-ui/pull/110)
    at [`aef9546`](https://github.com/Azure/gpt-rag-ui/commit/aef9546879333c8615b7adb3917f299a665f4ecc)
    adds uploaded filenames to session bookkeeping only after confirmed batch
    ingestion. A false result or exception preserves previously confirmed names;
    the boolean client contract cannot confirm individual files in a partial
    batch. Both failure outcomes display a failure notice with the question
    reference, not "Files received" or processed-success confirmation.
    **A false result or exception stops the accompanying question before it is
    sent to the chat backend.** Reattach **all files** and resubmit the question;
    retry is not automatic. If the failed upload allocated a new conversation
    ID, the UI restores the prior session ID. The manual retry allocates a
    fresh conversation and reingests all reattached files before sending the
    question, only after confirmed ingestion. For an existing conversation,
    its ID is preserved and ownership is checked again; retry does not bypass
    access denial. This does not guarantee cleanup of partial ingestion.
    If the failure persists, share the displayed question reference with
    application support. Confirmed successful ingestion still updates the
    bookkeeping and allows the question to continue (H6).

    Standalone download failures now use fixed generic text: typed
    `ResourceNotFoundError` returns 404; other failures return 500 even if their
    message contains `BlobNotFound`. Dependency details and file paths are
    omitted from this failure diagnostic. This does not change Copilot access.
    The secure grant route's existing generic 500/no-store catch covers only
    synchronous downloader acquisition, after authorization checks. Conversation
    resolution and late stream iteration are outside that catch; the P2 scope
    clarification adds no runtime handler or transport-termination guarantee.

    OpenAPI generation failure makes `/openapi.json` return HTTP 500, not a
    metadata-only or empty-path schema (H3). The failure is logged and no schema
    is cached. Investigate the generation error in server logs, repair its
    cause, and retry the request; only successful generation is cached.

    If the optional panel owner-index write fails after a managed conversation
    is created, ordinary chat continues and a safe log explicitly says that
    the write was not confirmed, owner-index repair is required, and no
    automatic repair was attempted (H4). Without
    that row the conversation is absent from panel listing, and panel
    read/feedback/delete return opaque 404 responses before accessing managed
    content. Continuing the chat does not retry the creation hook. There is no
    automatic repair, backfill or authorization bypass. Escalate to the
    operator to investigate the failed write and arrange an authorized
    owner-index repair; do not disable ownership checks or assume another
    chat turn restores panel access.
    These are unmerged notes for
    [#110](https://github.com/Azure/gpt-rag-ui/pull/110), not released guarantees
    or a change to the shipped manifest.

!!! warning "Unmerged ingestion configuration and feedback availability"
    Ingestion [`eb42bbb`](https://github.com/Azure/gpt-rag-ingestion/commit/eb42bbb155613ba570f891b67366967387735e32)
    makes configured fallback diagnostics explicit and adds
    `feedback.available` to the legacy `/api/panel/overview`. Failed feedback
    reads return zero placeholders with `available=false`, not a complete
    zero-feedback observation; jobs/files remain available. The separate
    frontend `/panel/overview/metrics` is unchanged. See
    [ingestion configuration and overview recovery](services_ingestion.md#observability)
    for source order, the existing environment opt-in, and recovery steps.
    This is candidate behavior, not a shipped manifest update.


**Showing Response Time Statistics in the Chat UI**

The GPT-RAG UI includes a built-in option to display response time after each agent answer. To enable it, set the `SHOW_STATISTICS` application setting to `true` in your Container App (or App Configuration). Once enabled, each response in the chat will show timing information, helping you identify slow responses and compare performance across different queries or configurations.


**Enabling Debug Logging**

To increase log verbosity for any GPT-RAG component (orchestrator, ingestion, or UI), set the `LOG_LEVEL` environment variable to `DEBUG` in the corresponding Container App. For example, in the Azure Portal go to your Container App → Environment variables → set `LOG_LEVEL` = `DEBUG`. After restarting the container, the application will emit detailed logs including internal function calls, SDK diagnostics, and step-by-step execution traces. Remember to revert to `INFO` or `WARNING` after troubleshooting to avoid excessive log volume and cost.


**Viewing Logs in Application Insights**

All GPT-RAG components send telemetry to Application Insights. Open your Application Insights resource in the Azure Portal and go to **Logs** to run KQL queries.

To find recent errors across all components:

```kql
traces
| where timestamp > ago(1h)
| where severityLevel >= 3
| project timestamp, message, cloud_RoleName, severityLevel
| order by timestamp desc
| take 50
```

To see errors specifically in the orchestrator:

```kql
traces
| where timestamp > ago(24h)
| where cloud_RoleName contains "orchestrator"
| where severityLevel >= 3
| project timestamp, message, operation_Id
| order by timestamp desc
```

To trace a single request end-to-end using its operation ID (you can get this from a previous query or from the UI response headers):

```kql
traces
| where operation_Id == "YOUR_OPERATION_ID"
| order by timestamp asc
| project timestamp, message, severityLevel, cloud_RoleName
```

To check for rate-limit (429) or throttling issues in ingestion:

```kql
traces
| where timestamp > ago(24h)
| where cloud_RoleName contains "ingest"
| where message contains "429" or message contains "throttl" or message contains "rate limit"
| project timestamp, message
| order by timestamp desc
```

To view exceptions with stack traces:

```kql
exceptions
| where timestamp > ago(24h)
| project timestamp, problemId, outerMessage, details, cloud_RoleName
| order by timestamp desc
| take 20
```


**Deploy fails after switching azd environments (stale `APP_CONFIG_ENDPOINT`)**

If `azd deploy <component>` fails right after starting with an Azure CLI error saying the App Configuration resource does not exist or cannot be found, and the message references an `https://<name>.azconfig.io` endpoint that does not match your current environment, the most likely cause is a stale `APP_CONFIG_ENDPOINT` environment variable left over from a previous deployment.

The component deploy scripts (`scripts/deploy.ps1` and `scripts/deploy.sh`) prefer the value of `APP_CONFIG_ENDPOINT` from your shell over the value stored in the active `azd` environment. When the previous App Configuration was deleted or recreated (for example, after tearing down an azd env and provisioning a new one), the stale value silently wins and the deploy targets a resource that no longer exists.

Clear the variable from your shell and let `azd env` provide the correct value:

PowerShell:

```powershell
Remove-Item env:APP_CONFIG_ENDPOINT -ErrorAction SilentlyContinue
azd env get-values | Out-Null  # optional, confirms the active env
azd deploy <component>
```

Bash:

```bash
unset APP_CONFIG_ENDPOINT
azd env get-values >/dev/null  # optional
azd deploy <component>
```

To avoid this in the future:

- Open a fresh terminal when switching between azd environments.
- If you must set `APP_CONFIG_ENDPOINT` manually (for example, on a jumpbox or in CI), confirm it matches `azd env get-value APP_CONFIG_ENDPOINT` before deploying.

The component deploy scripts also print a yellow warning when the shell `APP_CONFIG_ENDPOINT` and the active azd env disagree, starting with GPT-RAG [v2.9.1](https://github.com/Azure/GPT-RAG/releases/tag/v2.9.1) (orchestrator v2.8.3, ingestion v2.4.4, ui v2.3.11). See [#491](https://github.com/Azure/GPT-RAG/issues/491) for context.


**Known Issues and Fixes**

Below is a list of commonly reported issues that have been resolved. If you encounter one of these, make sure you are running the version that includes the fix.

**OOM container restarts during parallel ingestion** — Ingestion containers could run out of memory when processing multiple large files concurrently. Fixed by adding memory guards, temp-file downloads for large PDFs, and lowering default concurrency. See [#438](https://github.com/Azure/gpt-rag/issues/438).

**Re-indexing caused by embedding retry issues** — Transient embedding failures could cause documents to be unnecessarily re-indexed. Fixed in ingestion v2.2.5. See [#437](https://github.com/Azure/gpt-rag/issues/437).

**All documents re-indexed when permissionFilterOption is enabled** — Enabling document-level security caused a full re-index instead of incremental updates. Fixed in ingestion v2.2.5. See [#436](https://github.com/Azure/gpt-rag/issues/436).
