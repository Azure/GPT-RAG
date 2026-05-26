## Zero Trust installation

Use this page for GPT-RAG deployments with network isolation enabled. The authoritative step-by-step flow is the [Zero Trust Deployment](deploy.md#zero-trust-deployment) section of the Deployment Guide; this page exists as a short installation entry point.

## Quick path

- **Provision from the workstation:** set `NETWORK_ISOLATION=true`, then run `azd provision`.
- **Continue from inside the VNet:** use the jumpbox or another VNet-connected host for data-plane configuration and service deployment.
- **Run post-provision from the jumpbox:** set `RUN_FROM_JUMPBOX=true`, then run `scripts\postProvision.ps1`.
- **Deploy services from the jumpbox:** run `azd deploy` with `RUN_FROM_JUMPBOX=true`; component scripts use Azure Container Registry remote builds for isolated deployments.

```powershell
azd env set NETWORK_ISOLATION true
azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING true
azd provision

# From the jumpbox or another VNet-connected host:
azd env set RUN_FROM_JUMPBOX true
azd env set ACR_TASK_AGENT_POOL build-pool
.\scripts\postProvision.ps1
azd deploy
```

Do not run `azd deploy` from a workstation outside the VNet when `NETWORK_ISOLATION=true`. For the full flow, including Bastion/jumpbox access, post-provision behavior, and troubleshooting notes, continue with the [Deployment Guide](deploy.md#zero-trust-deployment).

