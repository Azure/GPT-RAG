# Embed the chat in a portal

Use Chainlit Copilot when users should open GPT-RAG from an existing web portal
instead of navigating to the standalone UI. Embedding is disabled by default.
When it is enabled, you must explicitly select `anonymous` or `entra`
authentication. An Entra failure never falls back to anonymous access.

GPT-RAG UI currently pins Chainlit 2.9.4. In this version, Copilot injects a
floating button and popover into an open Shadow DOM in the portal page. It does
not use an iframe. Sidebar mode requires Chainlit 2.11 or later and is outside
the scope of this integration.

## Before you start

You need:

- a GPT-RAG UI version that includes Copilot embedding support;
- an HTTPS portal origin, for example `https://portal.contoso.com`;
- permission to update GPT-RAG UI settings in Azure App Configuration;
- control of the portal Content Security Policy (CSP) and reverse proxy;
- for Entra mode, a portal SPA registration and a delegated GPT-RAG API scope.

Publish GPT-RAG UI through the approved gateway or reverse proxy. Do not expose
the internal Container App directly.

## Choose a topology

Use the first topology your portal can support.

| Topology | Example | Support level | Required action |
| --- | --- | --- | --- |
| Same-origin path | Portal `https://portal.contoso.com`, GPT-RAG at `/gpt-rag` | Preferred | Preserve the complete `/gpt-rag` prefix for HTTP, Socket.IO, WebSocket, assets, and downloads. |
| Sibling subdomain | Portal `https://portal.contoso.com`, GPT-RAG `https://chat.contoso.com` | Supported | Add the exact portal origin and preserve cookies. This is cross-origin but normally same-site. |
| Unrelated site | Portal `https://contoso-portal.com`, GPT-RAG `https://gpt-rag.example.net` | Best effort | Use exact CORS and `SameSite=None`. Test every target browser because third-party-cookie policies can block the session. |

An origin contains the scheme, host, and port only. Configure a public path
separately with `CHAINLIT_ROOT_PATH`. Never use a path, wildcard, query string,
fragment, credentials, or the `null` origin in `CHAINLIT_ALLOWED_ORIGINS`.

## Configure GPT-RAG UI

Add these settings to Azure App Configuration with the `gpt-rag-ui` or
`gpt-rag` label. Environment variables with the same names take precedence.

| Setting | Required | Value |
| --- | --- | --- |
| `CHAINLIT_COPILOT_ENABLED` | Yes | Set to `true`. Default: `false`. |
| `CHAINLIT_COPILOT_AUTH_MODE` | Yes | Set explicitly to `anonymous` or `entra`. There is no default. |
| `CHAINLIT_AUTH_SECRET` | Yes | Persistent secret with at least 32 UTF-8 bytes and 256 bits of entropy. Store it through a Key Vault-backed reference. Never expose it to the portal. |
| `CHAINLIT_URL` | Yes | Exact public HTTPS origin, such as `https://portal.contoso.com`. Paths are rejected. |
| `CHAINLIT_ROOT_PATH` | Same-origin | Canonical public prefix, such as `/gpt-rag`. A non-root path is required when the portal origin equals `CHAINLIT_URL`. |
| `CHAINLIT_ALLOWED_ORIGINS` | Yes | Comma-separated exact portal origins, with at most 20 entries. |
| `CHAINLIT_COOKIE_SAMESITE` | No | `lax` by default. Use `none` only for a cross-site HTTPS deployment. |
| `CHAINLIT_COPILOT_ENTRA_TENANT_ID` | Entra | Tenant GUID accepted in `tid` and the exact v2 issuer. |
| `CHAINLIT_COPILOT_ENTRA_AUDIENCE` | Entra | Exact API audience expected in `aud`. |
| `CHAINLIT_COPILOT_ENTRA_ALLOWED_CLIENT_IDS` | Entra | Comma-separated portal application client GUIDs, with at most 50 entries. The token's `azp` must match. |
| `CHAINLIT_COPILOT_ENTRA_REQUIRED_SCOPE` | No | Delegated scope required in `scp` for Entra mode. Default: `user_impersonation`. |
| `CHAINLIT_COPILOT_SESSION_TTL_SECONDS` | No | Session lifetime from 60 to 86400 seconds. Default: 3600. Entra expiry can shorten it. |
| `CHAINLIT_COPILOT_MAX_SESSIONS` | No | Maximum process-local sessions from 1 to 10000. Default: 1000. |
| `CHAINLIT_COPILOT_BOOTSTRAP_RATE_LIMIT_PER_MINUTE` | No | Process-local attempt limit from 1 to 600. Default: 60. Enforce authoritative throttling at trusted ingress. |
| `CITATION_SHARED_DOWNLOAD_CONTAINERS` | No | Configured document or image containers with uniform access for every authorized UI user. Default: empty. Never list permission-trimmed containers. |

