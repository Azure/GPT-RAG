> 📌 [Check out what's coming next](https://github.com/orgs/Azure/projects/536/views/6)  (Azure org only)

### June 2026
**[Release 2.9.14](https://github.com/Azure/GPT-RAG/tree/v2.9.14) - Overview tab tooltip casing, anonymous user count, and custom range editor**

Patch release that bumps the orchestrator pin from `v2.8.10` to [`v2.8.11`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.11). No other component changed; UI, ingestion, and AI Landing Zone pins are identical to v2.9.13. P2 follow-up against the Overview tab dashboard shipped in v2.8.10. Three operator-reported fixes: (1) the info tooltips on each metric card rendered in ALL CAPS because the card label uses `uppercase` styling and `text-transform` is inherited by descendants, so the tooltip body picked it up; tooltip popovers now reset to sentence case regardless of the surrounding label. (2) the **Active users** card showed one user per anonymous conversation (for example, 57 users for 57 anonymous conversations) because anonymous traffic uses a per-conversation Cosmos partition key (`anonymous-<conversation_id>`) and that value was written verbatim into `principal_id`; the Overview aggregation now collapses every `principal_id` starting with `anonymous-` (or equal to `anonymous`) into a single bucket before counting, and authenticated users continue to be counted by their Entra object id. The Active users tooltip wording is updated to match. (3) clicking the **Custom range** chip appeared to do nothing — the From/To date inputs were rendered but hidden in the chip row's flex layout, and the chart momentarily went to zero because every range change unmounted the chart in favor of a full-page spinner. The picker now renders the date inputs on a dedicated full-width row directly under the chips with visible `From` / `To` labels and a short hint about the 365-day cap, and refreshes after the first successful load keep the chart and KPIs mounted with a small `Refreshing...` indicator. Fixes [`Azure/gpt-rag-orchestrator#241`](https://github.com/Azure/gpt-rag-orchestrator/issues/241).
**[Release 2.9.13](https://github.com/Azure/GPT-RAG/tree/v2.9.13) - Dashboard date columns, REASONING_EFFORT, Overview time-range picker and tooltips**

Patch release that bumps the orchestrator pin from `v2.8.9` to [`v2.8.10`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.10). No other component changed; UI, ingestion, and AI Landing Zone pins are identical to v2.9.12. P1 patch against the operator dashboard shipped in v2.8.9. The **Conversations tab** Created and Last updated columns rendered `-` for every row because the API serialized those fields under the Cosmos names (`_ts`, `lastUpdated`) instead of the canonical names the frontend reads (`created_at`, `last_updated`); switching the affected Pydantic models from `alias=` to `validation_alias=` makes the response JSON match the frontend contract while still accepting the Cosmos names on input. On the **Configuration tab**, the `REASONING_EFFORT` field now round-trips its canonical lowercase values (`minimal/low/medium/high`) end-to-end and a regression test pins the contract. The **Overview tab** gains a time-range picker (Today / Last 7 days / Last 30 days [default] / Last 90 days / Custom range), and the active range drives the time-series chart, the Engagement panel, the Active users card subtitle, and a new in-window total. The four KPI cards keep their fixed semantic windows. Selection persists in `localStorage` under `gpt-rag-orchestrator.overview.range`. `/api/dashboard/overview` accepts `from` and `to` ISO query params, validates `from <= to`, caps the range at 365 days, returns `400` on invalid input, and keys the in-process cache on `(from, to)`. Finally, every Overview metric title now has an accessible info tooltip (same primitive already used on the Configuration tab) so operators can confirm what each number measures without leaving the page. Fixes [`Azure/gpt-rag-orchestrator#241`](https://github.com/Azure/gpt-rag-orchestrator/issues/241).

**[Release 2.9.12](https://github.com/Azure/GPT-RAG/tree/v2.9.12) - Configuration tab placeholder polish**

Patch release that bumps the ingestion pin from `v2.4.11` to [`v2.4.12`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.12). No other component changed; orchestrator, UI, and AI Landing Zone pins are identical to v2.9.11. Operator-reported follow-up to v2.4.11: every text/number input on the ingestion dashboard's **Configuration** tab used its own example or default as the HTML placeholder, styled close enough to a real entered value that operators could not tell empty fields apart from configured ones (for example, the Scheduling section showed `0 * * * *`, `0 2 * * *`, `*/15 * * * *` inside the inputs). The same examples were also repeated as helper text below the input, so the placeholder added nothing but confusion. Placeholders now describe what an empty field means at runtime: `Not configured` for the 5 cron inputs whose tooltip already says empty disables the schedule and for all 8 numeric inputs (the example moves into a new `Example: <value>.` helper line so operators still see a sensible starting point), and `Default: <value>` for the two cron inputs where the backend `SettingSpec.default` actually applies when empty (`CRON_RUN_BLOB_INDEX` → `0 * * * *`, `CRON_RUN_BLOB_PURGE` → `10 * * * *`). 15 inputs updated in total. No backend, schema, or styling changes.

**[Release 2.9.11](https://github.com/Azure/GPT-RAG/tree/v2.9.11) - Queue panel polish: collapsible, Last run column, correct toast and cron**

Patch release that bumps the ingestion pin from `v2.4.10` to [`v2.4.11`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.11). No other component changed; orchestrator, UI, and AI Landing Zone pins are identical to v2.9.10. This release polishes the *Queue and schedule* panel added in v2.9.10. Five operator-reported fixes are bundled into one container update. The *Run now* toast now says `Started <job_type>.` instead of `Queued <job_type>.` (APScheduler fires immediately, not after a delay, so "Started" matches what operators actually observe) and says `<job_type> is already running.` as a warning toast on `409 Conflict`. The *Cron* column on `GET /api/jobs/queue` is no longer empty: the endpoint now reads `cron` from `scheduler.get_job(job_id).trigger` (single source of truth, matches what APScheduler is actually firing) instead of an app config key whose pattern did not match what the scheduler writes. After every *Run now* click the panel bursts to a 1-second poll for 15 seconds and then reverts to 10 seconds, so the panel reflects the new in-flight state within seconds instead of waiting up to a full normal-poll cycle. The panel is now **collapsible** with a chevron toggle and **defaults to collapsed** so it stops pushing the runs table down ~250 px on every page load; the operator's expand/collapse preference is persisted in `localStorage` under `gpt-rag-ingestion.queuePanel.expanded`, and when collapsed the header still shows a compact summary line (`N jobs scheduled, M in flight`). Finally, a new **Last run** column shows the most recent finished or failed run per job type as `<relative time> · <status> · <indexed> indexed` (for example `3s ago · finished · 0 indexed`), sourced from a new `last_run` field on each `/api/jobs/queue` item; the field is derived from the same cached runs store `/api/jobs/runs` reads, so the frontend still issues one request per poll. Polishes [`Azure/gpt-rag-ingestion#247`](https://github.com/Azure/gpt-rag-ingestion/issues/247).

**[Release 2.9.10](https://github.com/Azure/GPT-RAG/tree/v2.9.10) - Operator dashboard: queued jobs and next-run ETA per job**

Feature release that bumps the ingestion pin from `v2.4.9` to [`v2.4.10`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.10). No other component changed; orchestrator, UI, and AI Landing Zone pins are identical to v2.9.9. Operators who use the *Run now* button (added in v2.9.6 / ingestion v2.4.7) now get **queue and next-run visibility** in the ingestion operator dashboard. Before v2.4.10, clicking *Run now* showed a toast and disappeared — there was no way to see what was in flight or when the next cron would fire without tailing container logs. v2.4.10 adds a compact *Queue and schedule* panel above the Jobs table that polls every 10 seconds and shows, per job type: any in-flight run (run id + elapsed), the next scheduled run as a relative ETA (`in 12 min`) with the absolute ISO timestamp in a tooltip, and the current cron string. The *Run now* button is also rendered disabled with a `Job already running` tooltip when the matching job is in flight, so operators learn before they click and get a `409 Conflict`. The panel reads from a new `GET /api/jobs/queue` endpoint (network-only auth, same posture as `GET /api/jobs` and `GET /api/config`); no persistent queue (Service Bus, Storage Queue, etc.) was added. Adds [`Azure/gpt-rag-ingestion#247`](https://github.com/Azure/gpt-rag-ingestion/issues/247).

**[Release 2.9.9](https://github.com/Azure/GPT-RAG/tree/v2.9.9) - Configuration tab fix follow-up**

Patch release that bumps the ingestion pin from `v2.4.8` to [`v2.4.9`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.9). No other component changed; orchestrator, UI, and AI Landing Zone pins are identical to v2.9.8. v2.9.8 fixed the missing top-level `settings` array, but operators upgrading to v2.9.8 reported the **Configuration tab in the ingestion dashboard was still blank**. The root cause was a second contract gap: each section was emitted as `{id, label, settings}` while the typed frontend `ConfigSection` reads `{id, title, keys}`, so `section.keys.map(...)` crashed with `TypeError: undefined is not iterable` and the tab rendered nothing. v2.4.9 now also emits `title` (mirror of `label`) and `keys` (ordered list of setting keys, matching the nested `settings` order) on every section. The legacy `label` and nested `settings` fields stay, so no other callers are affected. Fixes the follow-up to [`Azure/gpt-rag-ingestion#242`](https://github.com/Azure/gpt-rag-ingestion/issues/242).

**[Release 2.9.8](https://github.com/Azure/GPT-RAG/tree/v2.9.8) - Configuration tab fix in the ingestion dashboard**

Patch release that bumps the ingestion pin from `v2.4.7` to [`v2.4.8`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.8). No other component changed; orchestrator, UI, and AI Landing Zone pins are identical to v2.9.7. Operators who turned on `ENABLE_DASHBOARD=true` on the ingestion app saw the **Configuration tab render blank** in v2.9.7 (ingestion v2.4.7) because the ingestion `GET /api/config` endpoint did not return the flat `settings` array and `authEnabled` flag the typed frontend contract reads — the tab crashed with `TypeError: undefined is not iterable` and showed nothing. The endpoint now returns both the grouped `sections` view and a flat `settings` list (built from the same per-setting reader so the two views stay in lock-step), plus `authEnabled`. The Configuration tab loads as documented in v2.9.6. The allow-list, denylist, section grouping, and `Admin` app role gating are all unchanged. Fixes [`Azure/gpt-rag-ingestion#242`](https://github.com/Azure/gpt-rag-ingestion/issues/242).

**[Release 2.9.7](https://github.com/Azure/GPT-RAG/tree/v2.9.7) - AI Landing Zone preflight quota fix**

Patch release that bumps the AI Landing Zone pin from `v2.0.19` to [`v2.0.20`](https://github.com/Azure/bicep-ptn-aiml-landing-zone/releases/tag/v2.0.20). No component code changed; orchestrator, ingestion, and UI pins are identical to v2.9.6. Operators provisioning a fresh environment with `azd up` now get a clear `MODEL_QUOTA_INSUFFICIENT` error in seconds when regional OpenAI model quota is insufficient, instead of letting ARM run for ~15 minutes and then failing partway through the deploy.

**[Release 2.9.6](https://github.com/Azure/GPT-RAG/tree/v2.9.6) - Built-in operator dashboards (Overview, Conversations, Configuration)**

The latest June drop adds an opt-in **operator dashboard at `/dashboard`** on both the orchestrator and ingestion apps, with three tabs: Overview, Conversations, and Configuration.

- **Off by default, safe upgrade.** Existing deployments are byte-for-byte unchanged. To turn it on, set `ENABLE_DASHBOARD=true` in App Configuration for the orchestrator and/or the ingestion app. With Entra auth on, dashboard pages also require the `Admin` app role.
- **Overview tab.** Today / 7-day / 30-day conversation counts, a conversations-over-time chart, average user turns per conversation, and active user count. Reads come from the existing Cosmos conversation container — no new storage.
- **Conversations tab.** Paginated, newest-first list with a detail dialog that renders the full message history.
- **Configuration tab.** Admins can view and edit a curated, sectioned set of runtime settings (agent strategy, reasoning effort, temperature and top_p, max completion tokens, retrieval and search toggles, ingestion chunking, cron schedules, etc.) without leaving the app. Each field has the right control and an accessible info tooltip reachable by keyboard. Writes are protected by an explicit allow-list plus a denylist that rejects any key whose name matches sensitive suffixes (`_APIKEY`, `_SECRET`, `_PASSWORD`, `_CONNECTION_STRING`, `_TOKEN`, ...). Buttons are honest about what they do: *Reload settings cache* refreshes the in-process App Configuration cache, and *Apply changes* is a soft restart that refreshes the cache and returns a clear status — no button is labeled "Restart" if it does not actually restart the container.
- **Ingestion bonus: Run jobs on demand.** Admins can trigger any of the scheduled ingestion jobs (blob, sharepoint, sharepoint purge, ...) from the Jobs tab with a single click. Changing a `CRON_RUN_*` schedule and applying reschedules the affected job in place — no restart needed.

Pinned components: orchestrator [`v2.8.9`](https://github.com/Azure/gpt-rag-orchestrator/releases/tag/v2.8.9), ingestion [`v2.4.7`](https://github.com/Azure/gpt-rag-ingestion/releases/tag/v2.4.7), UI `v2.3.13`, infra `v2.0.19`.

---

**[Release 2.9.1](https://github.com/Azure/GPT-RAG/tree/v2.9.1) - Authenticated uploads, Foundry Agent Service v2 stabilization, and Sweden Central unblocked**

The June release train delivers four themes:

- **Authenticated per-conversation uploads end-to-end.** The uploader identity is preserved during ingestion, the active conversation id flows through retrieval, and uploaded chunks are indexed with ACL metadata so `single_agent_rag` can return them inside the same conversation.
- **Foundry Agent Service v2 stabilization.** The orchestrator moves to the create-once/reuse model, the landing zone provisions the Cosmos DB data-plane RBAC that declarative and versioned Foundry agents require, and Dapr is explicitly enabled on the orchestrator, frontend, and ingestion Container Apps after the landing zone switched Dapr to opt-in.
- **Sweden Central unblocked.** Late-June fixes scope the Foundry Cosmos data-plane role assignment at the database level and turn the Cosmos analytical storage preflight into a regional warning instead of a hard failure.
- **Quality of life.** RAG search results expose a new `custom_metadata` field so retrieval can surface arbitrary blob metadata, and the deploy scripts now warn when `APP_CONFIG_ENDPOINT` drifts from the active azd environment.

---

### May 2026

**[Release 2.7.14](https://github.com/Azure/GPT-RAG/tree/v2.7.14) - Landing zone hardening and ingestion identity fixes**

The late-May patch train hardens GPT-RAG deployments by rolling the AI Landing Zone forward to v2.0.12, including fixes for network-isolated deployments, firewall rule generation, Container Apps image pulls, and bounded Windows jumpbox bootstrap execution. It also completes the ingestion Managed Identity fix so Azure Container Apps can acquire user-assigned identity tokens reliably and avoid `/ingest-documents` returning HTTP 200 with `indexedChunks: 0`.

---

**[Release 2.7.6](https://github.com/Azure/GPT-RAG/tree/v2.7.6) - Long conversation handling and retrieval triage**

GPT-RAG now consumes `gpt-rag-orchestrator` v2.6.9. The orchestrator bounds persisted conversation documents before saving to Cosmos DB, keeping recent messages and question metadata while preventing very long chats from growing indefinitely. The default local MAF path also classifies greetings, retrieval-needed questions, and no-retrieval follow-ups so transformations of the previous answer can skip unnecessary Azure AI Search calls.

---

**[Release 2.7.5](https://github.com/Azure/GPT-RAG/tree/v2.7.5) - Existing-platform deployment, NL2SQL, and conversation rename fixes**

GPT-RAG now exposes the AI Landing Zone existing-platform parameters from the root `main.parameters.json`, so operators can integrate with shared Private DNS Zones, observability, hub networking, existing jumpbox/Bastion/NAT resources, Private Endpoint placement, ACR Task agent pools, speech resources, and policy-managed DNS without editing the infra submodule.

Runtime component updates in this release move NL2SQL to Microsoft Agent Framework with direct model calls and local NL2SQL tool execution, removing Semantic Kernel Agent Service agent creation from that path. The chat UI also persists conversation renames by calling the orchestrator conversation update API.

---

**[Release 2.7.0](https://github.com/Azure/GPT-RAG/tree/v2.7.0) - AI Landing Zone v2.0 bump**

The underlying Azure AI Landing Zone Bicep module has been upgraded from v1.0.7 to v2.0.2 — a major-version baseline update. Default behavior is unchanged for existing operators; all new capabilities are opt-in via `azd env set`.

Highlights of what v2 brings to GPT-RAG operators:

- **IP allow-listing** (`allowedIpRanges`): uniform CIDR allow-list applied across Storage, Key Vault, App Configuration, Container Registry, Cosmos DB, AI Search, and the AI Foundry storage account.
- **BYO Private DNS zones / observability / hub-and-spoke** parameters for integration with an existing Azure Landing Zone hub.
- **Pre-flight validation hooks** that catch parameter contradictions before reaching ARM and fail fast when the selected GPT-RAG region lacks required VM SKU support, provider/location support, or Azure OpenAI model quota. The preflight is explicit about limits Azure does not expose reliably before creation, such as transient Cosmos DB high-demand capacity.
- **Cosmos `enableAnalyticalStorage` fix** — the implicit `true` default that caused intermittent provisioning failures is gone; now an explicit opt-in via `enableCosmosAnalyticalStorage`.
- **Network-isolated deployment procedure clarified** — workstations run only `azd provision`; `postProvision` and `azd deploy` run from the jumpbox/VNet with `RUN_FROM_JUMPBOX=true`, using ACR remote builds so Docker is not required on the VM.

See the [v2-migration guide](https://github.com/Azure/bicep-ptn-aiml-landing-zone/blob/v2.0.0/docs/v2-migration.md) and the [parameterization reference](https://azure.github.io/AI-Landing-Zones/bicep/parameterization) for the full v2 surface. No GPT-RAG component bumps in this release.

**[Release 2.6.7](https://github.com/Azure/GPT-RAG/tree/v2.6.7) - Per-conversation file uploads**

Users can now upload files directly through the chat interface. Documents are persisted to a per-conversation storage container, chunked and indexed into Azure AI Search with a `conversationId` field, and retrieved by the orchestrator with a filter that mixes conversation-private content with shared/global content. Implemented across coordinated component releases: `gpt-rag-ingestion` v2.3.4, `gpt-rag-orchestrator` v2.6.3, `gpt-rag-ui` v2.3.2.

---

### April 2026

**[Release 2.6.4](https://github.com/Azure/GPT-RAG/tree/v2.6.4) - Ingestion Enhancements, Ingestion Admin Dashboard, and Cost Optimization**

**Ingestion Admin Dashboard**

A new React-based admin dashboard is available at `/dashboard` for monitoring and managing ingestion jobs. It provides paginated job and file tables, search, filters, and the ability to unblock stuck files. Processing timings are displayed as stacked color bars showing each phase (download, analysis, chunking, index upload), and per-file cost estimates break down spending by service.

**Content Understanding Integration**

Document analysis now uses Azure AI Foundry Content Understanding (`prebuilt-layout`) by default instead of Document Intelligence, resulting in approximately 69% cost reduction per page.

**Reliability and Large File Handling**

Files that fail during ingestion are now tracked per attempt. After exceeding the maximum retries (default 3), the file is automatically blocked, preventing repeated reprocessing and unnecessary document analysis costs. Stale jobs stuck after a container crash are auto-recovered after 2 hours. Additionally, large PDFs exceeding the analysis page limit (default 300 pages) are split automatically, and a memory guard skips oversized files to prevent OOM crashes.

* Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/BRwGaBAIICg?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="User Feedback" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

---

**[Release 2.6.1](https://github.com/Azure/GPT-RAG/tree/v2.6.1) - Conversation History and Multimodal Improvements**

**Conversation History**

Users can now list, resume, and delete past conversations directly from a sidebar in the chat UI.

**Multimodal Improvements**

Images now appear inline between response steps instead of grouped at the bottom, with improved validation accuracy.

---

### March 2026

**[Release 2.5.3](https://github.com/Azure/GPT-RAG/tree/v2.5.3) - New Orchestration Strategies, Infrastructure Overhaul, and Multimodality**

**New Orchestration Strategies** 

The orchestrator now supports new agentic strategies: 

- **Agent Service v2** uses Azure AI Foundry Agent Service v2 for managed orchestration. 

- **Microsoft Agent Framework**, Lightweight orchestration with direct Foundry access, no Agent Service.

- **Agent Service + Agent Framework** combines Agent Service v2 with the Microsoft Agent Framework for advanced scenarios. 

- **Multimodal** adds image understanding support for multimodality scenarios.  

**Infrastructure as External Bicep Module**

Bicep infrastructure extracted to the external [`bicep-ptn-aiml-landing-zone`](https://github.com/Azure/bicep-ptn-aiml-landing-zone) module for better maintainability and reuse. Deploy scripts hardened. [#424](https://github.com/Azure/GPT-RAG/pull/424)

---

### January 2026

**[Release 2.4.0](https://github.com/Azure/GPT-RAG/tree/v2.4.0) - Authentication and Document-Level Security**

This release introduces Microsoft Entra ID authentication in the frontend, with orchestrator-side user identity validation, plus RBAC-based access control and document-level authorization in retrieval workflows. It propagates user identity context through ingestion and orchestration so [Azure AI Search can enforce fine-grained ACL/RBAC](https://learn.microsoft.com/en-us/azure/search/search-query-access-control-rbac-enforcement) permissions end-to-end. [#417](https://github.com/Azure/GPT-RAG/pull/417)
  
How to configure it: [Authentication and Document-Level Security](howto_authentication.md)

### December 2025

**[Release 2.3.0](https://github.com/Azure/GPT-RAG/tree/v2.3.0) - SharePoint Lists and Azure Direct Models**

**Azure Direct Models (Microsoft Foundry)**

You can use Microsoft Foundry “Direct from Azure” models (for example, Mistral, DeepSeek, Grok, Llama, etc.) through the Foundry inference APIs with Entra ID authentication. [#296](https://github.com/Azure/GPT-RAG/issues/296)
  
How to configure it: [Azure Direct Models](howto_azure_direct.md)
  
Demo Video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/P87o8UwiTHw?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="User Feedback" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>


**SharePoint Lists**

The SharePoint connector now covers both SharePoint Online document libraries (files like PDFs/Office docs) and generic lists (structured fields) so your Azure AI Search index stays in sync with list items and documents. [#369](https://github.com/Azure/GPT-RAG/issues/369)

How to configure it: [SharePoint Data Source](ingestion_sharepoint_source.md) and [SharePoint Connector Setup Guide](howto_sharepoint_connector.md)

---

### October 2025

**[Release 2.2.0](https://github.com/Azure/GPT-RAG/tree/v2.2.1) - Agentic Retrieval and Network Flexibility**

This release introduces major enhancements to support more flexible and enterprise-ready deployments.

**Bring Your Own VNet**

Enables organizations to deploy GPT-RAG within their existing virtual network, maintaining full control over network boundaries, DNS, and routing policies. [#370](https://github.com/Azure/GPT-RAG/issues/370)

**Agentic Retrieval**

Adds intelligent, agent-driven retrieval orchestration that dynamically selects and combines information sources for more grounded and context-aware responses. [#359](https://github.com/Azure/GPT-RAG/issues/359)

---

### September 2025

**[Release 2.1.0](https://github.com/Azure/GPT-RAG/tree/v2.1.2) - User Feedback Loop**

Introduces a mechanism for end-users to provide thumbs-up or thumbs-down feedback on assistant responses, storing these signals alongside conversation history to continuously improve response quality.

* How to configure it: [User Feedback Configuration](howto_userfeedback.md)
* Demo video:

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
