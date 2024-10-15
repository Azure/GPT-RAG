# Bring Your Own Resource

Sometimes, you might prefer to utilize existing resources in your subscription rather than creating new ones. Our Bicep template supports this flexibility. On this page, I will explain how you can achieve this, followed by specific instructions for each type of resource where applicable.

## General Instructions

Let's delve deeper into the general process of integrating existing resources into our project. To provide a clear and practical example, I will guide you through the process of reusing an existing **AI Services** resource. 

**Pre-requisites**:

- AI Services resource created in the same subscription you will deploy Enterprise RAG.

**General Instruction Steps**:

1. Identify the resources you will reuse. For each resource to be reused, you need to set the correspondent environment variables. 

The table below outlines the environment variables associated with each resource type for customization:

| Resource Type                     | Environment Variables                                                                                   |
|-----------------------------------|---------------------------------------------------------------------------------------------------------|
| AOAI                              | `AOAI_REUSE`, `AOAI_RESOURCE_GROUP_NAME`, `AOAI_NAME`                                                   |
| Application Insights              | `APP_INSIGHTS_REUSE`, `APP_INSIGHTS_RESOURCE_GROUP_NAME`, `APP_INSIGHTS_NAME`                           |
| App Service Plan                  | `APP_SERVICE_PLAN_REUSE`, `APP_SERVICE_PLAN_RESOURCE_GROUP_NAME`, `APP_SERVICE_PLAN_NAME`                  |
| AI Search                         | `AI_SEARCH_REUSE`, `AI_SEARCH_RESOURCE_GROUP_NAME`, `AI_SEARCH_NAME`                                     |
| AI Services                       | `AI_SERVICES_REUSE`, `AI_SERVICES_RESOURCE_GROUP_NAME`, `AI_SERVICES_NAME`                               |
| Cosmos DB                         | `COSMOS_DB_REUSE`, `COSMOS_DB_RESOURCE_GROUP_NAME`, `COSMOS_DB_ACCOUNT_NAME`, `COSMOS_DB_DATABASE_NAME`  |
| Key Vault                         | `KEY_VAULT_REUSE`, `KEY_VAULT_RESOURCE_GROUP_NAME`, `KEY_VAULT_NAME`                                     |
| Storage                           | `STORAGE_REUSE`, `STORAGE_RESOURCE_GROUP_NAME`, `STORAGE_NAME`                                           |
| Virtual Network (VNet)            | `VNET_REUSE`, `VNET_RESOURCE_GROUP_NAME`, `VNET_NAME`                                                    |
| App Service                       | `APP_SERVICE_REUSE`, `APP_SERVICE_NAME`, `APP_SERVICE_RESOURCE_GROUP_NAME`                               |
| Orchestrator Function App         | `ORCHESTRATOR_FUNCTION_APP_REUSE`, `ORCHESTRATOR_FUNCTION_APP_RESOURCE_GROUP_NAME`, `ORCHESTRATOR_FUNCTION_APP_NAME` |
| Orchestrator Function App Storage | `ORCHESTRATOR_FUNCTION_APP_STORAGE_REUSE`, `ORCHESTRATOR_FUNCTION_APP_STORAGE_NAME`, `ORCHESTRATOR_FUNCTION_APP_STORAGE_RESOURCE_GROUP_NAME` |
| Data Ingestion Function App       | `INGESTION_FUNCTION_APP_REUSE`, `DATA_INGESTION_FUNCTION_APP_RESOURCE_GROUP_NAME`, `DATA_INGESTION_FUNCTION_APP_NAME` |
| Data Ingestion Function App Storage | `DATA_INGESTION_FUNCTION_APP_STORAGE_REUSE`, `DATA_INGESTION_FUNCTION_APP_STORAGE_NAME`, `DATA_INGESTION_FUNCTION_APP_STORAGE_RESOURCE_GROUP_NAME` |

This table serves as a guide for configuring environment variables to reuse existing resources in your deployment.

For AI Services, we have these three variables:

`AI_SERVICES_REUSE`, `AI_SERVICES_RESOURCE_GROUP_NAME`, `AI_SERVICES_NAME`.