Unsafe or incomplete enabled configuration fails startup. The Copilot
authentication mode is separate from standalone OAuth and `ALLOW_ANONYMOUS`.
When Copilot is disabled, standalone behavior is unchanged. Enabling Copilot
changes the process default for standalone anonymous access to `false`; set
`ALLOW_ANONYMOUS=true` explicitly if standalone anonymous access must remain
available without OAuth.

Restart GPT-RAG UI after changing these settings. Rotating
`CHAINLIT_AUTH_SECRET` signs out users and invalidates existing Chainlit tokens
and download grants.

`CHAINLIT_ROOT_PATH` must start with one `/` and must not end with `/`. Dot
segments, empty segments, percent encoding, a query, and a fragment are
rejected. A portal origin can equal `CHAINLIT_URL` only when this path is
non-root.

### Configure the preferred same-origin path

```text
CHAINLIT_URL=https://portal.contoso.com
CHAINLIT_ROOT_PATH=/gpt-rag
CHAINLIT_ALLOWED_ORIGINS=https://portal.contoso.com
```

The public base is `https://portal.contoso.com/gpt-rag`. The reverse proxy must
preserve the exact `/gpt-rag` prefix and send it to GPT-RAG UI. Do not strip the
prefix and do not rely on `X-Forwarded-Prefix` to add it. Requests outside that
prefix remain portal routes.

All GPT-RAG UI routes are under the public base:

| Purpose | Path under the public base |
| --- | --- |
| Copilot bundle | `/copilot/index.js` |
| Session bootstrap | `/copilot/auth/bootstrap` |
| Session logout | `/copilot/auth/logout` |
| Widget settings and APIs | `/project/settings` and `/project/*` |
| Socket.IO polling and upgrade | `/ws/socket.io` |
| Static content | `/assets/*`, `/public/*`, and `/version-footer` |
| Citation download | `/api/download/{grant_token}` |

For this example, the bootstrap URL is
`https://portal.contoso.com/gpt-rag/copilot/auth/bootstrap`.

For a sibling subdomain, use exact origins and no root prefix:

```text
CHAINLIT_URL=https://chat.contoso.com
CHAINLIT_ROOT_PATH=
CHAINLIT_ALLOWED_ORIGINS=https://portal.contoso.com
CHAINLIT_COOKIE_SAMESITE=none
```

The portal must use `credentials: "include"` and the UI must return an exact
CORS response for `https://portal.contoso.com`. An unrelated site uses the same
cookie setting but remains best effort because browsers can reject third-party
cookies.

## Add an anonymous widget

Anonymous mode must be deliberate:

```text
CHAINLIT_COPILOT_ENABLED=true
CHAINLIT_COPILOT_AUTH_MODE=anonymous
CHAINLIT_URL=https://portal.contoso.com
CHAINLIT_ROOT_PATH=/gpt-rag
CHAINLIT_ALLOWED_ORIGINS=https://portal.contoso.com
CHAINLIT_AUTH_SECRET=<Key Vault-backed secret with at least 32 bytes>
```

