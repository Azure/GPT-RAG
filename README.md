<!-- 
page_type: sample
languages:
- azdeveloper
- powershell
- bicep
products:
- azure
- azure-ai-foundry
- azure-openai
- azure-ai-search
urlFragment: GPT-RAG
name: Multi-repo ChatGPT and Enterprise data with Azure OpenAI and AI Search
description: GPT-RAG core is a Retrieval-Augmented Generation pattern running in Azure, using Azure AI Search for retrieval and Azure OpenAI large language models to power ChatGPT-style and Q&A experiences.
-->
<img src="media/logo.png" alt="Enterprise RAG Logo" width="80" align="left"/>

# GPT-RAG Solution Accelerator

This repository provides templates to quickly set up all the core Azure resources needed for RAG applications, allowing you to build a secure and scalable environment based on proven architecture patterns. Retrieval-Augmented Generation (RAG) enables large language models to generate responses grounded in your organization’s data, so answers stay current without retraining the model. This accelerator delivers an enterprise-ready foundation with zero-trust security, Responsible AI features, high availability, and auditing—making it ideal for moving from prototypes to MVPs or production.

### Architecture

![Zero Trust Architecture](media/architecture-zero-trust.png)

#### GPT-RAG Services

* **[Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)** – Agent-based info retrieval and response via Semantic Kernel & Azure AI.

* **[Web UI](https://github.com/Azure/gpt-rag-ui)** – Provides the user interface, supports streaming responses, and allows easy customization.

* **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)** – Handles data chunking and indexing to optimize retrieval for the RAG workflow.

