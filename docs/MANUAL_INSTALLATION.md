# Manual Installation for Zero Trust

This guide details the manual installation of the Solution Accelerator within a Zero Trust architecture. It includes prerequisites, a comprehensive list of required resources, and a step-by-step installation process.

If you prefer to proceed with the automated installation, please follow the instructions in the [Getting Started](https://github.com/Azure/GPT-RAG#zero-trust-architecture-deployment) section. However, feel free to read this document to understand the process behind the scenes.

## Prerequisites

* [Azure Subscription](https://azure.microsoft.com/free/).
* [Access to Azure OpenAI](https://learn.microsoft.com/legal/cognitive-services/openai/limited-access) - submit a form to request access.
* [Azure CLI (az)](https://aka.ms/install-az) - to run azure cli commands.
* [Git](https://git-scm.com/downloads) - to get repository contents.

You will also need the following permissions:
* Role: Owner or Contributor + User Access Administrator
* Scope: Resource group or Subscription

## Resources List

Here is the complete list of resources for a standard Zero Trust deployment, including descriptions and SKUs. These defaults have been extensively tested in the automated installation. You can adjust them during manual installation to suit your needs, considering usage factors like user volume and data.

### App Services

- **App Service Plan**
    <BR>Hosts the frontend and function apps.
    - SKU: P0v3
    - Operating System: Linux
    - Zone Redundant: Disabled
- **Function App (Orchestrator)**
    <BR>Orchestrates the RAG flow.
    - Operating System: Linux
    - LinuxFxVersion: python|3.11
- **Function App (Data Ingestion)**
    <BR>Supports the Data Ingestion Pipeline.
    - Operating System: Linux
    - LinuxFxVersion: python|3.11
- **App Service (Frontend)**
    <BR>Provides the Web User Interface.
    - Operating System: Linux
    - LinuxFxVersion: python|3.12
- **Application Insights**
    <BR>Provides real-time monitoring for apps.
    - Type: Classic

### Security

- **Key Vault (Application)**
    <BR>Stores API keys when needed.
    - SKU: Standard
    - Soft Delete: Enabled
    - Purge Protection: Enabled
- **Key Vault (Test VM Bastion)**
    <BR>Used by Bastion to store the Test VM password.
    - SKU: Standard
    - Soft Delete: Enabled
    - Purge Protection: Enabled

### AI Services

- **Azure AI Services Multi-Service Account**
    <BR>Reads documents (Data Ingestion) and interacts with users (Web UI).
    - SKU: Standard
- **Azure OpenAI**
    <BR>Generates responses and vector embeddings.
    - SKU: Standard
    - Deployments:
        - Regional gpt-4o, 40 TPM.
        - text-embedding-ada-002, 40 TPM.
- **Search Service**
    <BR>Provides vector indexes for the retrieval step.
    - SKU: Standard2
    - Replicas: 1
    - Partitions: 1

### Compute

- **Virtual Machine (Test VM)**
    <BR>Provides access to configure and test the solution after disabling public endpoints.
    - Operating System: Windows (Windows Server 2019 Datacenter)
    - SKU: Standard_D4s_v3 (4 vCPUs, 16 GiB memory)
    - Image Publisher: microsoft-dsvm (Data Science VM)
    - Image Offer: dsvm-win-2019

### Storage

- **Storage Account (Documents)**
    <BR>Stores content used for grounding responses.
    - Performance: Standard
    - Replication: Locally-redundant storage (LRS)
    - Account Type: StorageV2 (general purpose v2)
- **Storage Account (Orchestrator Function App)**
    <BR>Stores logs, code, and execution state for the Orchestrator Function App.
    - Performance: Standard
    - Replication: Locally-redundant storage (LRS)
    - Account Type: Storage (general purpose v1)
- **Storage Account (Data Ingestion Function App)**
    <BR>Stores logs, code, and execution state for the Data Ingestion Function App.
    - Performance: Standard
    - Replication: Locally-redundant storage (LRS)
    - Account Type: Storage (general purpose v1)
- **Test VM Disk**
    <BR>Disk for the Test VM.
    - Disk Size: 128 GiB
    - Storage Type: Premium SSD LRS
    - Operating System: Windows

### Database

- **Azure Cosmos DB**
    <BR>Stores conversation history and metadata to improve quality.
    - Kind: GlobalDocumentDB
    - Database Account Offer Type: Standard
    - Capacity Mode: Provisioned throughput

### Networking

- **Virtual Network**
    <BR>AI Services VNet.
    - Address Space: 10.0.0.0/24
> Address range is a suggestion, you should use what works for you.

- **Subnets**
    <BR>Designate network segments in the AI Services VNet to organize and secure traffic.
    - Subnets:
        - ai-subnet <BR>10.0.0.0/28
        - app-services-subnet <BR>10.0.0.16/28
        - database-subnet <BR>10.0.0.32/28
        - app-int-subnet <BR>10.0.0.48/28
        - AzureBastionSubnet <BR>10.0.0.64/28
    > Address range is a suggestion, you should use what works for you.

- **Private Endpoints**
    <BR>Enable private, secure access to Azure services via a virtual network.
    - Private Endpoints (PEs):
        - AI Search Private Endpoint
        - AI Services Private Endpoint
        - Azure OpenAI Private Endpoint
        - CosmosDB Private Endpoint
        - Data Ingestion Function App Private Endpoint
        - Frontend App Service Private Endpoint
        - Key Vault Private Endpoint
        - Orchestrator Function App Private Endpoint
        - Storage Account (Documents) Private Endpoint

- **Private DNS Zones**
    <BR>Resolve private endpoints to private IPs within a virtual network.
    - Private DNS Zones:
        - App Service and Function Apps Private DNS <BR> privatelink.azurewebsites.net
        - AI Services Private DNS <BR> privatelink.cognitiveservices.azure.com
        - Azure OpenAI Private DNS <BR> privatelink.openai.azure.com
        - Storage Account (Documents) Private DNS <BR> privatelink.blob.core.windows.net
        - CosmosDB Private DNS <BR> privatelink.documents.azure.com
        - AI Search Private DNS <BR> privatelink.search.windows.net
        - Key Vault Private DNS <BR> privatelink.vaultcore.azure.net

- **Network Interfaces**
    <BR>Provide connectivity to private endpoints and virtual machines within the AI Services VNet.
    - Interfaces:
        - AI Search PE's Network Interface
        - AI Services PE's Network Interface
        - Azure OpenAI PE's Network Interface
        - CosmosDB PE's Network Interface
        - Data Ingestion Function App PE's Network Interface
        - Frontend App Service PE's Network Interface
        - Key Vault PE's Network Interface
        - Orchestrator Function App PE's Network Interface
        - Storage Account (Documents) PE's Network Interface
        - Test Virtual Machine Network Interface

- **Bastion**
    <BR>Enables private and secure access to the Test VM without exposing the VM directly to the internet.
    - Tier: Standard

- **Public IP**
    <BR>Used by Bastion to enable secure access to the Test VM.
    - SKU: Standard
    - Tier: Regional

## Installation Procedure

### Before You Begin

Gather Necessary Information:
- Resource Group Name
- Location
- AI VNet Address Range
- Subnets IP Range
    - ai-subnet
    - app-services-subnet
    - database-subnet
    - app-int-subnet
    - AzureBastionSubnet
    
### 1. Creation of Core Components

1. **Resource Group**
   - Create a resource group in Azure where all components will be deployed.

2. **Virtual Network (AI VNet)**
     - Create a VNet with the required subnets:
        - ai-subnet (AI services subnet)
        - AzureBastionSubnet (Bastion subnet)
        - app-int-subnet (App Integration subnet)
        - app-services-subnet (App Services subnet)
        - database-subnet (Database subnet)

3. **Test VM**
   - Create a Windows VM in the same VNet to test and access resources without a public address.
   - Create the [Data Science VM](https://learn.microsoft.com/en-us/azure/machine-learning/data-science-virtual-machine/provision-vm?view=azureml-api-2) in the AI Subnet.
   - Set up a Bastion to access the VM from the internet.
   - Optionally, create a KeyVault to store the VM password as a secret.
    
4. **Database**
   - **Cosmos DB**
     - Create a Cosmos DB account with a database with two containers:
         - conversations
         - models
     - Disable public network access.

5. **AI Services**
   - **Azure Cognitive Services**
     - Create Azure AI Services.
     - Disable public network access.

   - **Azure OpenAI**
     - Create an Azure OpenAI service
     - Create deployments:
        - Regional gpt-4o, 40 TPM.
        - text-embedding-ada-002, 40 TPM.
     - Disable public network access.
     
   - **Azure Search**
     - Create an Azure Search service with standard2 SKU.
     - Create shared private link connection to:
         - Data Ingestion Function App
         - Blob Storage Account (Documents)

6. **Storage**
   - **Storage Account**
     - Create a storage account to store documents
     - Create the following blob containers:
        - documents
        - documents-images
        - documents-raw
     - Disable public access.
     - Enable soft delete for blobs.

7. **Security**
    - **Key Vault (Application)**
        - Create the Azure Key Vault with the following secrets
            - azureOpenAIKey (Azure OpenAI API Key)
            - azureSearchKey (Azure AI Search query API Key)
            - formRecKey (Azure AI Services API Key)
            - speechKey (Azure AI Services API Key)
        - Disable public access.
     
8. **App Services**

    - **App Service Plan**
        - Create an App Service Plan with the appropriate SKU and OS specifications.

    - **Function Apps**
        - Create function apps for the orchestrator and data ingestion.

    - **Web App (Front-end)**
        - Create a web app for the front-end.
        - Disable public access.
        - [Add app authentication](https://learn.microsoft.com/en-us/azure/app-service/scenario-secure-app-authentication-app-service). [Watch this quick tutorial](https://youtu.be/sA-an25jMB4) for step-by-step guidance.
        
9. **Private DNS Zones**
    - Configure private DNS zones for various services
    - AI Search Private Endpoint
    - AI Services Private Endpoint
    - Azure OpenAI Private Endpoint
    - CosmosDB Private Endpoint
    - Data Ingestion Function App Private Endpoint
    - Frontend App Service Private Endpoint
    - Key Vault Private Endpoint
    - Orchestrator Function App Private Endpoint
    - Storage Account (Documents) Private Endpoint
    
10. **Private Endpoints**
     - Set up private endpoints to secure communication within the VNet.
        - AI Search Private Endpoint
        - AI Services Private Endpoint
        - Azure OpenAI Private Endpoint
        - CosmosDB Private Endpoint
        - Data Ingestion Function App Private Endpoint
        - Frontend App Service Private Endpoint
        - Key Vault Private Endpoint
        - Orchestrator Function App Private Endpoint
        - Storage Account (Documents) Private Endpoint

11. **Permissions**
    - Assign permissions to the Managed Identities of various components in Azure. In each item, sample commands are provided to assign these roles; please use them by replacing the variables with the values specific to your environment.

    - **Storage Account**
        - Assign Storage Account "Storage Blob Data Reader" role to the Frontend App Service Managed Identity.
        ```
        az role assignment create \
            --assignee $principalId \
            --role "Storage Blob Data Reader" \
            --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
        ```

        - Assign Storage Account "Storage Blob Data Contributor" role to the Data Ingestion Function App Identity.
        ```
        az role assignment create \
            --assignee $principalId \
            --role "Storage Blob Data Contributor" \
            --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
        ```

    - **Key Vault**
        - Assign Key Vault "Key Vault Secrets User" role to the Identities of the following Apps:
            - Orchestrator Function App
            - Data Ingestion Function App
            - Frontend App Service
        ```
        az role assignment create \
            --assignee $principalId \
            --role "Key Vault Secrets User" \
            --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.KeyVault/vaults/$keyVaultName"
        ```

    - **Cosmos DB**
        - Assign Cosmos DB "Cosmos DB Built-in Data Contributor" role to Orchestrator's Managed Identity.
        ```
        az cosmosdb sql role assignment create \
            --account-name $cosmosDbAccountName \
            --resource-group $resourceGroupName \
            --role-definition-id 00000000-0000-0000-0000-000000000002 \
            --scope "/" \
            --principal-id $principalId
        ```

    - **Azure AI Search**
        - Assign AI Search "Search Index Data Reader" role to Orchestrator's Managed Identity.
        ```    
            az role assignment create \
                --assignee $principalId \
                --role "Search Index Data Reader" \
                --scope "/subscriptions/<subscription-id>/resourceGroups/$resourceGroupName/providers/Microsoft.Search/searchServices/$searchServiceName"
        ```

    - **Azure OpenAI**
        - Assign Azure OpenAI "Cognitive Services OpenAI User" role to the Identities of the following Resources:
            - Orchestrator Function App
            - Data Ingestion Function App
        ```    
            az role assignment create \
                --assignee $principalId \
                --role "Cognitive Services OpenAI User" \
                --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$openAIAccountName"
        ```

    - **Azure AI Services**
        - Assign AI Services "Cognitive Services Contributor" role to the Managed Identities of the following Apps:
            - Frontend App Service
            - Data Ingestion Function App
        ```    
            az role assignment create \
              --assignee $principalId \
              --role "Cognitive Services Contributor" \
              --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$aiServicesAccountName"
        ```

    - **Application Insights**
        - Assign Application Insights "Application Insights Component Contributor" role to the Managed Identities of the following Apps:
            - Orchestrator Function App
            - Data Ingestion Function App
            - Frontend App Service
        ```
            az role assignment create \
                --assignee $principalId \
                --role 'Application Insights Component Contributor' \
                --scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/microsoft.insights/components/$appInsightsName"
        ```

12. **Application Settings**
    - The applications (orchestrator, data ingestion, and frontend web app) use information obtained from environment variables. These variables are stored as App Settings in each application. When using the automated procedure, you don't need to worry about this. However, for the manual procedure, you'll need to set these variables manually. 
    - [Click here to see an example](MANUAL_ENVIRONMENT.md) of how to set these variables using the Azure CLI. You will need to adjust the commands to correctly reflect the names of your applications and parameters.

13. **Application Deployment**

    - Once resources are provisioned and settings configured, you’re ready to deploy each application.
    - First clone the repositories for each application.
    - For the Orchestrator Function App and Data Ingestion Function App:
      - In VSCode with the [Azure Function App Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions), go to the *Azure* panel, locate your Function App in the resource explorer, right-click on it, and select *Deploy*.
    - For the App Service Frontend deployment refer to the deployment section in the [frontend repo](https://github.com/Azure/gpt-rag-frontend#deploy-quickstart).

14. **External Access**
    - To allow internet access to your app, permit access only from [Azure Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/create-front-door-portal) to your App Service.