Call bootstrap without an `Authorization` header. Supplying one returns `400`;
it is never treated as an anonymous fallback.

```html
<div id="gpt-rag-status" role="status">Loading assistant...</div>
<script>
  const chainlitServer = "https://portal.contoso.com/gpt-rag";

  async function startAnonymousAssistant() {
    const status = document.getElementById("gpt-rag-status");
    const bootstrap = await fetch(
      `${chainlitServer}/copilot/auth/bootstrap`,
      { method: "POST", credentials: "include" }
    );

    if (!bootstrap.ok) {
      status.textContent = "The assistant is unavailable.";
      return;
    }

    const probe = await fetch(`${chainlitServer}/project/settings`, {
      credentials: "include"
    });
    if (!probe.ok) {
      await fetch(`${chainlitServer}/copilot/auth/logout`, {
        method: "POST",
        credentials: "include"
      });
      status.textContent = "The assistant session could not be established.";
      return;
    }

    const script = document.createElement("script");
    script.src = `${chainlitServer}/copilot/index.js`;
    script.onload = () => {
      window.mountChainlitWidget({ chainlitServer, theme: "light" });
      status.hidden = true;
    };
    script.onerror = () => {
      status.textContent = "The assistant is unavailable.";
    };
    document.head.appendChild(script);
  }

  void startAnonymousAssistant();
</script>
```

Anonymous sessions use an ephemeral identity. Durable thread recovery,
user-bound uploads, feedback, and authenticated citation downloads are not
available. Unauthorized citations appear as text instead of insecure links.

## Add an Entra-authenticated widget

Use an allowed portal app to obtain a delegated v2 access token for the GPT-RAG
API. GPT-RAG UI validates the token, creates a bounded server session, and sets
an opaque `HttpOnly; Secure` cookie. The cookie contains neither the Entra token
nor a Chainlit token.

```text
CHAINLIT_COPILOT_ENABLED=true
CHAINLIT_COPILOT_AUTH_MODE=entra
CHAINLIT_URL=https://portal.contoso.com
CHAINLIT_ROOT_PATH=/gpt-rag
CHAINLIT_ALLOWED_ORIGINS=https://portal.contoso.com
CHAINLIT_AUTH_SECRET=<Key Vault-backed secret with at least 32 bytes>
CHAINLIT_COPILOT_ENTRA_TENANT_ID=11111111-1111-4111-8111-111111111111
CHAINLIT_COPILOT_ENTRA_AUDIENCE=api://22222222-2222-4222-8222-222222222222
CHAINLIT_COPILOT_ENTRA_ALLOWED_CLIENT_IDS=33333333-3333-4333-8333-333333333333
CHAINLIT_COPILOT_ENTRA_REQUIRED_SCOPE=user_impersonation
```

The allowed client ID is the portal app registration's application client ID.
The access token must contain `ver=2.0` and an `azp` GUID in that allowlist.
`appid`-only v1 tokens are rejected.

Do not pass the raw Entra token to
`mountChainlitWidget({ accessToken: ... })`. In Chainlit 2.9.4,
`accessToken` expects a Chainlit session token signed with
`CHAINLIT_AUTH_SECRET`, not an Entra token.

