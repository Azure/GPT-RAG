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

## Permissions

| Resource                   | Role                                | Assignee                   | Description                                                                                         |
|:---------------------------|:------------------------------------|:---------------------------|:----------------------------------------------------------------------------------------------------|
| App Configuration Settings | App Configuration Data Owner        | Executor                   | Full control over App Configuration                                                                  |
| Azure Container Registry   | AcrPush                             | Executor                   | Push container images                                                                                |
| Key Vault                  | Key Vault Contributor               | Executor                   | Manage key vault settings                                                                            |
| Search Service             | Search Service Contributor          | Executor                   | Create search service elements                                                                       |
| Search Service             | Search Index Data Contributor       | Executor                   | Read and write search index data                                                                     |
| Storage Account            | Storage Blob Data Contributor       | Executor                   | Read and write blob data                                                                             |
| AI Foundry Search Service  | Search Service Contributor          | AI Foundry Project         | Manage AI search service                                                                             |
| AI Foundry Search Service  | Search Index Data Contributor       | AI Foundry Project         | Read/write AI search index data                                                                      |
| AI Foundry Blob Storage    | Storage Blob Data Contributor       | AI Foundry Project         | File and intermediate data storage (chunks, embeddings)                                              |
| AI Foundry Storage         | Storage Blob Data Owner             | AI Foundry Project         | File and intermediate data storage (chunks, embeddings)                                              |
| AI Foundry Cosmos DB       | Cosmos DB Operator                  | AI Foundry Project         | Thread storage: persist conversation messages & transactions                                         |
| AI Foundry Cosmos DB       | Cosmos DB Built-in Data Contributor | AI Foundry Project         | Thread storage: persist conversation messages & transactions                                         |
| Search Service             | Search Index Data Reader            | AI Foundry Project         | Read search index data                                                                               |
| Storage Account            | Storage Blob Data Reader            | AI Foundry Project         | Read blob data                                                                                       |
| Key Vault                  | Key Vault Crypto User               | AI Foundry Project         | Perform cryptographic ops only if CMK used                                                           |
| Key Vault                  | Key Vault Secrets User              | AI Foundry Project         | Read secrets for encryption only if CMK used                                                         |
| App Configuration Settings | App Configuration Data Reader       | ContainerApp: orchestrator | Read App Configuration data                                                                          |
| App Configuration Settings | App Configuration Data Reader       | ContainerApp: frontend     | Read App Configuration data                                                                          |
| App Configuration Settings | App Configuration Data Reader       | ContainerApp: dataingest   | Read App Configuration data                                                                          |
| AI Foundry Account         | Cognitive Services User             | ContainerApp: orchestrator | Access Cognitive Services operations                                                                 |
| AI Foundry Account         | Cognitive Services User             | ContainerApp: dataingest   | Access Cognitive Services operations                                                                 |
| AI Foundry Account         | Cognitive Services OpenAI User      | ContainerApp: orchestrator | Use OpenAI APIs                                                                                      |
| AI Foundry Account         | Cognitive Services OpenAI User      | ContainerApp: dataingest   | Use OpenAI APIs                                                                                      |
| Azure Container Registry   | AcrPull                             | ContainerApp: orchestrator | Pull container images                                                                                |
| Azure Container Registry   | AcrPull                             | ContainerApp: frontend     | Pull container images                                                                                |
| Azure Container Registry   | AcrPull                             | ContainerApp: dataingest   | Pull container images                                                                                |
| Cosmos DB                  | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data                                                                            |
| Key Vault                  | Key Vault Secrets User              | ContainerApp: orchestrator | Read vault secrets                                                                                   |
| Key Vault                  | Key Vault Secrets User              | ContainerApp: frontend     | Read vault secrets                                                                                   |
| Key Vault                  | Key Vault Secrets User              | ContainerApp: dataingest   | Read vault secrets                                                                                   |
| Search Service             | Search Index Data Reader            | ContainerApp: orchestrator | Read search index data                                                                               |
| Search Service             | Search Index Data Contributor       | ContainerApp: dataingest   | Read and write search index data                                                                     |
| Storage Account            | Storage Blob Data Contributor       | ContainerApp: dataingest   | Read and write blob data                                                                             |
| Storage Account            | Storage Blob Data Reader            | ContainerApp: orchestrator | Read blob data                                                                                       |
| Storage Account            | Storage Blob Data Reader            | ContainerApp: frontend     | Read blob data                                                                                       |
| Storage Account            | Storage Blob Data Reader            | Search Service             | Read blob data for search integration                                                                 |


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