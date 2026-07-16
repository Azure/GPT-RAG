This page covers common issues, debugging tools, and how to inspect logs in GPT-RAG.


## Embedded chat

Use this matrix when a portal embeds GPT-RAG through Chainlit Copilot. Start by
confirming `CHAINLIT_COPILOT_ENABLED=true`, verifying that
`CHAINLIT_COPILOT_AUTH_MODE` is explicitly `anonymous` or `entra`, and checking
the exact public base from `CHAINLIT_URL` plus `CHAINLIT_ROOT_PATH`.

| Symptom | Likely cause | What to check | Recovery |
| --- | --- | --- | --- |
| Widget stays on "Loading assistant..." | Bundle blocked, bootstrap failed, or CSP blocked script execution | Network and Console for `{publicBase}/copilot/auth/bootstrap` and `{publicBase}/copilot/index.js`; portal `script-src` | Fix the first failed request. Mount only after bootstrap succeeds. |
| Same-origin path returns 404 | The proxy stripped, duplicated, or ambiguously rewrote `CHAINLIT_ROOT_PATH` | Confirm `/gpt-rag` reaches GPT-RAG UI unchanged and `chainlitServer` includes it | Preserve the exact prefix. Do not rely on `X-Forwarded-Prefix`. |
| Anonymous bootstrap returns 400 | The request sent `Authorization` while `CHAINLIT_COPILOT_AUTH_MODE=anonymous` | Request headers | Remove the header. Anonymous mode never consumes or falls back from a token. |
| Entra bootstrap returns 401 | Token signature, version, issuer, audience, tenant, identity, scope, or time validation failed | RS256, `ver=2.0`, `iss`, `aud`, `tid`, `oid`, `scp`, `exp`, and `nbf`; confirm the portal requested the delegated GPT-RAG API scope | Acquire one fresh delegated token and retry once. Do not pass it to widget `accessToken`. |
| Bootstrap returns a readable 403 | The Entra `azp` is not allowed or the valid user fails GPT-RAG authorization | `CHAINLIT_COPILOT_ENTRA_ALLOWED_CLIENT_IDS`, `ALLOWED_USER_PRINCIPALS`, and `ALLOWED_USER_NAMES` | Correct the authorized portal or user policy. Do not fall back to anonymous. |
| Bootstrap appears as a CORS or network error | Browser `Origin` is not allowlisted exactly | Compare scheme, host, and port with `CHAINLIT_ALLOWED_ORIGINS`; remove paths, wildcards, and `null` | Add the exact HTTPS origin and restart GPT-RAG UI. |
| Bootstrap returns 429 | The process-local bootstrap attempt limit was reached | `Retry-After`, gateway/WAF limits, and aggregate traffic behind trusted ingress | Honor `Retry-After` and stop automatic retries. Configure authoritative ingress throttling. |
| Bootstrap returns 503 | GPT-RAG UI could not retrieve Entra signing keys | UI connectivity to the tenant v2 JWKS and service logs | Show an unavailable state. Do not start a sign-in loop or anonymous fallback. |
| Bootstrap succeeds but the widget reports authentication failure | The opaque session cookie was omitted, blocked, or scoped to the wrong path | `credentials: "include"`, `Set-Cookie`, cookie path, `SameSite`, and gateway cookie preservation; probe `{publicBase}/project/settings` | Fix cookie delivery. Never put the Entra token in `accessToken`. |
| Widget loads, then disconnects | Socket.IO route, WebSocket upgrade, session expiry, or affinity is broken | `{publicBase}/ws/socket.io` polling and upgrade; cookie; exact origin; backend affinity; WebSocket `4401` | Route all transports to the same session, preserve cookies, and rebootstrap once if the session expired. |
| Reconnect or retry duplicates a message | The portal retried the send operation instead of only the connection | Network trace around the last send and Socket.IO reconnect | Preserve the transcript and draft, reconnect first, and never automatically resend the last message. |
| Session stops near token expiry | The earlier of Entra `exp` and the configured Copilot TTL was reached | Bootstrap `expiresAt`, session TTL, eviction, process restart, or revision switch | In Entra mode acquire one fresh token; in anonymous mode send no token. Rebootstrap once, then offer recovery. |
| Works in one browser but not another | Third-party cookies, tracking prevention, private browsing, or enterprise browser policy blocks the cookie | Browser cookie warnings and whether the portal and GPT-RAG UI are unrelated sites | Prefer a same-origin path or sibling subdomain. Cross-site embedding is best effort; provide a standalone link. |
| Browser does not render or operate the widget correctly | The browser does not support the tested Chainlit 2.9.4 Shadow DOM, storage, or WebSocket behavior | Supported browser matrix, JavaScript policy, local storage, CSP, and WebSocket support | Use a supported current browser and provide a standalone fallback. Sidebar mode is not supported. |
| Citation or download returns 404 | Grant expired or changed, session is stale, conversation ownership failed, path is unsafe, or blob is absent | Absolute URL under `{publicBase}/api/download/{grant_token}`; current session; unchanged grant; conversation ownership | Reopen the citation from the current conversation. Do not replace the grant with a SAS or public-blob URL. The server intentionally uses 404 for denied and missing targets. |
| Citation opens a portal 404 outside GPT-RAG | Public root path was omitted from an absolute URL or the proxy route is incomplete | `CHAINLIT_URL`, `CHAINLIT_ROOT_PATH`, rendered `href`, and gateway path rule | Use the server-generated absolute URL and route the full public base. |
| A different account sees a previous thread | The portal remounted without clearing Copilot state | Logout/account-switch handler, `#chainlit-copilot`, and `chainlit-copilot-thread-id` | Stop the widget immediately, remove local state, call Copilot logout, and mount only after a clean bootstrap. |
| CSP blocks styles or fonts | Chainlit 2.9.4 injects Shadow DOM styles and may load Google Inter | Console violations for `style-src` and `font-src` | Add the required `style-src 'unsafe-inline'` exception with security-owner review, and allow approved font sources or self-host the font. |

The embedded widget is not an iframe. Changing `frame-src`,
`X-Frame-Options`, or GPT-RAG UI `frame-ancestors` does not fix a bundle, CORS,
cookie, or WebSocket failure.

See [Embed the chat in a portal](howto_embed_chat.md) for the complete setup and
validation checklist.


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
