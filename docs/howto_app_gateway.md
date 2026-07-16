## Application Gateway public ingress

GPT-RAG uses the Azure AI Landing Zone Bicep module for network-isolated infrastructure. Application Gateway WAF v2 public ingress is implemented in that landing-zone module, while GPT-RAG exposes the `publicIngress` parameter from the root `main.parameters.json`.

!!! tip "Full runbook"
    Follow the AI Landing Zone runbook for certificate, DNS, validation, and teardown steps: [Public Ingress with Application Gateway](https://azure.github.io/AI-Landing-Zones/bicep/public-ingress/).

## When to use it

- **Use Application Gateway** when `NETWORK_ISOLATION=true` and one private Container App needs a controlled public HTTPS entry point.
- **Do not use it for basic deployments** unless you specifically need a public WAF entry point in front of an internal Container Apps environment.
- **Expect extra cost** because Application Gateway WAF_v2 and Standard Public IP incur hourly charges while deployed.

## GPT-RAG configuration handoff

Do not edit `infra/` directly. Before running `azd provision`, update GPT-RAG's root `main.parameters.json`; the pre-provision hook copies this file into the landing-zone module as the deployment parameter override.

Start with skeleton mode so the gateway resources are created but public traffic remains closed:

```json
"publicIngress": {
  "value": {
    "enabled": true
  }
}
```

After you have the hostname, Key Vault certificate secret URI, DNS record, and allowed source CIDRs, move to live mode:

```json
"publicIngress": {
  "value": {
    "enabled": true,
    "backendAppIndex": 1,
    "frontendHostName": "app.contoso.com",
    "sslCertSecretId": "https://<key-vault-name>.vault.azure.net/secrets/<certificate-name>",
    "allowedSourceAddressPrefixes": [
      "203.0.113.10/32"
    ]
  }
}
```

For GPT-RAG's default `containerAppsList`, `backendAppIndex: 1` points to the frontend app. Use the AI Landing Zone runbook for the complete two-step flow and for the `PUBLIC_INGRESS_*` outputs to validate the deployed gateway.

## Reverse proxy requirements for embedded chat

When a portal embeds GPT-RAG with Chainlit Copilot, prefer a same-origin path
such as `https://portal.contoso.com/gpt-rag`:

```text
CHAINLIT_URL=https://portal.contoso.com
CHAINLIT_ROOT_PATH=/gpt-rag
CHAINLIT_ALLOWED_ORIGINS=https://portal.contoso.com
```

The public base is the exact concatenation of `CHAINLIT_URL` and
`CHAINLIT_ROOT_PATH`. Configure one Application Gateway path rule for
`/gpt-rag` and `/gpt-rag/*`. Forward that prefix unchanged to GPT-RAG UI. Do
not strip it, duplicate it, percent-encode it, or rely on
`X-Forwarded-Prefix` to add it. Requests outside the prefix remain portal
routes.

The rule must route every public GPT-RAG UI path to the same backend:

- `/gpt-rag/copilot/index.js`;
- `/gpt-rag/copilot/auth/bootstrap` and `/gpt-rag/copilot/auth/logout`;
- `/gpt-rag/project/settings` and other authorized `/gpt-rag/project/*` APIs;
- `/gpt-rag/ws/socket.io` polling, POST, and WebSocket upgrade traffic;
- `/gpt-rag/assets/*`, `/gpt-rag/public/*`, and
  `/gpt-rag/version-footer`;
- `/gpt-rag/api/download/{grant_token}`.

For each route:

- preserve the external `Host`, exact `Origin`, methods, query strings, request
  bodies, and HTTPS scheme;
- preserve `Set-Cookie` and `Cookie` headers and do not cache authenticated
  bootstrap, settings, logout, or download responses;
- do not rewrite the cookie path. Copilot and Chainlit cookies are scoped to
  `CHAINLIT_ROOT_PATH`;
- enable WebSocket upgrades and use an idle timeout suitable for streamed
  responses;
- keep bootstrap, HTTP, Socket.IO polling and upgrade, and WebSocket traffic on
  the same backend session if more than one replica is used;
- do not rewrite an unapproved origin into an allowed origin;
- keep TLS from the browser to the gateway. Use end-to-end TLS when required by
  the network security design.

GPT-RAG UI does not infer its public URL from forwarding headers. Set
`CHAINLIT_URL` and `CHAINLIT_ROOT_PATH` to the externally visible values so
bundle URLs and absolute `/api/download/{grant_token}` links are correct.

Copilot session and retained Entra token state are process-local. One active
revision with `minReplicas=1` and `maxReplicas=1` is the supported baseline.
Affinity across all routes above is required for multiple replicas, but it does
not provide high availability. A restart or revision switch signs users out.

The portal owns the CSP that allows the bundle and connection. Add the public
GPT-RAG UI HTTPS origin to `script-src` and `connect-src`, and its WSS origin to
`connect-src`. Chainlit 2.9.4 also requires `style-src 'unsafe-inline'` for
styles injected into the Shadow DOM. Scope and review that exception with the
portal security owner. Do not add `frame-src` for Copilot because the widget is
not an iframe.

For exact origins, cookies, CSP, authentication, and browser limitations, see
[Embed the chat in a portal](howto_embed_chat.md).
