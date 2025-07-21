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

The **RAG pattern** enables businesses to use the reasoning capabilities of LLMs, using their existing models to process and generate responses based on new data. RAG facilitates periodic data updates without the need for fine-tuning, thereby streamlining the integration of LLMs into businesses. 

The **Enterprise RAG** Solution Accelerator (GPT-RAG) offers a robust architecture tailored for enterprise-grade deployment of the RAG pattern. It ensures grounded responses and is built on Zero-trust security and Responsible AI, ensuring availability, scalability, and auditability. Ideal for organizations transitioning from exploration and PoC stages to full-scale production and MVPs.

✨ See our [User & Admin Guide](docs/GUIDE.md) for complete setup and usage details.

## Application Components

GPT-RAG follows a modular approach, consisting of three components, each with a specific function.

* **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)** - Optimizes data chunking and indexing for the RAG retrieval step.

* **Orchestrator** - Manages information retrieval and response generation. Choose between **[Functional](https://github.com/Azure/gpt-rag-orchestrator)** using Semantic Kernel functions or **[Agentic](https://github.com/Azure/gpt-rag-agentic)** powered by AutoGen. Refer to the deployment instructions to switch.

* **App Front-End** – Provides the user interface. Choose between the **[React Front-End](https://github.com/Azure/gpt-rag-frontend)**, the original interface built with React, or the **[Chainlit Front-End](https://github.com/Azure/gpt-rag-ui)**, supporting streaming and easy customization, used exclusively with the agentic orchestrator. Both follow the [Backend for Front-End](https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends) pattern.


<!-- * [Teams-BOT](https://github.com/Azure/gpt-rag-bot) Constructed using Azure BOT Services, this platform enables users to engage with the Orchestrator seamlessly through the Microsoft Teams interface. -->

<!-- 
Removing temporarily while not finished
## GPT-RAG Integration HUB
* [SQL Integration](https://github.com/Azure/gpt-rag-int-sql) Connect the GPT-RAG Infrastructure to SQL using NL2SQL. -->

## Concepts

If you want to learn more about the RAG Pattern and GPT-RAG architecture.

* [RAG Pattern: What and Why?](docs/RAG_CONCEPTS.md)

* [Solution Architecture Overview](docs/ARCHITECTURE.md)

<!-- ![Architecture Overview](media/GPT-RAG-ZeroTrust.png) -->

*  [Enterprise RAG +Prompt Engineering+Finetuning+Train (Video in Spanish)](https://www.youtube.com/watch?v=ICsf4yirieA)

<!-- ## Administration Guide

For detailed instructions on managing and configuring the system, please refer to the [Administration Guide](docs/ADMINISTRATION_GUIDE.md) 📖. -->

<!-- <a href="https://www.youtube.com/watch?v=ICsf4yirieA"><img src="https://img.youtube.com/vi/ICsf4yirieA/0.jpg" alt="Alt text" width="480"/></a> -->


## Setup Guide

1) **Basic Architecture Deployment:** *for quick demos with no network isolation*⚙️

Learn how to **quickly set up** the basic architecture for scenarios without network isolation. [Click the link to proceed](#basic-architecture-deployment).

2) **Standard Zero-Trust Architecture Deployment:** *fastest Zero-Trust deployment option*⚡

Deploy the solution accelerator using the standard zero-trust architecture with pre-configured solution settings. No customization needed. [Click the link to proceed](#zero-trust-architecture-deployment).

3) **Custom Zero-Trust Architecture Setup:** *most used* ⭐

Explore options for customizing the deployment of the solution accelerator with a zero-trust architecture, adjusting solution settings to your needs. [Click the link to proceed](docs/AUTOMATED_INSTALLATION.md).

4) **Step-by-Step Manual Setup: Zero-Trust Architecture:** *hands-on approach* 🛠️**

For those who prefer complete control, follow this detailed guide to manually set up the solution accelerator with a zero-trust architecture. [Click the link to proceed](docs/MANUAL_INSTALLATION.md).


## Getting Started

This guide will walk you through the deployment process of Enterprise RAG. There are two deployment options available, **Basic Architecture** and **Zero Trust Architecture**. Before beginning the deployment, please ensure you have prepared all the necessary tools and services as outlined in the **Pre-requisites** section.

**Pre-requisites**

- Azure Developer CLI: [Download azd for Windows](https://azdrelease.azureedge.net/azd/standalone/release/1.5.0/azd-windows-amd64.msi), [Other OS's](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd).
 - Powershell 7+ (Windows only): [Powershell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package).
 - Microsoft Visual Studio Build Tools (Windows only: [Download Build Tools](https://visualstudio.microsoft.com/downloads/?q=build+tools#build-tools-for-visual-studio-2022).
 - Git: [Download Git](https://git-scm.com/downloads).
 - Node.js 16+ [windows/mac](https://nodejs.dev/en/download/)  [linux/wsl](https://nodejs.dev/en/download/package-manager/)
 - Python 3.11: [Download Python](https://www.python.org/downloads/release/python-3118/).
 - Initiate an [Azure AI services creation](https://portal.azure.com/#create/Microsoft.CognitiveServicesAllInOne) and agree to the Responsible AI terms **

<!-- [AZ Module](https://learn.microsoft.com/en-us/powershell/azure/what-is-azure-powershell?view=azps-11.6.0#the-az-powershell-module) -->

** If you have not created an Azure AI service resource in the subscription before

### Basic Architecture Deployment

For quick demonstrations or proof-of-concept projects without network isolation requirements, you can deploy the accelerator using its basic architecture.
![Basic Architecture](media/architecture-GPT-RAG-Basic.png)


### Architecture

![Zero Trust Architecture](media/architecture-zero-trust.png)

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

## How to deploy the infrastructure

```shell
azd init -t azure/gpt-rag 
azd provision
````

> [!TIP]
> You can update `main.parameters.json` to customize settings before running `azd provision`.

## Demo Video

[![Watch the demo](https://img.youtube.com/vi/nZMDtaDQuP4/0.jpg)](https://www.youtube.com/embed/nZMDtaDQuP4?autoplay=1)

## GPT-RAG Services

After infrastructure is in place, deploy the GPT-RAG services from their respective repositories:

* **[Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)** – Manages information retrieval and response generation with an agent-based approach using Semantic Kernel and Azure AI Foundry Agent Service.

* **[Web UI](https://github.com/Azure/gpt-rag-ui)** – Provides the user interface, supports streaming responses, and allows easy customization.

* **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)** – Handles data chunking and indexing to optimize retrieval for the RAG workflow.

## Permissions

| Resource                              | Role                                | Assignee                   | Description                                                           |
| :------------------------------------ | :---------------------------------- | :------------------------- | :-------------------------------------------------------------------- |
| GenAI App Configuration Store         | App Configuration Data Owner        | Executor                   | Full control over configuration settings                              |
| GenAI App Configuration Store         | App Configuration Data Reader       | ContainerApp: orchestrator | Read configuration data                                               |
| GenAI App Configuration Store         | App Configuration Data Reader       | ContainerApp: frontend     | Read configuration data                                               |
| GenAI App Configuration Store         | App Configuration Data Reader       | ContainerApp: dataingest   | Read configuration data                                               |
| GenAI App Configuration Store         | App Configuration Data Reader        | ContainerApp: mcp     | Read configuration data              |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: mcp     | Pull container images                |
| GenAI App Container Registry          | AcrPush                             | Executor                   | Push container images                                                 |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: orchestrator | Pull container images                                                 |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: frontend     | Pull container images                                                 |
| GenAI App Container Registry          | AcrPull                             | ContainerApp: dataingest   | Pull container images                                                 |
| GenAI App Key Vault                   | Key Vault Contributor               | Executor                   | Manage Key Vault settings                                             |
| GenAI App Key Vault                   | Key Vault Secrets Officer           | Executor                   | Create Key Vault Secrets                                              |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: orchestrator | Read secrets                                                          |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: frontend     | Read secrets                                                          |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: dataingest   | Read secrets                                                          |
| GenAI App Key Vault                   | Key Vault Secrets User              | ContainerApp: mcp     | Read secrets                         |
| GenAI App Search Service              | Search Service Contributor          | Executor                   | Create/update search service elements                                 |
| GenAI App Search Service              | Search Index Data Contributor       | Executor                   | Read/write search index data                                          |
| GenAI App Search Service              | Search Index Data Reader            | AI Foundry Project         | Read index data                                                       |
| GenAI App Search Service              | Search Service Contributor          | AI Foundry Project         | Create AI search connection                                           |
| GenAI App Search Service              | Search Index Data Reader            | ContainerApp: orchestrator | Read index data                                                       |
| GenAI App Search Service              | Search Index Data Contributor       | ContainerApp: dataingest   | Read/write index data                                                 |
| GenAI App Search Service              | Search Index Data Contributor       | ContainerApp: mcp     | Read/write index data                |
| GenAI App Storage Account             | Storage Blob Data Contributor       | Executor                   | Read/write blob data                                                  |
| GenAI App Storage Account             | Storage Blob Data Reader            | AI Foundry Account         | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Reader            | ContainerApp: orchestrator | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Reader            | ContainerApp: frontend     | Read blob data                                                        |
| GenAI App Storage Account             | Storage Blob Data Contributor       | ContainerApp: dataingest   | Read/write blob data                                                  |
| GenAI App Storage Account             | Storage Blob Data Reader            | Search Service             | Read blob data for search integration                                 |
| GenAI App Storage Account             | Storage Blob Data Contributor       | ContainerApp: mcp     | Read/write blob data                 |
| GenAI App Storage Account             | Storage Queue Data Contributor      | ContainerApp: mcp     | Read/write storage queue data        |
| GenAI App Cosmos DB                   | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data                                             |
| GenAI App Cosmos DB                   | Cosmos DB Built-in Data Contributor | Executor                   | Read/write Cosmos DB data                                             |
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
| AI Foundry Account                    | Cognitive Services User             | ContainerApp: mcp     | Access Cognitive Services            |
| AI Foundry Account                    | Cognitive Services OpenAI User      | ContainerApp: mcp     | Use OpenAI APIs                      |

## Original Release

This repo has undergone a major architectural update. For the original version, see [v1.0.0](https://github.com/Azure/gpt-rag/tree/v1.0.0).

To deploy v1.0.0 run the following commands:

```shell
azd init -t azure/gpt-rag -b v1.0.0
azd provision
````

## Contributing

We appreciate contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on the Contributor License Agreement (CLA), code of conduct, and submitting pull requests.

## Trademarks

This project may contain trademarks or logos. Authorized use of Microsoft trademarks or logos must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Modified versions must not imply sponsorship or cause confusion. Third-party trademarks are subject to their own policies.
