# Bring Your Own Resource

Sometimes, you might prefer to utilize existing resources in your subscription rather than creating new ones. Our Bicep template supports this flexibility. On this page, I will explain how you can achieve this, followed by specific instructions for each type of resource where applicable.

## General Instructions

Let's delve deeper into the general process of integrating existing resources into our project. To provide a clear and practical example, I will guide you through the process of reusing an existing **AI Services** resource. 

**Prerequisites**:

- The resources to be reused must be located in the same subscription where you will deploy Enterprise RAG.
- This prerequisite does not apply for networking resources reusing (e.g., VNet reuse).

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
| Virtual Network (VNet)            | `VNET_REUSE`                                                                                             |
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

- The AI Search must have **Managed Identity** and **Role-based access control** enabled.

- If the AI Search will be used for more than one gpt-rag project, to avoid conflicts, you should use different names for the index where retrieval is performed and the container where the documents are obtained. These two items can be configured with the variables `AZURE_STORAGE_CONTAINER_NAME` and `AZURE_SEARCH_INDEX`.

### Azure Function App and App Service

Azure Function Apps, such as Orchestrator and Data Ingestion, should have managed identities enabled, as should the App Service.

You should also add the environment variables accordingly, take a look at the [main.bicep](../infra/main.bicep) to learn about the environment variables used by each function app and the app service.

All function apps and app services should have the following tag: `azd-env-name : your-azd-env-name`.

The Orchestrator function app, Data ingestion function app, and the App Service should have respectively the following tags: `azd-service-name : orchestrator`, `azd-service-name : dataIngest`, and `azd-service-name : frontend`.

### Azure OpenAI

When reusing an Azure OpenAI resource, it's essential to first specify both the OpenAI resource name and its resource group, as outlined in the [General Instructions](#general-instructions).

Additionally, the original resource must have two deployments, one for a GPT model and another for an embeddings model.

Ensure the embeddings model is **text-embedding-3-large** version 1, with the deployment named **text-embedding**.

If you're using a different name for the Embedding model, you'll need to set the corresponding environment variables as shown in the table below.

| Item                       | Environment Variable Name               |
|----------------------------|-----------------------------------------|
| Embeddings Model Name      | AZURE_EMBEDDINGS_MODEL_NAME             |
| Embeddings Model Version   | AZURE_EMBEDDINGS_VERSION                |
| Embeddings Deployment Name | AZURE_EMBEDDINGS_DEPLOYMENT_NAME        |
| Embeddings Vector Size     | AZURE_EMBEDDINGS_VECTOR_SIZE            |

The default GPT model is **gpt-4o** version **2024-11-20** and the default deployment name is **chat**. If you're using the pre-created service with these default settings, no further modifications are required.

However, if you're using a different name for the GPT, or a different model, you'll need to set the corresponding environment variables as shown in the table below.

| Item                       | Environment Variable Name               |
|----------------------------|-----------------------------------------|
| GPT Deployment Name        | AZURE_CHAT_GPT_DEPLOYMENT_NAME          |
| GPT Model Name             | AZURE_CHAT_GPT_MODEL_NAME               |
| GPT Model Version          | AZURE_CHAT_GPT_MODEL_VERSION            |

To set these environment variables, use the `azd env set` command as described earlier.

For instance, to inform the name of the GPT deployment, you would update the `AZURE_CHAT_GPT_DEPLOYMENT_NAME` variable like this:

`azd env set AZURE_CHAT_GPT_DEPLOYMENT_NAME my-gpt-deployment-name`

### CosmosDB

In addition to specifying the CosmosDB service name, database name, and resource group as mentioned in the [General Instructions](#general-instructions), it's important to note that the reused Cosmos account should contain the following containers:

- Conversations Container
- Datasources Container

You can create the containers with default names or use your own names. If using default names, please create them with the following names:

- Conversations Container: 'conversations'
- Datasources Container (used when orchestration layer will connect to SQL or Fabric data sources): 'datasources'

If you prefer custom names, use the following variables to define your names with `azd env set` command:

- AZURE_DB_CONVERSATIONS_CONTAINER_NAME
- AZURE_DB_DATASOURCES_CONTAINER_NAME

### Key Vault

If you are reusing a Key Vault, the identity used to execute the AZD commands, whether it's your Entra ID user or a Service Principal, must have an Access Policy that allows `list`, `get`, and `set` operations on the secrets within this Key Vault.

### Virtual Network (VNet)

If you prefer to use an existing VNet, that's perfectly fine. In this case, you’ll need to set up your network resources—such as the VNet, subnets, and private endpoints—manually and indicate this by setting the `VNET_REUSE` variable. 

Below is a typical workflow: first, provision non-network resources, such as the Function App and CosmosDB; then, create and configure the network resources; and finally, deploy the application components (orchestrator, frontend, and data ingestion).

> [!NOTE] You may create the VNet and subnets before provisioning non-network resources if preferred. However, private endpoints can only be created after the associated resources are provisioned.

**Steps to Provision GPT-RAG Resources while Reusing Network Resources:**

1. **Set Environment Variable:**
   Before provisioning, set the environment variable to indicate that you will reuse an existing VNet by running:
   ```bash
   azd env set NETWORK_ISOLATION true 
   azd env set VNET_REUSE true
   ```

2. **Provision Resources:**
   Provision the core GPT-RAG resources (Function App, AI Services, etc.) by executing:
   ```bash
   azd provision
   ```

3. **Setup Network:**
   After provisioning, you can configure the necessary network resources to ensure your application functions smoothly. Instructions on creating these network elements manually via the Azure Portal are available on the [Manual Network Setup](GUIDE.md#3-manual-network-setup) section in the Admin Guide.

   This page explains how to manually create the network resources used by the solution, following the same architectural definitions as the Bicep template used for automatic network setup.

> [!Note]
> We recommend using the same VNet and subnet topology as defined in the architecture to facilitate maintenance, but feel free to organize as preferred. The important part is to ensure the same connectivity among resources.

4. **Deploying GPT-RAG Application Components:**
    After provisioning the GPT-RAG resources with `azd provision` and configuring the network resources, you can deploy the GPT-RAG application components using:
    ```bash
    azd package
    azd deploy
    ```

#### Bastion and Data Science VM:

If users have secure access to the VNet through ExpressRoute or VPN, they can perform the required tasks directly from their own machines. This eliminates the need for a Bastion VM, making its creation optional. This way, you won’t need to create a Bastion subnet or provision a Data Science VM.

To skip provisioning the Data Science VM when running `azd provision`, remember to set the following variable to false:

```bash
azd env set AZURE_VM_DEPLOY_VM false
```