* **[MCP](https://github.com/Azure/gpt-rag-mcp)** – The Model Context Protocol server to support standard and custom business logic tool hosting.

## Prerequisites

<details markdown="block">
<summary>Expand to view prerequisites</summary>

To deploy this template, the user or service principal requires the following permissions on the target Resource Group:

* An Azure subscription.
* An Azure user with **Contributor** and **User Access Admin** permissions on the target resource group.

In addition, the machine or environment used for deployment should have:

- Azure Developer CLI: [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- PowerShell 7+ (Windows only): [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package)
- Git: [Download Git](https://git-scm.com/downloads)
- Python 3.12: [Download Python](https://www.python.org/downloads/release/python-3120/)
- An Azure AI Services resource created or agreement to Responsible AI terms in the portal

</details>

## How to Deploy the Infrastructure

Choose your preferred deployment method based on project requirements and environment constraints.

> [!TIP]
> You can change parameter values in `main.parameters.json` or set them with `azd env set` before running `azd provision`. This applies only to parameters that support environment variable substitution.

### 1. Basic Architecture (No Network Isolation) ⚙️
Quick setup for demos without network isolation.

```shell
azd init -t azure/gpt-rag
azd provision
````

[![Watch the basic architecture deployment video](https://img.youtube.com/vi/nZMDtaDQuP4/0.jpg)](https://www.youtube.com/embed/nZMDtaDQuP4?autoplay=1)

### 2. Zero-Trust Architecture (ZTA) 🔒

For deployments that **require network isolation**.

#### 1) Before Provisioning

Enable network isolation in your environment:

```shell
azd env set NETWORK_ISOLATION true
```

#### 2) Provision the Infrastructure

```shell
azd provision
```

#### 3) Post-Provision Steps *(VNet access required)*

> [!NOTE]
> The Bicep template provisions a **Jumpbox VM** by default. You can connect to it to perform the post-provision steps, deploy services, and run tests.

**Option A – Using the deployed Jumpbox VM**

1. Connect via **Azure Bastion**.
2. Open a terminal in the VM and run:

   ```shell
   cd C:\github.com\gpt-rag
   .\scripts\postProvision.ps1
   ```

**Option B – From your local machine (must have VNet access)**

1. From the `gpt-rag` directory, run:

   ```shell
   .\scripts\postProvision.ps1
   ```

   or (Bash)

   ```shell
   .\scripts\postProvision.sh
   ```

2. If you have re-initialized or cloned the repo again, refresh your `azd` environment so it points to the **existing** deployment:

   ```shell
   azd init -t azure/gpt-rag
   azd env refresh
   ```

3. When prompted, select the **same Subscription, Resource Group, and Location** as the original provisioning so `azd` correctly links to your environment.

### 3. Step-by-Step Manual Setup: Zero-Trust Architecture 🛠️

*Coming soon.*

## How to Deploy GPT-RAG Services

Once the GPT-RAG infrastructure is provisioned, you can deploy the services.

To deploy **all services at once**, navigate to the `gpt-rag` directory (with azd environment configured) and run:

```shell
azd deploy
```

This command deploys each service in sequence.

If you prefer to **deploy a single service**—for example, when updating only that service—navigate to the corresponding service repository and follow the instructions in its **"How to Deploy"** section.

## Permissions

**AI Foundry Role and AI Search Assignments**

| Resource                              | Role                                | Assignee           | Description                                                           |
| :------------------------------------ | :---------------------------------- | :----------------- | :-------------------------------------------------------------------- |
| GenAI App Search Service              | Search Index Data Reader            | AI Foundry Project | Read index data                                                       |
| GenAI App Search Service              | Search Service Contributor          | AI Foundry Project | Create AI search connection                                           |
| GenAI App Storage Account             | Storage Blob Data Reader            | AI Foundry Account | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Reader            | Search Service     | Read blob data for search integration                                 |
| AI Foundry Storage Account            | Storage Blob Data Contributor       | AI Foundry Project | Enable agent to store/retrieve blob artifacts in customer storage     |
| AI Foundry Storage Account Containers | Storage Blob Data Owner (workspace) | AI Foundry Project | Scoped owner access to workspace containers for session-specific data |
| AI Foundry Cosmos DB Account          | Cosmos DB Operator                  | AI Foundry Project | Control-plane operations for enterprise memory database (threads)     |
| AI Foundry Cosmos DB Containers       | Cosmos DB Built-in Data Contributor | AI Foundry Project | Read/write conversation threads within enterprise memory containers   |
| AI Foundry Search Service             | Search Service Contributor          | AI Foundry Project | Create/update indexes for vector search workflows                     |
| AI Foundry Search Service             | Search Index Data Contributor       | AI Foundry Project | Read/write index data for embedding-based queries                     |

**Container App Role Assignments**

| Resource                      | Role                                | Assignee                   | Description                          |
| :---------------------------- | :---------------------------------- | :------------------------- | :----------------------------------- |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: orchestrator | Read configuration data              |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: frontend     | Read configuration data              |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: dataingest   | Read configuration data              |
| GenAI App Configuration Store | App Configuration Data Reader       | ContainerApp: mcp          | Read configuration data              |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: mcp          | Pull container images                |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: orchestrator | Pull container images                |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: frontend     | Pull container images                |
| GenAI App Container Registry  | AcrPull                             | ContainerApp: dataingest   | Pull container images                |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: orchestrator | Read secrets                         |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: frontend     | Read secrets                         |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: dataingest   | Read secrets                         |
| GenAI App Key Vault           | Key Vault Secrets User              | ContainerApp: mcp          | Read secrets                         |
| GenAI App Search Service      | Search Index Data Reader            | ContainerApp: orchestrator | Read index data                      |
| GenAI App Search Service      | Search Index Data Contributor       | ContainerApp: dataingest   | Read/write index data                |
| GenAI App Search Service      | Search Index Data Contributor       | ContainerApp: mcp          | Read/write index data                |
| GenAI App Storage Account     | Storage Blob Data Reader            | ContainerApp: orchestrator | Read blob data                       |
| GenAI App Storage Account     | Storage Blob Data Reader            | ContainerApp: frontend     | Read blob data                       |
| GenAI App Storage Account     | Storage Blob Data Contributor       | ContainerApp: dataingest   | Read/write blob data                 |
| GenAI App Storage Account     | Storage Blob Data Contributor       | ContainerApp: mcp          | Read/write blob data                 |
| GenAI App Storage Account     | Storage Queue Data Contributor      | ContainerApp: mcp          | Read/write storage queue data        |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data            |
| AI Foundry Account            | Cognitive Services User             | ContainerApp: orchestrator | Access Cognitive Services operations |
| AI Foundry Account            | Cognitive Services User             | ContainerApp: dataingest   | Access Cognitive Services operations |
| AI Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: orchestrator | Use OpenAI APIs                      |
| AI Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: dataingest   | Use OpenAI APIs                      |
| AI Foundry Account            | Cognitive Services User             | ContainerApp: mcp          | Access Cognitive Services            |
| AI Foundry Account            | Cognitive Services OpenAI User      | ContainerApp: mcp          | Use OpenAI APIs                      |

**Executor Role Assignments**

| Resource                      | Role                                | Assignee | Description                                 |
| :---------------------------- | :---------------------------------- | :------- | :------------------------------------------ |
| GenAI App Configuration Store | App Configuration Data Owner        | Executor | Full control over configuration settings    |
| GenAI App Container Registry  | AcrPush                             | Executor | Push container images                       |
| GenAI App Key Vault           | Key Vault Contributor               | Executor | Manage Key Vault settings                   |
| GenAI App Key Vault           | Key Vault Secrets Officer           | Executor | Create Key Vault secrets                    |
| GenAI App Search Service      | Search Service Contributor          | Executor | Create/update search service elements       |
| GenAI App Search Service      | Search Index Data Contributor       | Executor | Read/write search index data                |
| GenAI App Storage Account     | Storage Blob Data Contributor       | Executor | Read/write blob data                        |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor | Executor | Read/write Cosmos DB data                   |
| AI Foundry Project            | Azure AI Project Manager            | Executor | Manage AI Foundry projects and assign roles |

**Jumpbox VM Role Assignments**


| Resource                      | Role                                                       | Assignee   | Description                                           |
| ----------------------------- | ---------------------------------------------------------- | ---------- | ----------------------------------------------------- |
| GenAI App Container Apps      | Container Apps Contributor                                 | Jumpbox VM | Full control over Container Apps (deploy/manage apps) |
| Azure Managed Identity        | Managed Identity Operator                                  | Jumpbox VM | Assign and manage user-assigned managed identities    |
| GenAI App Container Registry  | Container Registry Repository Writer                       | Jumpbox VM | Write to specific repositories                        |
| GenAI App Container Registry  | Container Registry Tasks Contributor                       | Jumpbox VM | Manage ACR tasks                                      |
| GenAI App Container Registry  | Container Registry Data Access Configuration Administrator | Jumpbox VM | Manage data access configuration for ACR              |
| GenAI App Container Registry  | AcrPush                                                    | Jumpbox VM | Push container images                                 |
| GenAI App Configuration Store | App Configuration Data Owner                               | Jumpbox VM | Full control over configuration settings              |
| GenAI App Key Vault           | Key Vault Contributor                                      | Jumpbox VM | Manage Key Vault settings                             |
| GenAI App Key Vault           | Key Vault Secrets Officer                                  | Jumpbox VM | Create Key Vault secrets                              |
| GenAI App Search Service      | Search Service Contributor                                 | Jumpbox VM | Create/update search service elements                 |
| GenAI App Search Service      | Search Index Data Contributor                              | Jumpbox VM | Read/write search index data                          |
| GenAI App Storage Account     | Storage Blob Data Contributor                              | Jumpbox VM | Read/write blob data                                  |
| AI Foundry Account            | Azure AI Project Manager                                   | Jumpbox VM | Manage AI Foundry projects and assign roles           |
| AI Foundry Account            | Cognitive Services Contributor                             | Jumpbox VM | Manage Cognitive Services resources                   |
| GenAI App Cosmos DB           | Cosmos DB Built-in Data Contributor                        | Jumpbox VM | Read/write Cosmos DB data                             |

## Previous Releases

To deploy earlier releases, such as **[v1.0.0](https://github.com/Azure/gpt-rag/tree/v1.0.0)**, run:

```shell
azd init -t azure/gpt-rag -b v1.0.0
azd provision
```
## Contributing

We appreciate contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on the Contributor License Agreement (CLA), code of conduct, and submitting pull requests.

## Trademarks

This project may contain trademarks or logos. Authorized use of Microsoft trademarks or logos must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Modified versions must not imply sponsorship or cause confusion. Third-party trademarks are subject to their own policies.
