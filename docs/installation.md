## Standard installation

Use this page for a standard GPT-RAG deployment without private network isolation. The authoritative step-by-step flow is the [Basic Deployment](deploy.md#basic-deployment) section of the Deployment Guide; this page exists as a short installation entry point.

## Quick path

- **Initialize the template:** run `azd init -t azure/gpt-rag` in a clean working directory.
- **Authenticate:** run `az login` and `azd auth login` before provisioning.
- **Select public/basic mode:** set `NETWORK_ISOLATION=false` for a non-isolated deployment.
- **Provision and deploy:** run `azd provision`, then `azd deploy`.

```powershell
azd init -t azure/gpt-rag
az login
azd auth login
azd env set NETWORK_ISOLATION false
azd provision
azd deploy
```

For required permissions, tools, preflight checks, regional quota notes, and service deployment details, continue with the [Deployment Guide](deploy.md).

