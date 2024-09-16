# Custom Installation for Zero Trust

This guide details the automated installation of the Solution Accelerator within a Zero Trust architecture. It leverages Bicep Infrastructure as Code (IaC) for efficient deployment and management of Azure resources. The guide includes prerequisites, a comprehensive list of required resources, and a step-by-step installation process, ensuring a streamlined setup that adheres to Zero Trust principles.

**Table of Contents**

1. [Prerequisites](#prerequisites)
2. [Resource List](#resource-list)
3. [Installation Procedure](#installation-procedure)
   - [Before You Begin](#before-you-begin)
   - [Installation Steps](#installation-steps)
4. [Optional Next Steps](#optional-next-steps)
5. [Extending Application Components](#extending-application-components)


## Prerequisites

- [Azure Subscription](https://azure.microsoft.com/free/).
- [Access to Azure OpenAI](https://learn.microsoft.com/legal/cognitive-services/openai/limited-access) - submit a form to request access.
- [Azure CLI (az)](https://aka.ms/install-az) - to run azure cli commands.
- Azure Developer CLI: [Download azd for Windows](https://azdrelease.azureedge.net/azd/standalone/release/1.5.0/azd-windows-amd64.msi), [Other OS's](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd).
 - Powershell 7+ with AZ module (Windows only): [Powershell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package), [AZ Module](https://learn.microsoft.com/en-us/powershell/azure/what-is-azure-powershell?view=azps-11.6.0#the-az-powershell-module)
 - Git: [Download Git](https://git-scm.com/downloads)
 - Node.js 16+ [windows/mac](https://nodejs.dev/en/download/)  [linux/wsl](https://nodejs.dev/en/download/package-manager/)
 - Python 3.11: [Download Python](https://www.python.org/downloads/release/python-3118/)
 - Initiate an [Azure AI services creation](https://portal.azure.com/#create/Microsoft.CognitiveServicesAllInOne) and agree to the Responsible AI terms **

** If you have not created an Azure AI service resource in the subscription before

You will also need **Owner** or **Contributor + User Access Administrator** permission in Subscription scope.

## Resource List

Here is the complete list of resources for a standard Zero Trust deployment, including descriptions and SKUs. These defaults have been extensively tested in the automated installation. You can review them to adjust to your needs, considering usage factors like user volume and data.

> [!TIP]
> Review this list before deploying to ensure you have the necessary quota for deployment in the desired subscription and region.

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

**Gather Necessary Information**

- Subscription Name
- Resource Group Name
- Azure Location Location
- Azure Environment Name (ex: gpt-rag-dev,  gpt-rag-poc, ...)

> [!NOTE]
> Choose a region with sufficient service quotas. Commonly tested regions include eastus2, eastus, and westus.

**Review these points for potential customizations**

- **Resource names** (optional)

You can customize the names of the resources being created. By default, azd automatically generates a unique name based on the environment name, subscription, and location. If you prefer to define specific names, refer to [this page](CUSTOMIZATIONS_RESOURCE_NAMES.md) to learn how to customize each resource name. Before running the `azd provisioning` command, you must execute a command like the one below to apply these custom names to each resource you want to customize:

`azd env set AZURE_RESOURCE_TYPE_NAME <yourResourceNameHere>`

- **Reuse pre-existing resources** (optional)

In some cases, you may want to use one or more pre-existing resources in your subscription instead of creating new ones. Our Bicep template allows you to do this. For detailed instructions on how this can be achieved, please take a look at the [Bring Your Own Resources](CUSTOMIZATIONS_BYOR.md) page.

- **Virtual Network Configuration** (optional)

Adjust network addressing to avoid overlaps with existing VNets, as overlapping address ranges prevent direct connections via VNet peering, VPN gateways, or ExpressRoute. The default address ranges are:

| **Network Item**         | **Address Range**    |
|--------------------------|----------------------|
| AI VNet                  | 10.0.0.0/24          |
| ai-subnet                | 10.0.0.0/28          |
| app-services-subnet      | 10.0.0.16/28         |
| database-subnet          | 10.0.0.32/28         |
| app-int-subnet           | 10.0.0.48/28         |
| AzureBastionSubnet       | 10.0.0.64/28         |

Each `/28` subnet offers 11 usable IP addresses, as Azure reserves 5 IP addresses in each subnet. The `/24` VNet allows 251 usable IP addresses. To customize address ranges, set the following environment variables:

| **Environment Variable**               | **Network Item**      |
|----------------------------------------|-----------------------|
| `AZURE_VNET_ADDRESS`                   | AI VNet               |
| `AZURE_AI_SUBNET_PREFIX`               | AI Subnet             |
| `AZURE_APP_INT_SUBNET_PREFIX`          | App Internal Subnet   |
| `AZURE_APP_SERVICES_SUBNET_PREFIX`     | App Services Subnet   |
| `AZURE_BASTION_SUBNET_PREFIX`          | Bastion Subnet        |
| `AZURE_DATABASE_SUBNET_PREFIX`         | Database Subnet       |

Set the desired address range with `azd env` command after `azd int` and before `az provision`. 

Example: `azd env set AZURE_AI_SUBNET_PREFIX 10.0.0.16/28`.

### Installation Steps

Before starting the Zero Trust architecture deployment, review the prerequisites. Note that Node.js and Python are only required for the second phase, which you will perform on the VM created during the deployment. To deploy this architecture, follow these steps using Azure Developer CLI (azd) in your terminal:

**1** Download the Repository

```sh
azd init -t azure/gpt-rag
```

> [!NOTE]  
> Add the `-b agentic` parameter if you want to use the agentic version.
> ```sh
> azd init -t azure/gpt-rag -b agentic
> ```

**2** Enable network isolation
   
```sh  
azd env set AZURE_NETWORK_ISOLATION true  
```  
 
**2** Login to Azure:

**2.a** Azure Developer CLI:

```sh
azd auth login
```

**2.b** Azure CLI:

```sh
az login
```

**3** Set environment variable values

Run the `azd env set` commands if you want to customize the installation as indicated in the previous section.

**4** Start Building the infrastructure and components deployment:

```sh
azd provision
```

**5** Use the Virtual Machine with the Bastion connection (created in step 4) to proceed with the deployment.
   
Log into the created VM with the user **gptrag** and authenticate with the password stored in the key vault, similar to the figure below:  

<BR>   
<img src="../media/readme-keyvault-login.png" alt="Keyvault Login" width="1024">
   
**6**  Upon accessing Windows, install [Powershell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4#installing-the-msi-package), as the other prerequisites are already installed on the VM.  
   
**7** Open the command prompt and run the following command to update azd to the latest version:  
   
```  
choco upgrade azd  
```  
   
After updating azd, simply close and reopen the terminal.  
   
**8** Create a new directory, for example, `deploy` then enter the created directory.  
   
```  
mkdir deploy  
cd deploy  
```  

To finalize the procedure, execute the subsequent commands in the command prompt to successfully complete the deployment:

```  
azd init -t azure/gpt-rag  
azd auth login   
azd env refresh  
azd package  
azd deploy  
```  

> [!IMPORTANT] 
> Note: when running the ```azd init ...``` and ```azd env refresh```, use the same environment name, subscription, and region used in the initial provisioning of the infrastructure.  
   
> [!IMPORTANT]  
> Add the `-b agentic` parameter to azd init command if you are using the agentic option.
> ```sh
> azd init -t azure/gpt-rag -b agentic
> ```

**Done! Zero trust deployment is completed.**

### Optional Next Steps

**9** [Add app authentication](https://learn.microsoft.com/en-us/azure/app-service/scenario-secure-app-authentication-app-service). [Watch this quick tutorial](https://youtu.be/sA-an25jMB4) for step-by-step guidance.

**10** Configure [Azure Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/create-front-door-portal) to allow external access to your app only through Azure Front Door.

**11. Configure Outbound Rules for External Services**

The solution accelerator allows integration with other services to enhance the data sources used for grounding the solution. If you plan to connect to these external services as described in the [AI Integration HUB](AI_INTEGRATION_HUB.md) section, you'll need to configure outbound rules for specific public endpoints, as shown in the table below.


| Service                | Source                       | Destination                           |
|------------------------|------------------------------|---------------------------------------|
| Bing Custom Search      | Orchestrator Function App    | https://api.bing.microsoft.com        |
| MS Graph API            | Data Ingestion Function App  | https://graph.microsoft.com      |

> [!TIP]
> Use **Azure API Management** to secure API requests when connecting to external services.

### Extending Application Components

After installing the solution accelerator, you may want to customize its application components. For example, you can modify the orchestrator for a specific scenario or adjust the data ingestion app for different chunk generation. See [Extending App Components](EXTENDING_APP_COMPONENTS.md) for details.