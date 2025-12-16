# 🚀 Deployment Guide

Choose your preferred deployment method based on project requirements and environment constraints.

> **Note:** You can change parameter values in `main.parameters.json` or set them with `azd env set` before running `azd provision`. This applies only to parameters that support environment variable substitution.

## Prerequisites

**Required Permissions:**

- Azure subscription with **Contributor** and **User Access Admin** roles
- Agreement to Responsible AI terms for Azure AI Services

**Required Tools:**

- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package) (Windows only)
- [Git](https://git-scm.com/downloads)
- [Python 3.12](https://www.python.org/downloads/release/python-3120/)

## Basic Deployment

Quick setup for demos without network isolation.

```
azd init -t azure/gpt-rag
az login
azd auth login
azd provision
```

> Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

Demo video:

<div style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; margin: 0 auto 20px auto; border-radius: 8px;">
  <iframe src="https://www.youtube.com/embed/nZMDtaDQuP4?rel=0&modestbranding=1" 
          style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;" 
          title="GPT-RAG Tutorial" 
          frameborder="0" 
          loading="lazy"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
          allowfullscreen>
  </iframe>
</div>

## Zero Trust Deployment

For deployments that **require network isolation**.

**Before Provisioning**

Enable network isolation in your environment:

```
azd env set NETWORK_ISOLATION true
```

Make sure you’re signed in with your Azure user account:

```

az login
azd auth login

```

> Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

**Provision Infrastructure**

```
azd provision
```

**Post-Provision Configuration**

After provisioning completes, you'll be prompted whether your machine has VNet access.

- If you have VNet access:

Answer `Y` when prompted. The post-provision script will run automatically and complete the configuration.

- If you don't have VNet access:

Answer `N` when prompted. You'll need to use the provisioned Jumpbox VM to complete the post-provision steps.

Using the Jumpbox VM

1) **Reset the VM password** in the Azure Portal (required on first access if not set in deployment parameters):

- Go to your VM resource → **Support + troubleshooting** → **Reset password** → Set new credentials
- Default username is `testvmuser`

2) **Connect via Azure Bastion**

3) **Authenticate with the VM's Managed Identity:**

   ```powershell
   az login --identity
   azd auth login --managed-identity
   ```

   > Add `--tenant` for `az` or `--tenant-id` for `azd` if you want a specific tenant.

4) **Run the post-provision script:**

   PowerShell:
   ```powershell
   cd c:\github\gpt-rag
   .\scripts\postProvision.ps1
   ```

   Bash:
   ```bash
   cd /mnt/c/github/gpt-rag
   ./scripts/postProvision.sh
   ```

> **Note:** If you have re-initialized or cloned the gpt-rag repo again, refresh your `azd` environment before running the postProvision script so it points to the **existing** deployment:
> `azd init -t azure/gpt-rag` then `azd env refresh`. When prompted, select the **same Subscription, Resource Group, and Location** as the original provisioning so `azd` correctly links to your environment.

## Deploy GPT-RAG Services

> **Note:** For Zero Trust deployments with network isolation, ensure you have VNet connectivity either through the Jumpbox VM or via VPN before deploying services. If using the Jumpbox VM, the repositories are located in the `c:\github` directory.

Once the GPT-RAG infrastructure is provisioned, you can deploy the services.

To deploy **all services at once**, navigate to the `gpt-rag` directory (with azd environment configured) and run:

```
azd deploy
```

This command deploys each service in sequence.

If you prefer to **deploy a single service**, for example, when updating only that service, you can deploy it individually. Below is an example using the orchestrator service. The same approach applies to other services (frontend, dataingest, mcp).

### Deploy Individual Services

Make sure you're logged in to Azure:

```bash
az login
```

**Example: Deploying the Orchestrator**

**Using azd (recommended):**

Initialize the template:
```shell
azd init -t azure/gpt-rag-orchestrator 
```

> **Important:** Use the **same environment name** with `azd init` as in the infrastructure deployment to keep components consistent.

Update environment variables then deploy:
```shell
azd env refresh
azd deploy 
```

> **Important:** Run `azd env refresh` with the **same subscription** and **resource group** used in the infrastructure deployment.

**Using a shell script:**

Clone the repository, set the App Configuration endpoint, and run the deployment script.

PowerShell (Windows):
```powershell
git clone https://github.com/Azure/gpt-rag-orchestrator.git
$env:APP_CONFIG_ENDPOINT = "https://<your-app-config-name>.azconfig.io"
cd gpt-rag-orchestrator
.\scripts\deploy.ps1
```

Bash (Linux/macOS):
```bash
git clone https://github.com/Azure/gpt-rag-orchestrator.git
export APP_CONFIG_ENDPOINT="https://<your-app-config-name>.azconfig.io"
cd gpt-rag-orchestrator
./scripts/deploy.sh
```

## Permissions

**Microsoft Foundry Role and AI Search Assignments**

| Resource                  | Role                       | Assignee           | Description                                |
| ------------------------- | -------------------------- | ------------------ | ------------------------------------------ |
| GenAI App Search Service  | Search Index Data Reader   | Microsoft Foundry Project | Read index data                            |
| GenAI App Search Service  | Search Service Contributor | Microsoft Foundry Project | Create AI Search connection                |
| GenAI App Storage Account | Storage Blob Data Reader   | Microsoft Foundry Project | Read blob data                             |
| Microsoft Foundry Account        | Cognitive Services User    | Search Service     | Allow Search Service to access vectorizers |

