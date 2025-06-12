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
<!-- YAML front-matter schema: https://review.learn.microsoft.com/en-us/help/contribute/samples/process/onboarding?branch=main#supported-metadata-fields-for-readmemd -->

<img src="media/logo.png" alt="Enterprise RAG Logo" width="80" align="left"/>

# GPT-RAG Solution Accelerator

The **RAG pattern** enables businesses to use the reasoning capabilities of LLMs, using their existing models to process and generate responses based on new data. RAG facilitates periodic data updates without the need for fine-tuning, thereby streamlining the integration of LLMs into businesses. 

The GPT-RAG Solution Accelerator offers a robust architecture tailored for enterprise-grade deployment of the RAG pattern. It ensures grounded responses and is built on Zero-trust security and Responsible AI, ensuring availability, scalability, and auditability. Ideal for organizations transitioning from exploration and PoC stages to full-scale production and MVPs.

### Architecture

 ![Zero Trust Architecture](media/architecture-zero-trust.png)

## Pre-requisites

To deploy this template, you need the following permissions on the Resource Group:

- Contributor
- Role-Based Access Administrator

Além disso voce vai precisar mais dessas ferramentas instaladas na maquina que for rodar o deployment.

- Azure Developer CLI: [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd).
- Powershell 7+ (Windows only): [Powershell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package).
- Git: [Download Git](https://git-scm.com/downloads).
- Python 3.12: [Download Python](https://www.python.org/downloads/release/python-3118/).
- Initiate an [Azure AI services creation](https://portal.azure.com/#create/Microsoft.CognitiveServicesAllInOne) and agree to the Responsible AI terms **

## How to deploy the landing zone?

```
azd init
azd provision
```

> [!TIP]
> Você pode atualizar o arquivo main.parameters.json para parametrizar seu deployment antes de rodar azd provision.

## Permissions

| Resource                         | Role                                | Assignee                     | Description                                                              |
|:---------------------------------|:------------------------------------|:-----------------------------|:-------------------------------------------------------------------------|
| GenAI App Configuration Settings | App Configuration Data Owner        | Executor                     | Full control over configuration settings                                 |
| GenAI App Configuration Settings | App Configuration Data Reader       | ContainerApp: orchestrator   | Read configuration data                                                  |
| GenAI App Configuration Settings | App Configuration Data Reader       | ContainerApp: frontend       | Read configuration data                                                  |
| GenAI App Configuration Settings | App Configuration Data Reader       | ContainerApp: dataingest     | Read configuration data                                                  |
| GenAI App Container Registry     | AcrPush                             | Executor                     | Push container images                                                     |
| GenAI App Container Registry     | AcrPull                             | ContainerApp: orchestrator   | Pull container images                                                     |
| GenAI App Container Registry     | AcrPull                             | ContainerApp: frontend       | Pull container images                                                     |
| GenAI App Container Registry     | AcrPull                             | ContainerApp: dataingest     | Pull container images                                                     |
| GenAI App Key Vault              | Key Vault Contributor               | Executor                     | Manage Key Vault settings                                                 |
| GenAI App Key Vault              | Key Vault Secrets User              | ContainerApp: orchestrator   | Read secrets                                                              |
| GenAI App Key Vault              | Key Vault Secrets User              | ContainerApp: frontend       | Read secrets                                                              |
| GenAI App Key Vault              | Key Vault Secrets User              | ContainerApp: dataingest     | Read secrets                                                              |
| GenAI App Search Service         | Search Service Contributor          | Executor                     | Create/update search service elements                                     |
| GenAI App Search Service         | Search Index Data Contributor       | Executor                     | Read/write index data                                                     |
| GenAI App Search Service         | Search Index Data Reader            | AI Foundry Account           | Read index data                                                           |
| GenAI App Search Service         | Search Index Data Reader            | ContainerApp: orchestrator   | Read index data                                                           |
| GenAI App Search Service         | Search Index Data Contributor       | ContainerApp: dataingest     | Read/write index data                                                     |
| GenAI App Storage Account        | Storage Blob Data Contributor       | Executor                     | Read/write blob data                                                      |
| GenAI App Storage Account        | Storage Blob Data Reader            | AI Foundry Account           | Read blob data                                                            |
| GenAI App Storage Account        | Storage Blob Data Reader            | ContainerApp: orchestrator   | Read blob data                                                            |
| GenAI App Storage Account        | Storage Blob Data Reader            | ContainerApp: frontend       | Read blob data                                                            |
| GenAI App Storage Account        | Storage Blob Data Contributor       | ContainerApp: dataingest     | Read/write blob data                                                      |
| GenAI App Storage Account        | Storage Blob Data Reader            | Search Service               | Read blob data for search integration                                     |
| GenAI App Cosmos DB              | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator   | Read/write Cosmos DB data                                                 |
| AI Foundry Project               | Azure AI Project Manager            | Executor                     | Manage AI Foundry projects and assign roles                               |
| AI Foundry Storage Account       | Storage Blob Data Contributor       | AI Foundry Project           | Enable agent to store/retrieve blob artifacts in customer storage         |
| AI Foundry Storage Account Containers | Storage Blob Data Owner (workspace) | AI Foundry Project       | Scoped owner access to workspace containers for session-specific data     |
| AI Foundry Cosmos DB Account     | Cosmos DB Operator                  | AI Foundry Project           | Control-plane operations for enterprise memory database (threads)         |
| AI Foundry Cosmos DB Containers  | Cosmos DB Built-in Data Contributor | AI Foundry Project           | Read/write conversation threads within enterprise memory containers       |
| AI Foundry Search Service        | Search Service Contributor          | AI Foundry Project           | Create/update indexes for vector search workflows                         |
| AI Foundry Search Service        | Search Index Data Contributor       | AI Foundry Project           | Read/write index data for embedding-based queries                         |
| AI Foundry Account               | Cognitive Services User             | ContainerApp: orchestrator   | Access Cognitive Services operations                                      |
| AI Foundry Account               | Cognitive Services User             | ContainerApp: dataingest     | Access Cognitive Services operations                                      |
| AI Foundry Account               | Cognitive Services OpenAI User      | ContainerApp: orchestrator   | Use OpenAI APIs                                                           |
| AI Foundry Account               | Cognitive Services OpenAI User      | ContainerApp: dataingest     | Use OpenAI APIs                                                           |


## Original Release

This repo has undergone a major architectural update. For the original version, see [v1.0.0](https://github.com/Azure/gpt-rag/tree/v1.0.0).

## Contributing

We appreciate your interest in contributing to this project! Please refer to the [CONTRIBUTING.md](./CONTRIBUTING.md) page for detailed guidelines on how to contribute, including information about the Contributor License Agreement (CLA), code of conduct, and the process for submitting pull requests.

Thank you for your support and contributions!

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.