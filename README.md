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

This repository provides infrastructure deployment templates to establish a landing zone for hosting GPT-RAG application services. It sets up the core Azure resources and patterns required to deploy a modular RAG-based solution, ensuring security, scalability, and operational readiness.

The **Retrieval-Augmented Generation (RAG) pattern** enables organizations to combine large language models with custom data: LLMs generate responses grounded in retrieved data instead of relying solely on pre-trained knowledge. By separating data retrieval from model fine-tuning, RAG allows periodic data updates without retraining, streamlining integration of LLM capabilities into enterprise applications.

This solution accelerator offers a robust architecture tailored for enterprise-grade deployment of the RAG pattern. It enforces zero-trust security, Responsible AI principles, high availability, and auditability. It is ideal for teams moving from proofs-of-concept and experimentation to full-scale production or MVPs.

### Architecture

![Zero Trust Architecture](media/architecture-zero-trust.png)

## Prerequisites

To deploy this template, the user or service principal requires the following permissions on the target Resource Group:

- Contributor
- Role-Based Access Administrator

In addition, the machine or environment used for deployment should have:

- Azure Developer CLI: [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- PowerShell 7+ (Windows only): [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package)
- Git: [Download Git](https://git-scm.com/downloads)
- Python 3.12: [Download Python](https://www.python.org/downloads/release/python-3120/)
- An Azure AI Services resource created or agreement to Responsible AI terms in the portal

## How to deploy the infrastructure

```shell
azd init -t azure/gpt-rag -b feature/vnext-architecture
azd provision
````

> [!TIP]
> You can update `main.parameters.json` to customize settings before running `azd provision`.

## Demo Video

[![Watch the demo](https://img.youtube.com/vi/nZMDtaDQuP4/0.jpg)](https://www.youtube.com/embed/nZMDtaDQuP4?autoplay=1)

## GPT-RAG Services

After infrastructure is in place, deploy the GPT-RAG services from their respective repositories:

* **[Orchestrator](https://github.com/Azure/gpt-rag-orchestrator/tree/feature/vnext-architecture)** – Manages information retrieval and response generation with an agent-based approach using Semantic Kernel and Azure AI Foundry Agent Service.

* **[App Front-End](https://github.com/Azure/gpt-rag-orchestrator/tree/feature/vnext-architecture)** – Provides the user interface, supports streaming responses, and allows easy customization; used exclusively with the agentic orchestrator. Follows the Backend for Frontend pattern.

* **[Data Ingestion](https://github.com/Azure/gpt-rag-orchestrator/tree/feature/vnext-architecture)** – Handles data chunking and indexing to optimize retrieval for the RAG workflow.

## Permissions

| Resource                              | Role                                | Assignee                   | Description                                                           |
| :------------------------------------ | :---------------------------------- | :------------------------- | :-------------------------------------------------------------------- |
| GenAI App Configuration Settings      | App Configuration Data Owner        | Executor                   | Full control over configuration settings                              |
| GenAI App Configuration Settings      | App Configuration Data Reader       | ContainerApp: orchestrator | Read configuration data                                               |
| GenAI App Configuration Settings      | App Configuration Data Reader       | ContainerApp: frontend     | Read configuration data                                               |
| GenAI App Configuration Settings      | App Configuration Data Reader       | ContainerApp: dataingest   | Read configuration data                                               |
| GenAI App Container Registry          | AcrPush                             | Executor                   | Push container images                                                 |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: orchestrator | Pull container images                                                 |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: frontend     | Pull container images                                                 |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: dataingest   | Pull container images                                                 |
| GenAI App Key Vault                   | Key Vault Contributor               | Executor                   | Manage Key Vault settings                                             |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: orchestrator | Read secrets                                                          |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: frontend     | Read secrets                                                          |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: dataingest   | Read secrets                                                          |
| GenAI App Search Service              | Search Service Contributor          | Executor                   | Create/update search service elements                                 |
| GenAI App Search Service              | Search Index Data Contributor       | Executor                   | Read/write search index data                                          |
| GenAI App Search Service              | Search Index Data Reader            | AI Foundry Account         | Read index data                                                       |
| GenAI App Search Service              | Search Index Data Reader            | ContainerApp: orchestrator | Read index data                                                       |
| GenAI App Search Service              | Search Index Data Contributor       | ContainerApp: dataingest   | Read/write index data                                                 |
| GenAI App Storage Account             | Storage Blob Data Contributor       | Executor                   | Read/write blob data                                                  |
| GenAI App Storage Account             | Storage Blob Data Reader            | AI Foundry Account         | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Reader            | ContainerApp: orchestrator | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Reader            | ContainerApp: frontend     | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Contributor       | ContainerApp: dataingest   | Read/write blob data                                                  |
| GenAI App Storage Account             | Storage Blob Data Reader            | Search Service             | Read blob data for search integration                                 |
| GenAI App Cosmos DB                   | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data                                             |
| AI Foundry Project                    | Azure AI Project Manager            | Executor                   | Manage AI Foundry projects and assign roles                           |
| AI Foundry Storage Account            | Storage Blob Data Contributor       | AI Foundry Project         | Enable agent to store/retrieve blob artifacts in customer storage     |
| AI Foundry Storage Account Containers | Storage Blob Data Owner (workspace) | AI Foundry Project         | Scoped owner access to workspace containers for session-specific data |
| AI Foundry Cosmos DB Account          | Cosmos DB Operator                  | AI Foundry Project         | Control-plane operations for enterprise memory database (threads)     |
| AI Foundry Cosmos DB Containers       | Cosmos DB Built-in Data Contributor | AI Foundry Project         | Read/write conversation threads within enterprise memory containers   |
| AI Foundry Search Service             | Search Service Contributor          | AI Foundry Project         | Create/update indexes for vector search workflows                     |
| AI Foundry Search Service             | Search Index Data Contributor       | AI Foundry Project         | Read/write index data for embedding-based queries                     |
| AI Foundry Account                    | Cognitive Services User             | ContainerApp: orchestrator | Access Cognitive Services operations                                  |
| AI Foundry Account                    | Cognitive Services User             | ContainerApp: dataingest   | Access Cognitive Services operations                                  |
| AI Foundry Account                    | Cognitive Services OpenAI User      | ContainerApp: orchestrator | Use OpenAI APIs                                                       |
| AI Foundry Account                    | Cognitive Services OpenAI User      | ContainerApp: dataingest   | Use OpenAI APIs                                                       |

## Original Release

This repo has undergone a major architectural update. For the original version, see [v1.0.0](https://github.com/Azure/gpt-rag/tree/v1.0.0).

## Contributing

We appreciate contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on the Contributor License Agreement (CLA), code of conduct, and submitting pull requests.

## Trademarks

This project may contain trademarks or logos. Authorized use of Microsoft trademarks or logos must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Modified versions must not imply sponsorship or cause confusion. Third-party trademarks are subject to their own policies.