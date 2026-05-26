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