2. Once you have identified the variables, set the reuse variable to true and provide the existing resource information. For example:

```sh
azd env set AI_SERVICES_REUSE true
azd env set AI_SERVICES_RESOURCE_GROUP_NAME rg-gptragz910
azd env set AI_SERVICES_NAME ai0-fa6zfs7v4izv6
```

In this example, I am reusing the AI Service `ai0-fa6zfs7v4izv6` in the resource group `rg-gptragz910`.

3. Now, simply run `azd up` or `azd provision` to deploy the service.

> Notes
> - This procedure should be completed before you run the `azd up` or `azd provision` command.
> - The steps described here are universally applicable across all resources. However, note that **some resource types may have unique setup needs**. After reviewing these general instructions, please consult the [Resource-Specific Configuration Guidelines](#resource-specific-configuration-guidelines) for any additional requirements.

## Resource-Specific Configuration Guidelines

### App Service Plan

App Service Plan kind must be Linux.

### Application Service Environment

If you want to use an existing [Application Service Environment (ASE)](https://learn.microsoft.com/en-us/azure/app-service/environment/overview) to run the function apps and the front-end web app, please note that the installation must be performed manually, as Bicep does not support this scenario. You should follow the manual procedure, ensuring that the App Service Plan within your ASE is Linux-based.

### Azure AI Search

In addition to specifying the AI Search service name and resource group as mentioned in the [General Instructions](#general-instructions), it's important to pay attention to the following points:

- The AI Search tier must be Standard 2 (S2) or higher if you want to use a zero-trust environment.

- The AI Search must have Managed Identity Enabled.

- If the AI Search will be used for more than one gpt-rag project, to avoid conflicts, you should use different names for the index where retrieval is performed and the container where the documents are obtained. These two items can be configured with the variables `AZURE_STORAGE_CONTAINER_NAME` and `AZURE_SEARCH_INDEX`.

### Azure Function App and App Service

Azure Function Apps, such as Orchestrator and Data Ingestion, should have managed identities enabled, as should the App Service.

You should also add the environment variables accordingly, take a look at the [main.bicep](../infra/main.bicep) to learn about the environment variables used by each function app and the app service.

All function apps and app services should have the following tag: `azd-env-name : your-azd-env-name`.

The Orchestrator function app, Data ingestion function app, and the App Service should have respectively the following tags: `azd-service-name : orchestrator`, `azd-service-name : dataIngest`, and `azd-service-name : frontend`.

### Azure OpenAI

When reusing an Azure OpenAI resource, it's essential to first specify both the OpenAI resource name and its resource group, as outlined in the [General Instructions](#general-instructions).

Additionally, the original resource must have two deployments, one for a GPT model and another for an embeddings model.

Ensure the embeddings model is **text-embedding-ada-002** version 2, with the deployment named **text-embedding-ada-002**.

The default GPT model is **gpt-4o** and the default deployment name is **chat**. If you're using the pre-created service with these default settings, no further modifications are required.

However, if you're using a different name for the GPT, or a different model, you'll need to set the corresponding environment variables as shown in the table below.

| Item                       | Environment Variable Name               |
|----------------------------|-----------------------------------------|
| GPT Deployment Name        | AZURE_CHAT_GPT_DEPLOYMENT_NAME          |
| GPT Model Name             | AZURE_CHAT_GPT_MODEL_NAME               |

To set these environment variables, use the `azd env set` command as described earlier.

For instance, to inform the name of the GPT deployment, you would update the `AZURE_CHAT_GPT_DEPLOYMENT_NAME` variable like this:
`azd env set AZURE_CHAT_GPT_DEPLOYMENT_NAME=my-gpt-deployment-name`

### CosmosDB

In addition to specifying the CosmosDB service name, database name, and resource group as mentioned in the [General Instructions](#general-instructions), it's important to note that the reused Cosmos account should contain the following containers:

- Conversations Container
- Models Container

You can create the containers with default names or use your own names. If using default names, please create them with the following names:

- Conversations Container: 'conversations'
- Models Container: 'models'

If you prefer custom names, use the following variables to define your names with `azd env set` command:

- AZURE_DB_CONVERSATIONS_CONTAINER_NAME
- AZURE_DB_MODELS_CONTAINER_NAME

### Key Vault

If you are reusing a Key Vault, the identity used to execute the AZD commands, whether it's your Entra ID user or a Service Principal, must have an Access Policy that allows `list`, `get`, and `set` operations on the secrets within this Key Vault.

### Virtual Network (Vnet)

Reusing a VNet involves more than simply pre-creating an AI Services VNet and inform its name and resource group as indicated in the [General Instructions Section](#general-instructions).

To reuse a VNet, configure the required subnets and networking resources as detailed below.

#### Subnets

**Before deploying GPT-RAG**, ensure the reused VNet is pre-configured with the 5 required subnets.

The diagram below illustrates the AI Services VNet and its 5 subnets utilized by GPT-RAG:

![Zero Trust Architecture](../media/architecture-GPT-RAG-ZeroTrust.png)

The simplest approach is to create subnets with predefined names: **ai-subnet**, **AzureBastionSubnet**, **app-int-subnet**, **app-services-subnet**, **database-subnet**.

If you prefer different names for the subnets, you can use custom names by specifying them with the corresponding variables. Refer to the table below for the predefined names and their associated variables:

| Subnet Name           | Predefined Name       | Environment Variable Name      |
|-----------------------|-----------------------|--------------------------------|
| AI Subnet             | ai-subnet             | AZURE_AI_SUBNET_NAME           |
| Azure Bastion Subnet  | AzureBastionSubnet    | AZURE_BASTION_SUBNET_NAME      |
| App Int Subnet        | app-int-subnet        | AZURE_APP_INT_SUBNET_NAME      |
| App Services Subnet   | app-services-subnet   | AZURE_APP_SERVICES_SUBNET_NAME |
| Database Subnet       | database-subnet       | AZURE_DATABASE_SUBNET_NAME     |

For instance, if your AI subnet has a custom name, specify it using the `AZURE_AI_SUBNET_NAME` variable.

`azd env set AZURE_AI_SUBNET_NAME my-ai-subnet-name`

#### Networking resources

When reusing an existing VNet, you must configure the network resources according to your standards **before deploying GPT-RAG**.

These resources include Private Endpoints, Private DNS Links, and Search Private Links:


| Service Type        | Related Service                | Description                                                  |
|---------------------|--------------------------------|--------------------------------------------------------------|
| Private Endpoint    | Data Ingestion Function App    | Data Ingestion Function App Private Endpoint                 |
| Private Endpoint    | Azure Storage Account          | Azure Storage Account Private Endpoint                       |
| Private Endpoint    | Azure Cosmos DB                | Azure Cosmos DB Private Endpoint                             |
| Private Endpoint    | Azure Key Vault                | Azure Key Vault Private Endpoint                             |
| Private Endpoint    | Orchestrator Function App      | Orchestrator Function App Private Endpoint                   |
| Private Endpoint    | Frontend Web App               | Frontend Web App Private Endpoint                            |
| Private Endpoint    | Azure AI Services              | Azure AI Services Private Endpoint                           |
| Private Endpoint    | Azure OpenAI                   | Azure OpenAI Private Endpoint                                |
| Private Endpoint    | Azure Search                   | Azure Search Private Endpoint                                |
| DNS Zone            | Azure Storage Account          | DNS Zone for Azure Storage Account                           |
| DNS Zone            | Azure Cosmos DB                | DNS Zone for Azure Cosmos DB                                 |
| DNS Zone            | Azure Key Vault                | DNS Zone for Azure Key Vault                                 |
| DNS Zone            | Azure App Services             | DNS Zone for Azure App Services                              |
| DNS Zone            | Azure AI Services              | DNS Zone for Azure AI Services                               |
| DNS Zone            | Azure OpenAI                   | DNS Zone for Azure OpenAI                                    |
| DNS Zone            | Azure Search                   | DNS Zone for Azure Search                                    |
| Search Private Link | Data Ingestion Function App    | AI Search Private Link for Data Ingestion Function App       |
| Search Private Link | Storage Account                | Azure AI Search Private Link for Storage Account             |