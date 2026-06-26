> 📌 [Check out what's coming next](https://github.com/orgs/Azure/projects/536/views/6)  (Azure org only)

### June 2026

#### Release v3.0.2: Foundry IQ default
*Feature preview · Azure/GPT-RAG [#526](https://github.com/Azure/GPT-RAG/issues/526)*

Starting with GPT-RAG v3.0.2 and AI Landing Zone v2.1.2, new deployments use
Foundry IQ by default through a native Azure Blob Knowledge Source. Azure AI
Search remains fully supported for existing deployments, rollback, and custom
GPT-RAG ingestion pipelines.

- New deployments use `RETRIEVAL_BACKEND=foundry_iq` with
  `FOUNDRY_IQ_PATTERN=azureBlob`.
- Existing deployments can stay on `RETRIEVAL_BACKEND=ai_search` until an
  operator migrates them.
- The default Blob path lets Foundry IQ process files directly from the
  `documents` container. GPT-RAG ingestion is not used in that path.
- The custom ingestion path registers the existing GPT-RAG Azure AI Search index
  as a Foundry IQ `searchIndex` knowledge source, preserving GPT-RAG ingestion,
  runtime uploads, and security-field filtering through `filterAddOn`.
- Native Foundry IQ permission enforcement uses
  `x-ms-query-source-authorization`; custom ingestion path GPT-RAG security
  fields use `filterAddOn`. These are separate mechanisms.
- `FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN` controls the Azure AI Search
  `knowledgeRetrieval` plan. Use `standard` only after billing approval.

See [Retrieval backend selection](howto_retrieval_backend.md) for setup,
security, rollback, and known limitations.

---

#### Release 2.9.17: Conversations dialog fix
*Hotfix · orchestrator [v2.8.13](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.13)*

Hotfix on top of v2.9.16. UI, ingestion, and AI Landing Zone pins are unchanged.

- After the v2.9.16 fix that reconstructs Conversations detail from `questions[]`, the dialog still showed `user (empty)` / `assistant (empty)` for every turn. The backend was emitting each message body under a `text` field, but the dialog component only read `content`, so the body never reached the screen.
- The dialog now reads `content` and falls back to `text`, so reconstructed user prompts and assistant answers render without any backend redeploy gymnastics.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.17)

---

#### Release 2.9.16: Dashboard fixes
*Patch · orchestrator [v2.8.12](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.12)*

Five operator-reported fixes against the dashboard's **Overview** and **Conversations** tabs. Other components unchanged.

- **Custom range no longer accepts future dates.** Both From/To inputs cap at today (UTC), saved future dates are clamped on load, and an inline error mirrors the existing 365-day cap message.
- **End-of-day semantics on `to=YYYY-MM-DD`.** A bare date on `GET /api/dashboard/overview` is now treated as end of day UTC, so `From=2026-06-15 To=2026-06-19` includes everything that happened on the 19th.
- **Readable Overview tooltips.** Opaque `bg-card` background with border and shadow, sitting cleanly above the cards in light and dark mode (the v2.8.11 sentence-case fix is preserved).
- **Conversations detail reconstructed from `questions[]`.** Assistant replies live on the Azure AI Foundry agent thread, so the dialog now reconstructs user turns from Cosmos and shows a friendly note pointing to the Foundry thread for the assistant side, instead of empty cards.
- **Clearer Configuration buttons.** *Reload settings cache* is renamed to *Refresh from App Configuration*, and both footer buttons now have sentence-case info tooltips that explain what each one actually does.

Fixes [`gpt-rag-orchestrator#246`](https://github.com/Azure/gpt-rag-orchestrator/pull/246).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.16)

---

#### Release 2.9.15: Schedules tab
*Patch · ingestion [v2.4.13](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.13)*

Two operator-reported UX fixes on the ingestion dashboard. Orchestrator, UI, and AI Landing Zone pins are unchanged.

- **New Schedules tab.** The seven-button *Run now* strip and the *Queue and schedule* table were crowding the Jobs tab. They now live on a dedicated **Schedules** tab between *Jobs* and *Files*, so the order is **Jobs | Schedules | Files | Configuration**. Jobs goes back to a clean recent-runs view. All triggering and scheduling behavior is preserved, including the 1-second burst polling after each *Run now* click, the cron column, and the *Last run* summary per job type. Clicking *Run now* on Schedules keeps you on Schedules so you can watch the queue update.
- **Toast auto-dismiss.** The green "Started <job_type>." toast no longer stays on screen forever. It auto-dismisses after 4 seconds, each toast has its own independent timer (a fresh trigger does not extend an older toast), and there is a manual close button. The warning toast for "already running" and the error toast follow the same behavior.

Fixes [`gpt-rag-ingestion#254`](https://github.com/Azure/gpt-rag-ingestion/pull/254).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.15)

---

#### Release 2.9.14: Overview polish
*Patch · orchestrator [v2.8.11](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.11)*

P2 follow-up against the Overview tab dashboard shipped in v2.8.10. Three operator-reported fixes. Other components unchanged.

- **Tooltips no longer shout.** Info tooltips on each metric card were rendering in ALL CAPS because the card label uses `uppercase` styling and `text-transform` is inherited. Tooltip popovers now reset to sentence case regardless of the surrounding label.
- **Active users counts anonymous traffic correctly.** The card was showing one user per anonymous conversation (for example, 57 users for 57 anonymous conversations) because anonymous traffic uses a per-conversation Cosmos partition key written verbatim into `principal_id`. The aggregation now collapses every `principal_id` starting with `anonymous-` (or equal to `anonymous`) into a single bucket. Authenticated users are still counted by their Entra object id. Tooltip wording updated to match.
- **Custom range chip actually works.** The From/To inputs were rendered but hidden inside the chip row's flex layout, and the chart momentarily went to zero on every range change. The picker now renders the date inputs on a dedicated full-width row directly under the chips with visible `From` / `To` labels and a short hint about the 365-day cap, and refreshes after the first successful load keep the chart and KPIs mounted with a small `Refreshing…` indicator.

Fixes [`gpt-rag-orchestrator#241`](https://github.com/Azure/gpt-rag-orchestrator/issues/241).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.14)

---

#### Release 2.9.13: Date columns and time-range picker
*Patch · orchestrator [v2.8.10](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.10)*

P1 patch against the operator dashboard shipped in v2.8.9. Other components unchanged.

- **Conversations columns render.** Created and Last updated columns were showing `-` for every row because the API serialized those fields under the Cosmos names (`_ts`, `lastUpdated`) instead of the canonical names the frontend reads (`created_at`, `last_updated`). Switching the affected Pydantic models from `alias=` to `validation_alias=` makes the response JSON match the frontend contract while still accepting the Cosmos names on input.
- **`REASONING_EFFORT` round-trips its canonical values.** Lowercase `minimal/low/medium/high` end-to-end, with a regression test pinning the contract.
- **Overview time-range picker.** Today / Last 7 days / Last 30 days (default) / Last 90 days / Custom range. The active range drives the time-series chart, the Engagement panel, the Active users card subtitle, and a new in-window total. The four KPI cards keep their fixed semantic windows. Selection persists in `localStorage` under `gpt-rag-orchestrator.overview.range`.
- **`GET /api/dashboard/overview` accepts `from` and `to`.** Validates `from <= to`, caps the range at 365 days, returns `400` on invalid input, and keys the in-process cache on `(from, to)`.
- **Info tooltips on every Overview metric.** Same primitive already used on the Configuration tab, so operators can confirm what each number measures without leaving the page.

Fixes [`gpt-rag-orchestrator#241`](https://github.com/Azure/gpt-rag-orchestrator/issues/241).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.13)

---

#### Release 2.9.12: Configuration polish
*Patch · ingestion [v2.4.12](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.12)*

Operator-reported follow-up to v2.4.11. Other components unchanged.

Every text/number input on the ingestion dashboard's **Configuration** tab used its own example or default as the HTML placeholder, styled close enough to a real entered value that operators could not tell empty fields from configured ones (Scheduling showed `0 * * * *`, `0 2 * * *`, `*/15 * * * *` inside the inputs). The same examples were also repeated as helper text below, so the placeholder added nothing but confusion.

Placeholders now describe what an empty field means at runtime:

- `Not configured` for the 5 cron inputs whose tooltip already says empty disables the schedule, and for all 8 numeric inputs. The example moves into a new `Example: <value>.` helper line so operators still see a sensible starting point.
- `Default: <value>` for the two cron inputs where the backend `SettingSpec.default` actually applies when empty (`CRON_RUN_BLOB_INDEX` → `0 * * * *`, `CRON_RUN_BLOB_PURGE` → `10 * * * *`).

15 inputs updated in total. No backend, schema, or styling changes. [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.12)

---

#### Release 2.9.11: Queue panel polish
*Patch · ingestion [v2.4.11](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.11)*

Five operator-reported fixes against the *Queue and schedule* panel added in v2.9.10. Other components unchanged.

- **Honest *Run now* toasts.** Says `Started <job_type>.` instead of `Queued <job_type>.` (APScheduler fires immediately, so "Started" matches reality) and `<job_type> is already running.` as a warning toast on `409 Conflict`.
- **Cron column is no longer empty.** `GET /api/jobs/queue` now reads `cron` from `scheduler.get_job(job_id).trigger`, the single source of truth, instead of an app config key whose pattern did not match what the scheduler writes.
- **Faster feedback after *Run now*.** The panel bursts to a 1-second poll for 15 seconds and then reverts to 10 seconds, so the new in-flight state shows up within seconds instead of waiting a full normal-poll cycle.
- **Collapsible panel, defaults collapsed.** Chevron toggle, no more ~250 px push of the runs table on every page load. The expand/collapse preference persists in `localStorage` under `gpt-rag-ingestion.queuePanel.expanded`. Collapsed header still shows `N jobs scheduled, M in flight`.
- **New Last run column.** Shows the most recent finished or failed run per job type as `<relative time> · <status> · <indexed> indexed` (for example `3s ago · finished · 0 indexed`), sourced from a new `last_run` field on each `/api/jobs/queue` item. Derived from the same cached runs store `/api/jobs/runs` reads, so the frontend still issues one request per poll.

Polishes [`gpt-rag-ingestion#247`](https://github.com/Azure/gpt-rag-ingestion/issues/247).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.11)

---

#### Release 2.9.10: Queued jobs and ETA
*Feature · ingestion [v2.4.10](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.10)*

Operators who use the *Run now* button (added in v2.9.6 / ingestion v2.4.7) now get **queue and next-run visibility** in the ingestion operator dashboard. Other components unchanged.

Before v2.4.10, clicking *Run now* showed a toast and disappeared. There was no way to see what was in flight or when the next cron would fire without tailing container logs.

A new compact *Queue and schedule* panel sits above the Jobs table, polls every 10 seconds, and shows per job type:

- Any in-flight run (run id + elapsed).
- The next scheduled run as a relative ETA (`in 12 min`), with the absolute ISO timestamp in a tooltip.
- The current cron string.

The *Run now* button is rendered disabled with a `Job already running` tooltip when the matching job is in flight, so operators learn before they click and get a `409 Conflict`. The panel reads from a new `GET /api/jobs/queue` endpoint (network-only auth, same posture as `GET /api/jobs` and `GET /api/config`). No persistent queue (Service Bus, Storage Queue, etc.) was added.

Adds [`gpt-rag-ingestion#247`](https://github.com/Azure/gpt-rag-ingestion/issues/247).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.10)

---

#### Release 2.9.9: Configuration fix follow-up
*Patch · ingestion [v2.4.9](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.9)*

v2.9.8 fixed the missing top-level `settings` array, but operators upgrading reported the **Configuration tab in the ingestion dashboard was still blank**.

Second contract gap: each section was emitted as `{id, label, settings}` while the typed frontend `ConfigSection` reads `{id, title, keys}`. `section.keys.map(...)` crashed with `TypeError: undefined is not iterable` and the tab rendered nothing.

v2.4.9 now also emits `title` (mirror of `label`) and `keys` (ordered list of setting keys, matching the nested `settings` order) on every section. The legacy `label` and nested `settings` fields stay, so no other callers are affected.

Fixes the follow-up to [`gpt-rag-ingestion#242`](https://github.com/Azure/gpt-rag-ingestion/issues/242).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.9)

---

#### Release 2.9.8: Configuration tab fix
*Patch · ingestion [v2.4.8](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.8)*

Operators who turned on `ENABLE_DASHBOARD=true` on the ingestion app saw the **Configuration tab render blank** in v2.9.7 (ingestion v2.4.7), because the ingestion `GET /api/config` endpoint did not return the flat `settings` array and `authEnabled` flag the typed frontend contract reads. The tab crashed with `TypeError: undefined is not iterable` and showed nothing.

The endpoint now returns both the grouped `sections` view and a flat `settings` list (built from the same per-setting reader so the two views stay in lock-step), plus `authEnabled`. The Configuration tab loads as documented in v2.9.6. The allow-list, denylist, section grouping, and `Admin` app role gating are all unchanged.

Fixes [`gpt-rag-ingestion#242`](https://github.com/Azure/gpt-rag-ingestion/issues/242).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.8)

---

#### Release 2.9.7: Preflight quota fix
*Patch · AI Landing Zone [v2.0.20](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.20)*

No component code changed. Operators provisioning a fresh environment with `azd up` now get a clear `MODEL_QUOTA_INSUFFICIENT` error in seconds when regional OpenAI model quota is insufficient, instead of letting ARM run for ~15 minutes and then failing partway through the deploy. [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.7)

---

#### Release 2.9.6: Operator dashboards
*Feature · orchestrator [v2.8.9](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.9) · ingestion [v2.4.7](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.7) · UI v2.3.13 · infra v2.0.19*

The latest June drop adds an opt-in **operator dashboard at `/dashboard`** on both the orchestrator and ingestion apps, with three tabs: Overview, Conversations, and Configuration.

- **Off by default, safe upgrade.** Existing deployments are byte-for-byte unchanged. Set `ENABLE_DASHBOARD=true` in App Configuration for the orchestrator and/or ingestion app to turn it on. With Entra auth on, dashboard pages also require the `Admin` app role.
- **Overview tab.** Today / 7-day / 30-day conversation counts, a conversations-over-time chart, average user turns per conversation, and active user count. Reads come from the existing Cosmos conversation container, no new storage.
- **Conversations tab.** Paginated, newest-first list with a detail dialog that renders the full message history.
- **Configuration tab.** Admins can view and edit a curated, sectioned set of runtime settings (agent strategy, reasoning effort, temperature and top_p, max completion tokens, retrieval and search toggles, ingestion chunking, cron schedules, etc.) without leaving the app. Each field has the right control and an accessible info tooltip reachable by keyboard. Writes are protected by an explicit allow-list plus a denylist that rejects any key whose name matches sensitive suffixes (`_APIKEY`, `_SECRET`, `_PASSWORD`, `_CONNECTION_STRING`, `_TOKEN`, ...). Buttons are honest about what they do: *Reload settings cache* refreshes the in-process App Configuration cache, and *Apply changes* is a soft restart that refreshes the cache and returns a clear status. Nothing is labeled "Restart" if it does not actually restart the container.
- **Ingestion bonus: Run jobs on demand.** Admins can trigger any of the scheduled ingestion jobs (blob, sharepoint, sharepoint purge, ...) from the Jobs tab with a single click. Changing a `CRON_RUN_*` schedule and applying reschedules the affected job in place, no restart needed.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.6)

---

#### Release 2.9.1: Authenticated uploads
*June release train · four themes*

- **Authenticated per-conversation uploads end-to-end.** The uploader identity is preserved during ingestion, the active conversation id flows through retrieval, and uploaded chunks are indexed with ACL metadata so `single_agent_rag` can return them inside the same conversation.
- **Foundry Agent Service v2 stabilization.** The orchestrator moves to the create-once/reuse model, the landing zone provisions the Cosmos DB data-plane RBAC that declarative and versioned Foundry agents require, and Dapr is explicitly enabled on the orchestrator, frontend, and ingestion Container Apps after the landing zone switched Dapr to opt-in.
- **Sweden Central unblocked.** Late-June fixes scope the Foundry Cosmos data-plane role assignment at the database level and turn the Cosmos analytical storage preflight into a regional warning instead of a hard failure.
- **Custom metadata on RAG search results.** Search results expose a new `custom_metadata` field so retrieval can surface arbitrary blob metadata to the orchestrator.
- **Deploy scripts catch App Configuration drift.** The deploy scripts now warn when `APP_CONFIG_ENDPOINT` drifts from the active azd environment, before the deployment touches anything.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.9.1)

---

### May 2026

#### Release 2.7.14: Landing zone hardening
*Patch · AI Landing Zone v2.0.12*

The late-May patch train rolls the AI Landing Zone forward, including fixes for network-isolated deployments, firewall rule generation, Container Apps image pulls, and bounded Windows jumpbox bootstrap execution. It also completes the ingestion Managed Identity fix so Azure Container Apps can acquire user-assigned identity tokens reliably and avoid `/ingest-documents` returning HTTP 200 with `indexedChunks: 0`. [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.7.14)

---

#### Release 2.7.6: Long conversations
*Patch · orchestrator v2.6.9*

- The orchestrator bounds persisted conversation documents before saving to Cosmos DB, keeping recent messages and question metadata while preventing very long chats from growing indefinitely.
- The default local MAF path classifies greetings, retrieval-needed questions, and no-retrieval follow-ups, so transformations of the previous answer can skip unnecessary Azure AI Search calls.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.7.6)

---

#### Release 2.7.5: Existing-platform deployment

- **Existing-platform parameters from the root `main.parameters.json`.** Operators can integrate with shared Private DNS Zones, observability, hub networking, existing jumpbox/Bastion/NAT resources, Private Endpoint placement, ACR Task agent pools, speech resources, and policy-managed DNS without editing the infra submodule.
- **NL2SQL moved to Microsoft Agent Framework.** Direct model calls and local NL2SQL tool execution, removing Semantic Kernel Agent Service agent creation from that path.
- **Chat UI persists conversation renames** by calling the orchestrator conversation update API.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.7.5)

---

#### Release 2.7.0: Landing Zone v2.0
*Major baseline · AI Landing Zone v1.0.7 → v2.0.2*

Default behavior is unchanged for existing operators. All new capabilities are opt-in via `azd env set`. No GPT-RAG component bumps in this release.

Highlights v2 brings to GPT-RAG operators:

- **IP allow-listing** (`allowedIpRanges`): uniform CIDR allow-list applied across Storage, Key Vault, App Configuration, Container Registry, Cosmos DB, AI Search, and the AI Foundry storage account.
- **BYO Private DNS zones / observability / hub-and-spoke** parameters for integration with an existing Azure Landing Zone hub.
- **Pre-flight validation hooks** that catch parameter contradictions before reaching ARM and fail fast when the selected GPT-RAG region lacks required VM SKU support, provider/location support, or Azure OpenAI model quota. The preflight is explicit about limits Azure does not expose reliably before creation, such as transient Cosmos DB high-demand capacity.
- **Cosmos `enableAnalyticalStorage` fix.** The implicit `true` default that caused intermittent provisioning failures is gone, replaced by an explicit opt-in via `enableCosmosAnalyticalStorage`.
- **Network-isolated deployment procedure clarified.** Workstations run only `azd provision`; `postProvision` and `azd deploy` run from the jumpbox/VNet with `RUN_FROM_JUMPBOX=true`, using ACR remote builds so Docker is not required on the VM.

See the [v2-migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.0/docs/v2-migration.md) and the [parameterization reference](https://azure.github.io/AI-Landing-Zones/bicep/parameterization) for the full v2 surface. [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.7.0)

---

#### Release 2.6.7: Per-conversation uploads
*Feature · ingestion v2.3.4 · orchestrator v2.6.3 · UI v2.3.2*

Users can now upload files directly through the chat interface. Documents are persisted to a per-conversation storage container, chunked and indexed into Azure AI Search with a `conversationId` field, and retrieved by the orchestrator with a filter that mixes conversation-private content with shared/global content. [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.6.7)

---

### April 2026

#### Release 2.6.4: Ingestion enhancements

- **Ingestion Admin Dashboard.** A new React-based admin dashboard at `/dashboard` for monitoring and managing ingestion jobs. Paginated job and file tables, search, filters, and the ability to unblock stuck files. Processing timings shown as stacked color bars per phase (download, analysis, chunking, index upload), with per-file cost estimates broken down by service.
- **Content Understanding integration.** Document analysis now uses Azure AI Foundry Content Understanding (`prebuilt-layout`) by default instead of Document Intelligence, resulting in approximately 69% cost reduction per page.
- **Reliability and large file handling.** Files that fail during ingestion are tracked per attempt. After the maximum retries (default 3), the file is automatically blocked, preventing repeated reprocessing and unnecessary document analysis costs. Stale jobs stuck after a container crash are auto-recovered after 2 hours. Large PDFs exceeding the analysis page limit (default 300 pages) are split automatically, and a memory guard skips oversized files to prevent OOM crashes.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.6.4)

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/BRwGaBAIICg?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="Ingestion Admin Dashboard" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

---

#### Release 2.6.1: Conversation history

- **Conversation history.** List, resume, and delete past conversations directly from a sidebar in the chat UI.
- **Multimodal improvements.** Images now appear inline between response steps instead of grouped at the bottom, with improved validation accuracy.

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.6.1)

---

### March 2026

#### Release 2.5.3: Orchestration overhaul

**New orchestration strategies.** The orchestrator now supports:

- **Agent Service v2**: managed orchestration via Azure AI Foundry Agent Service v2.
- **Microsoft Agent Framework**: lightweight orchestration with direct Foundry access, no Agent Service.
- **Agent Service + Agent Framework**: combines Agent Service v2 with the Microsoft Agent Framework for advanced scenarios.
- **Multimodal**: image understanding support for multimodality scenarios.

**Infrastructure as external Bicep module.** Bicep infrastructure extracted to the external [`bicep-ptn-aiml-landing-zone`](https://github.com/Azure/bicep-ptn-aiml-landing-zone) module for better maintainability and reuse. Deploy scripts hardened. [`#424`](https://github.com/Azure/GPT-RAG/pull/424)

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.5.3)

---

### January 2026

#### Release 2.4.0: Document-level security

Microsoft Entra ID authentication in the frontend, with orchestrator-side user identity validation, plus RBAC-based access control and document-level authorization in retrieval workflows. User identity context is propagated through ingestion and orchestration so [Azure AI Search can enforce fine-grained ACL/RBAC](https://learn.microsoft.com/en-us/azure/search/search-query-access-control-rbac-enforcement) permissions end-to-end. [`#417`](https://github.com/Azure/GPT-RAG/pull/417)

How to configure: [Authentication and Document-Level Security](howto_authentication.md). [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.4.0)

---

### December 2025

#### Release 2.3.0: SharePoint Lists

- **Azure Direct Models (Microsoft Foundry).** Use Microsoft Foundry "Direct from Azure" models (Mistral, DeepSeek, Grok, Llama, etc.) through the Foundry inference APIs with Entra ID authentication. [`#296`](https://github.com/Azure/GPT-RAG/issues/296). How to configure: [Azure Direct Models](howto_azure_direct.md).
- **SharePoint Lists.** The SharePoint connector now covers both SharePoint Online document libraries (PDFs, Office docs) and generic lists (structured fields), so your Azure AI Search index stays in sync with list items and documents. [`#369`](https://github.com/Azure/GPT-RAG/issues/369). How to configure: [SharePoint Data Source](ingestion_sharepoint_source.md) and [SharePoint Connector Setup Guide](howto_sharepoint_connector.md).

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.3.0)

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/P87o8UwiTHw?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="Azure Direct Models" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

---

### October 2025

#### Release 2.2.0: Agentic retrieval

- **Bring Your Own VNet.** Deploy GPT-RAG within your existing virtual network, keeping full control over network boundaries, DNS, and routing policies. [`#370`](https://github.com/Azure/GPT-RAG/issues/370)
- **Agentic retrieval.** Intelligent, agent-driven retrieval orchestration that dynamically selects and combines information sources for more grounded and context-aware responses. [`#359`](https://github.com/Azure/GPT-RAG/issues/359)

[Release notes](https://github.com/Azure/GPT-RAG/tree/v2.2.1)

---

### September 2025

#### Release 2.1.0: User feedback loop

A mechanism for end-users to give thumbs-up or thumbs-down feedback on assistant responses, storing these signals alongside conversation history to continuously improve response quality.

How to configure: [User Feedback Configuration](howto_userfeedback.md). [Release notes](https://github.com/Azure/GPT-RAG/tree/v2.1.2)

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/t2EkzJ9P8HA?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="User Feedback" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>