**Container App Role Assignments**

| Resource                      | Role                                | Assignee                   | Description               |
| ----------------------------- | ----------------------------------- | -------------------------- | ------------------------- |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: orchestrator | Read configuration data   |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: frontend     | Read configuration data   |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: dataingest   | Read configuration data   |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: mcp          | Read configuration data   |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: orchestrator | Pull container images     |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: frontend     | Pull container images     |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: dataingest   | Pull container images     |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: mcp          | Pull container images     |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: orchestrator | Read secrets              |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: frontend     | Read secrets              |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: dataingest   | Read secrets              |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: mcp          | Read secrets              |
| GenAI App Search Service      | Search Index Data Reader            | ContainerApp: orchestrator | Read index data           |
| GenAI App Search Service      | Search Index Data Contributor       | ContainerApp: dataingest   | Read/write index data     |
| GenAI App Search Service      | Search Index Data Contributor       | ContainerApp: mcp          | Read/write index data     |
| GenAI App Storage Account     | Storage Blob Data Reader            | ContainerApp: orchestrator | Read blob data            |
| GenAI App Storage Account     | Storage Blob Data Reader            | ContainerApp: frontend     | Read blob data            |
| GenAI App Storage Account     | Storage Blob Data Contributor       | ContainerApp: dataingest   | Read/write blob data      |
| GenAI App Storage Account     | Storage Blob Data Contributor       | ContainerApp: mcp          | Read/write blob data      |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data |
| Microsoft Foundry Account            | Cognitive Services User             | ContainerApp: orchestrator | Access Cognitive Services |
| Microsoft Foundry Account            | Cognitive Services User             | ContainerApp: dataingest   | Access Cognitive Services |
| Microsoft Foundry Account            | Cognitive Services User             | ContainerApp: mcp          | Access Cognitive Services |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: orchestrator | Use OpenAI APIs           |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: dataingest   | Use OpenAI APIs           |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: mcp          | Use OpenAI APIs           |

**Executor Role Assignments**

| Resource                      | Role                                | Assignee | Description                              |
| ----------------------------- | ----------------------------------- | -------- | ---------------------------------------- |
| GenAI App Configuration Store | App Configuration Data Owner        | Executor | Full control over configuration settings |
| GenAI App Container Registry  | AcrPush                             | Executor | Push container images                    |
| GenAI App Container Registry  | AcrPull                             | Executor | Pull container images                    |
| GenAI App Key Vault           | Key Vault Contributor               | Executor | Manage Key Vault settings                |
| GenAI App Key Vault           | Key Vault Secrets Officer           | Executor | Create Key Vault secrets                 |
| GenAI App Search Service      | Search Service Contributor          | Executor | Create/update search service elements    |
| GenAI App Search Service      | Search Index Data Contributor       | Executor | Read/write search index data             |
| GenAI App Search Service      | Search Index Data Reader            | Executor | Read index data                          |
| GenAI App Storage Account     | Storage Blob Data Contributor       | Executor | Read/write blob data                     |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor | Executor | Read/write Cosmos DB data                |
| Microsoft Foundry Account            | Cognitive Services OpenAI User      | Executor | Use OpenAI APIs                          |

**Jumpbox VM Role Assignments**

| Resource                      | Role                                                       | Assignee   | Description                                |
| ----------------------------- | ---------------------------------------------------------- | ---------- | ------------------------------------------ |
| GenAI App Container Apps      | Container Apps Contributor                                 | Jumpbox VM | Full control over Container Apps           |
| Azure Managed Identity        | Managed Identity Operator                                  | Jumpbox VM | Assign and manage user-assigned identities |
| GenAI App Container Registry  | Container Registry Repository Writer                       | Jumpbox VM | Write to ACR repositories                  |
| GenAI App Container Registry  | Container Registry Tasks Contributor                       | Jumpbox VM | Manage ACR tasks                           |
| GenAI App Container Registry  | Container Registry Data Access Configuration Administrator | Jumpbox VM | Manage ACR data access configuration       |
| GenAI App Container Registry  | AcrPush                                                    | Jumpbox VM | Push container images                      |
| GenAI App Configuration Store | App Configuration Data Owner                               | Jumpbox VM | Full control over configuration settings   |
| GenAI App Key Vault           | Key Vault Contributor                                      | Jumpbox VM | Manage Key Vault settings                  |
| GenAI App Key Vault           | Key Vault Secrets Officer                                  | Jumpbox VM | Create Key Vault secrets                   |
| GenAI App Search Service      | Search Service Contributor                                 | Jumpbox VM | Create/update search service elements      |
| GenAI App Search Service      | Search Index Data Contributor                              | Jumpbox VM | Read/write search index data               |
| GenAI App Storage Account     | Storage Blob Data Contributor                              | Jumpbox VM | Read/write blob data                       |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor                        | Jumpbox VM | Read/write Cosmos DB data                  |
| Microsoft Foundry Account            | Cognitive Services Contributor                             | Jumpbox VM | Manage Cognitive Services resources        |
| Microsoft Foundry Account            | Cognitive Services OpenAI User                             | Jumpbox VM | Use OpenAI APIs                            |