```html
<div id="gpt-rag-status" role="status">Loading assistant...</div>
<script>
  const chainlitServer = "https://portal.contoso.com/gpt-rag";
  let sessionExpiryTimer;

  async function bootstrapAssistant(accessToken) {
    return fetch(`${chainlitServer}/copilot/auth/bootstrap`, {
      method: "POST",
      credentials: "include",
      headers: { Authorization: "Bearer " + accessToken }
    });
  }

  function removeAssistantUi() {
    clearTimeout(sessionExpiryTimer);
    window.unmountChainlitWidget?.();
    document.getElementById("chainlit-copilot")?.remove();
    localStorage.removeItem("chainlit-copilot-thread-id");
  }

  async function stopAssistant() {
    removeAssistantUi();
    try {
      await fetch(`${chainlitServer}/copilot/auth/logout`, {
        method: "POST",
        credentials: "include"
      });
    } catch {
      // The local UI is already gone. The bounded server session will expire.
    }
  }

  async function loadCopilotBundle() {
    if (typeof window.mountChainlitWidget === "function") return;
    await new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = `${chainlitServer}/copilot/index.js`;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  function scheduleRefresh(expiresAt) {
    const refreshAt = Number(expiresAt) * 1000 - Date.now() - 30_000;
    if (Number.isFinite(refreshAt)) {
      sessionExpiryTimer = setTimeout(
        () => void restartAssistant(),
        Math.max(0, refreshAt)
      );
    }
  }

  async function startAssistant({ forceRefresh = false } = {}) {
    const status = document.getElementById("gpt-rag-status");
    status.hidden = false;
    status.textContent = "Loading assistant...";

    try {
      let token = await portalAuth.getGptRagAccessToken({ forceRefresh });
      let response = await bootstrapAssistant(token);

      if (response.status === 401 && !forceRefresh) {
        token = await portalAuth.getGptRagAccessToken({ forceRefresh: true });
        response = await bootstrapAssistant(token);
      }

      if (!response.ok) {
        status.textContent = response.status === 403
          ? "You do not have access to this assistant."
          : "The assistant is temporarily unavailable.";
        return;
      }

      const session = await response.json();
      const probe = await fetch(`${chainlitServer}/project/settings`, {
        credentials: "include"
      });
      if (!probe.ok) {
        throw new Error("The assistant cookie was not established.");
      }
      await loadCopilotBundle();
      window.mountChainlitWidget({ chainlitServer, theme: "light" });
      scheduleRefresh(session.expiresAt);
      status.hidden = true;
    } catch {
      await stopAssistant();
      status.hidden = false;
      status.textContent = "The assistant is temporarily unavailable.";
    }
  }

  async function restartAssistant() {
    await stopAssistant();
    await startAssistant({ forceRefresh: true });
  }

  void startAssistant();
</script>
```

Bootstrap returns
`{"success":true,"authMode":"entra","expiresAt":<unix-seconds>}` and the
session cookie. Honor `429 Retry-After`. After one forced token refresh fails,
stop retrying and show an explicit sign-in or unavailable action.

## Configure the portal CSP

The portal's CSP governs the widget because the Shadow DOM is part of the portal
document. GPT-RAG UI response headers do not set the portal's policy.

For a sibling subdomain such as `https://chat.contoso.com`, permit:

```text
script-src 'self' https://chat.contoso.com;
connect-src 'self' https://chat.contoso.com wss://chat.contoso.com;
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob: https://chat.contoso.com;
```

Chainlit 2.9.4 requires inline styles injected into the Shadow DOM. Scope this
exception to the portal that hosts the widget and review it with the portal
security owner. If no custom font is configured, the bundle loads Google Inter.
Permit the required Google style and font origins or configure an approved
self-hosted font.

No `frame-src` change is required because Copilot is not an iframe. If a
nonce-based policy loads the bundle dynamically, give each new script element a
valid nonce, including after an account switch.

## Treat the browser bridge as untrusted input

Shadow DOM isolates styles, not trust. Scripts already running in the portal can
inspect the open shadow root and call Chainlit browser globals.

GPT-RAG default-denies `call_fn` and `window_message` for Copilot sessions in
both directions. Do not place credentials, tokens, customer data, or
authorization decisions in browser events. Chainlit 2.9.4 still contains
browser-global APIs and wildcard `postMessage` behavior in its bundle, so these
convenience APIs are not authorization boundaries.

## Handle logout, account switch, and expiry

The portal owns the complete widget lifecycle. On logout or account switch:

1. Stop accepting new chat input.
2. Unmount the widget and remove `#chainlit-copilot`.
3. Remove `chainlit-copilot-thread-id` from local storage.
4. `POST` to `{publicBase}/copilot/auth/logout` with
   `credentials: "include"`.
5. Clear the portal's cached delegated token.
6. For a new account, acquire a new token, bootstrap, and then mount a fresh
   widget.

The logout endpoint deletes the bounded server session, disconnects active
sockets, and clears the cookie. A successful bootstrap also replaces the
previous session. Do not let a user send another message if stale content from a
different account is visible.

The cookie and thread key are shared across tabs in one browser profile. A
bootstrap in one tab replaces the server session used by the others. If the
portal supports multiple tabs, coordinate lifecycle changes with
`BroadcastChannel` or an equivalent portal-owned mechanism. Do not support
different accounts concurrently in separate tabs.

Use the bootstrap `expiresAt` value to refresh before planned expiry. A session
can also disappear after eviction, process restart, revision replacement, or
affinity loss. On HTTP `401`, Socket.IO authentication failure, or WebSocket
`4401`, clear local state and bootstrap once. Do not retry indefinitely or
automatically resend the user's last message.

## Use absolute citation and download URLs

GPT-RAG UI returns absolute citation URLs based on `CHAINLIT_URL` plus
`CHAINLIT_ROOT_PATH`. Authorized links use
`/api/download/{grant_token}`. The short-lived signed grant is bound to the
principal, conversation, container, and blob. The server rechecks session and
conversation ownership before streaming the file.

Do not replace these URLs with relative links, public blobs, or SAS fallbacks.
Leave `CITATION_SHARED_DOWNLOAD_CONTAINERS` empty for permission-trimmed
content. Unauthorized citations render as text.

## Browser and deployment limitations

- Unrelated cross-site operation depends on the browser accepting a
  `SameSite=None; Secure` third-party cookie. There is no safe application
  fallback when it is blocked.
- Only Chainlit 2.9.4 floating mode is supported.
- Anonymous sessions have no durable identity, thread recovery, user-bound
  upload, feedback, or authenticated citation download.
- Copilot session state and retained Entra tokens are process-local. One active
  revision with one UI replica is the supported baseline. Scale-out requires
  affinity for bootstrap, HTTP, Socket.IO polling and upgrade, and WebSocket,
  but affinity is not high availability.
- Restart, revision replacement, eviction, or affinity loss signs affected
  users out.

## Validate the integration

Complete this checklist in each supported browser:

- [ ] Embedding is off by default and the standalone UI remains unchanged.
- [ ] `CHAINLIT_COPILOT_AUTH_MODE` is explicitly `anonymous` or `entra`.
- [ ] The public base preserves the exact `CHAINLIT_ROOT_PATH`.
- [ ] The bundle creates an open Shadow DOM floating widget.
- [ ] An unlisted `Origin` is rejected for HTTP, Socket.IO, and WebSocket.
- [ ] Anonymous bootstrap omits `Authorization`; Entra bootstrap never falls
      back to anonymous.
- [ ] Entra accepts only the configured v2 issuer, tenant, audience, delegated
      scope, `tid`, `oid`, and allowed portal `azp`.
- [ ] ID, Graph, app-only, v1, expired, future, and wrong-issuer tokens are
      rejected.
- [ ] No Entra token appears in widget configuration, local storage, page
      source, or logs.
- [ ] HTTPS chat and WSS streaming work through the gateway.
- [ ] Disconnect and retry do not duplicate the user's last message.
- [ ] Expiry performs one refresh or rebootstrap and then offers recovery.
- [ ] Logout and account switch clear the widget, server session, and thread
      state.
- [ ] Download links are absolute and use `/api/download/{grant_token}` under
      the public base.
- [ ] Keyboard focus, Escape, visible focus, screen-reader announcements, and
      320 px layout are usable.
- [ ] A blocked third-party cookie produces a clear error and a standalone
      fallback.

See [Troubleshooting](troubleshooting.md#embedded-chat) for failure symptoms and
recovery steps.
