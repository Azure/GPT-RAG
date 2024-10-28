# GPT-RAG User & Admin Guide

*This comprehensive guide provides both users and administrators with detailed instructions on deploying, configuring, and managing the GPT-RAG solution within a Zero Trust Architecture.*

## Table of Contents

1. [**Overview**](#overview)
2. [**Concepts**](#concepts)
   - [2.1 Solution Architecture](#solution-architecture)
   - [2.2 Data Ingestion](#data-ingestion)
   - [2.3 Orchestration Flow](#orchestration-flow)
   - [2.4 Network Components](#network-components)
   - [2.5 Access Control](#access-control)
3. [**How-to: User**](#how-to-user)
   - [3.1 Accessing the Application](#accessing-the-application)
   - [3.2 Upload Content](#uploading-documents-for-ingestion)
   - [3.3 Reindexing Data](#reindexing-documents-in-ai-search)
4. [**How-to: Administration**](#how-to-administration)
   - [4.1 Deploying the Solution Accelerator](#deploying-the-solution-accelerator)
   - [4.2 Network Configuration Scenarios](#network-configuration-scenarios)
   - [4.3 Accessing the Data Science VM](#accessing-the-data-science-vm-via-bastion)
   - [4.4 Internal User Access](#internal-user-access)
     - [4.4.1 VNet Peering](#configuring-vnet-peering)
     - [4.4.2 Private Endpoints](#configuring-private-endpoints)
   - [4.5 External User Access](#external-user-access)
     - [4.5.1 Front Door & WAF](#configuring-front-door-and-web-application-firewall-waf)
     - [4.5.2 IP Allowlist](#configuring-ip-allowlist)
   - [4.6 Entra Authentication](#configuring-entra-authentication)
   - [4.7 Authorization Setup](#configuring-authorization)
   - [4.8 Setting Up Git Repos](#setting-up-git-repos)
5. [**Troubleshooting**](#troubleshooting)

---

## Overview

The **GPT-RAG Solution Accelerator** enables organizations to leverage **Generative AI** for enhanced customer support, decision-making, and data-driven processes by empowering systems to handle complex inquiries using extensive datasets. Designed to provide **secure and efficient deployment**, it allows businesses to integrate AI with existing operations, making it adaptable for both simple and advanced information retrieval.

Beyond classical **Retrieval-Augmented Generation (RAG)** capabilities, the accelerator incorporates **agents** that support sophisticated scenarios such as **NL2SQL query generation** and other context-aware data interactions. This flexibility enables advanced use cases where AI can seamlessly retrieve and interpret information, meeting diverse technical requirements.

The GPT-RAG Solution Accelerator follows a **modular approach**, consisting of three components: **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)**, **[Orchestrator](https://github.com/Azure/gpt-rag-agentic)**, and **[App Front-End](https://github.com/Azure/gpt-rag-frontend)**, which utilizes the [Backend for Front-End](https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends) pattern to provide a scalable and efficient web interface.

![Zero Trust Architecture](../media/admin-guide-homepage.png)
<br>*GPT-RAG UI*

### Protected Data Access with Zero Trust Design

Adopting a **Zero Trust** approach in Azure, as implemented by the GPT-RAG Solution Accelerator, provides a strong **security foundation** to safeguard your organization’s data and resources. Instead of using public endpoints, which expose services to the internet and increase susceptibility to cyber threats, this architecture ensures all access occurs within a **secure, isolated network** environment, reducing the attack surface and mitigating the risk of unauthorized access.

GPT-RAG's **Zero Trust** architecture with **private endpoints** ensures **network isolation** for sensitive data, enabling efficient Azure service integration without public IP exposure. This approach mitigates risks like data breaches and unauthorized access, creating a controlled environment that strengthens **data integrity** and confidentiality.

### Tailored Orchestration and Chunking

The GPT-RAG Solution Accelerator's **agentic orchestration** allows organizations to design **tailored orchestration flows** that coordinate multiple specialized agents. This customization ensures that complex queries are handled with precision and efficiency, leading to more accurate and contextually relevant AI responses.

Additionally, the solution’s **custom chunking strategy** tailors content segmentation to fit the unique characteristics of different data types and document structures. Aligning chunking methods to data specifics enhances retrieval speed, accuracy, and AI responsiveness, ensuring information is precise and contextually relevant.

## Concepts

### Solution Architecture

The solution leverages a **Zero Trust Architecture** to ensure maximum security and compliance. All components are securely integrated within a virtual network, and communication between services is strictly controlled.

![Zero Trust Architecture](../media/architecture-GPT-RAG-ZeroTrust-LZ.png)
*Zero Trust Architecture*

The diagram above illustrates the Zero Trust architecture. The **GPT-RAG Solution Accelerator** scope encompasses components within the **Enterprise RAG** resource group, providing essential Zero Trust functionalities.

### Key Resources

- **Virtual Network (VNet):** Isolates resources and controls inbound and outbound traffic.
- **Azure App Service:** Hosts the front-end application.
- **Azure Functions:** Executes serverless functions for data ingestion and orchestration.
- **Azure Storage Account:** Stores data blobs for retrieval.
- **Azure AI Search:** Indexes and searches data efficiently.
- **Azure OpenAI:** Generates responses and vector embeddings.
- **Azure AI Services:** Reads documents for data Ingestion.
- **Azure CosmosDB:** Stores conversation history and metadata to improve quality.
- **Azure Key Vault:** Manages secrets used by the solution.
- **Azure Private Endpoints:** Secures network communication between services.
- **Data Science VM:** Provides a secure Bastion environment for admins and developers to configure the solution.

For more information about Zero Trust architecture, see the [Enterprise RAG (GPT-RAG) Architecture](ARCHITECTURE.md) page.

> [!TIP]
> Need the Visio diagrams used in this documentation? You can easily download them here: [Enterprise RAG](../media/visio/Enterprise%20RAG.vsdx).

## Data Ingestion

Data ingestion is a crucial part of the solution, enabling the system to retrieve accurate and up-to-date information.

### How It Works

1. **Data Collection:** Documents are ingested from `documents` blob container in the GPT-RAG storage account.
2. **Data Preprocessing:** The documents are prepared for indexing in AI Search Index, including breaking them into smaller chunks and optimizing them for efficient searchability.
3. **Indexing for Search:** The chunks are then indexed within Azure AI Search, allowing for efficient retrieval during query processing.

> [!NOTE]  
> The ingestion process uses a pull approach: an Azure AI Search indexer checks blob storage hourly, triggering a Function App to preprocess and chunk new documents for indexing. Execution frequency is configurable.

For more information about the data ingestion process take a look at the [GPT-RAG ingestion](https://github.com/Azure/gpt-rag-ingestion) function app repo.

## Orchestration Flow

The solution uses an **Agentic Orchestration** approach, enabling agents to operate autonomously for efficient handling of user requests. The orchestration flow described below provides a typical structure but can be tailored to meet specific requirements.

### How It Works

1. **User Interaction:** The user submits a query through the front-end application.
2. **Orchestration Process:** The Orchestrator initiates a group chat with specialized agents to address the query.
   - Agents retrieve relevant data from an AI Search index or a SQL database.
   - The GPT model generates a response based on the collected information.
3. **Response Delivery:** The front-end application returns a grounded answer to the user.

> [!NOTE]  
> Running as a Function App, the orchestrator offers scalable and efficient management of agent operations.

For more information about the agentic orchestration take a look at the [GPT-RAG orchestration](https://github.com/Azure/gpt-rag-agentic) function app repo.

## Network Components

The networking architecture for the GPT-RAG solution leverages Azure’s advanced features to ensure a secure, flexible, and isolated environment, adhering to Zero Trust principles through the use of private endpoints and stringent access controls.

1. **Azure Virtual Network (VNet):** Provides a logically isolated network environment, segmented into subnets for different application tiers, ensuring organized and secure deployment of resources.
    
2. **Azure Private Link and Private Endpoints:** Establish secure, private connections to Azure services, keeping traffic within the Microsoft backbone network and minimizing exposure to the public internet.
    
3. **Private DNS Zones:** Enable internal name resolution within the Virtual Network, ensuring secure communication between services without public exposure.
    
4. **Network Security Groups (NSGs):** Control and restrict inbound and outbound traffic to Azure resources with granular security rules, enhancing the protection of your network.
    
5. **Azure Bastion:** Provides secure access for the development team to the VM used for GPT-RAG deployment via the Azure portal, without exposing it to the internet, ensuring secure and controlled deployment activities.

> [!NOTE]  
> The Infrastructure as Code (IaC) Bicep templates included in this solution accelerator allow you to automatically provision networking resources. The templates support customization so you can follow your organization's naming conventions and address range standards. Alternatively, if you prefer, you can choose to set up these resources manually.

**External users** can connect securely via **Azure Front Door** with WAF. **Internal users** can access through **VPN** or **ExpressRoute**. **VNet Peering** or **Private Endpoints** can be configured to connect GPT-RAG resources to your VNet. Further configuration details will follow. 

<!-- *Refer to the Solution Architecture diagram for a visual representation.* -->

## Access Control

### Authentication

The solution utilizes **Azure Entra ID** (formerly Azure Active Directory) for authenticating users accessing the front-end application. This ensures secure access control and integration with organizational identity management.

### Authorization

Authorization is managed by defining specific Entra ID users and groups that are permitted to use the application. These allowed users and groups are configured directly in the App Service settings, ensuring that only authorized individuals have access to the application.


## How-to: User

This section guides users through essential tasks required to interact with the GPT-RAG Solution Accelerator. This section is divided into three main parts:

1. **Accessing the Application**
2. **Managing Document Uploads**
3. **Reindexing Documents in AI Search**

### Accessing the Application

To connect to the web frontend of the GPT-RAG Solution Accelerator:

- **Navigate to the Web Application:**
  - Open your preferred web browser.
  - Enter the web application endpoint URL provided by your administrator. The endpoint will follow a format similar to `webgpt0-[random_suffix].azurewebsites.net`, where `[random_suffix]` is a unique identifier assigned during deployment.
  - **Example:** `https://webgpt0-abc123.azurewebsites.net`
  - Log in using your authorized credentials to access the application's interface.

![GPT-RAG Front-end UI](../media/admin-guide-homepage.png)
<br>*GPT-RAG Front-end UI*

### Uploading Documents for Ingestion

*This task updates documents to be indexed and is intended for users responsible for performing these updates. Users who are not involved in updating documents do not need to handle this task.*

#### **Prerequisites**

Before uploading documents, ensure that you have the necessary permissions in Azure:

- **Azure Role Required:** You must have the **Storage Blob Data Contributor** role assigned in Azure Entra ID for the storage account you will be accessing. This role allows you to upload and manage blobs within the storage containers.

> [!NOTE]
> If you do not have the required role, contact your Azure administrator to obtain the necessary permissions.

#### Procedure

1. **Log in to the Azure Portal:**
   - Navigate to [Azure Portal](https://portal.azure.com/) and sign in with your Azure credentials.

2. **Locate the Storage Account:**
   - In the Azure Portal, go to the **Storage Accounts** section.

   ![Storage account section](../media/admin-guide-document-upload-portal-storage-account-section.png)
   <br>*Selecting documents storage account*
   
3. **Select the storage account name provided by your administrator.**

   ![Selecting documents storage account](../media/admin-guide-document-upload-portal-select-storage-account.png)
   <br>*Selecting documents storage account*

> [!TIP]
> It is the storage account **without** the suffixes **"ing"** or **"orc"**.

4. **Navigate to the Documents Container:**
   - Within the selected storage account, click on **Containers** in the left-hand menu.
   - Locate and select the **Documents** container from the list.

5. **Upload Your Files:**
   - Click the **Upload** button at the top of the container view.
   - In the upload pane, click **Browse** to select the files you wish to upload from your local machine.
   - After selecting the files, click **Upload** to begin the process.
   - Wait for the upload to complete. Once finished, your documents will be available in the **Documents** container for ingestion.

   ![Sample document upload screen](../media/admin-guide-document-upload-portal.png)
   <br>*Sample document upload screen - Azure Portal*

   > **Automatic Indexing:** The AI Search indexer automatically checks for new documents every hour, ensuring that uploaded documents are indexed without manual intervention. If you prefer to index documents immediately, refer to the **Reindexing Content in AI Search** section.

#### **Alternative Method: Using Azure Storage Explorer**

If you need to perform updates frequently, consider using **Azure Storage Explorer** for a more streamlined experience. [Visit the Azure Storage Explorer page](https://azure.microsoft.com/en-us/products/storage/storage-explorer/) to download and learn more about this convenient tool.

### Reindexing Documents in AI Search

*This task updates the retrieval index to ensure that search results remain accurate and efficient. It is designated for users responsible for indexing operations. Users who are not handling the retrieval index do not need to perform this task.*

#### **Prerequisites**

Before reindexing, ensure that you have the necessary permissions:

- **Azure Role Required:** You must have the **Cognitive Search Contributor** or **Cognitive Search Index Administrator** role assigned in Azure Entra ID for the AI Search resource.

> [!NOTE]
> If you do not have the required role, contact your Azure administrator to obtain the necessary permissions.

#### **Procedure**

1. **Log in to the Azure Portal:**
   - Navigate to [Azure Portal](https://portal.azure.com/) and sign in with your Azure credentials.

2. **Navigate to AI Search:**
   - In the Azure Portal, go to the **Resource Groups** section.
   - Select the resource group associated with your application.
   - Within the resource group, locate and select the **AI Search** resource.

3. **Open Search Management:**
   - In the AI Search resource overview, click on **Search Management** in the left-hand menu.

4. **Access GPT-RAG Indexer:**
   - Click on **Indexers** to view the list of available indexers.
   - Locate and select the **ragindex-indexer-chunk-documents**.

   ![AI Search Reindexing UI](../media/admin-guide-ai-search-management.png)
   <br>*GPT-RAG Indexer in Search Management*

5. **Run the Search Index:**
   - Click the **Run** button to initiate the reindexing process for **ragindex-indexer-chunk-documents** indxer.

   ![AI Search Reindexing UI](../media/admin-guide-ai-search-reindex.png)
   <br>*AI Search Indexer UI*

> [!TIP]
> If you wish to reindex all content, click **Reset** before running the search index.

# How-to: Administration

This section provides step-by-step guides for common administrative tasks.

## Deploying the Solution Accelerator

This setup guide will walk you through provisioning a resource group containing all the essential components for the solution to operate effectively. The diagram below highlights the resource group and its corresponding components, marked in red, that will be provisioned during the process.

![Zero Trust Architecture](../media/admin-guide-architecture-scope.png)
<br>*GPT-RAG Zero Trust Architecture*

### Prerequisites

- Azure subscription with access to **Azure OpenAI**.
- **Owner** or **Contributor + User Access Administrator** permission at the Subscription scope.
- Confirm you have the required quota to provision resources in the chosen Azure region for deployment. For details on resources and SKUs, refer to the [Installation Guide](https://github.com/Azure/GPT-RAG/blob/main/docs/AUTOMATED_INSTALLATION.md#resource-list).
- Agree to the Responsible AI terms by initiating the creation of an [Azure AI service](https://portal.azure.com/#create/Microsoft.CognitiveServicesAllInOne) resource in the portal. 

> [!NOTE]
> The last step is unnecessary if an Azure AI service resource already exists in the subscription. 

### Deployment Overview

1. Clone the deployment repository.  
2. Evaluate which network creation scenario best applies to your case (next section).  
3. Update the configuration files to reflect your desired settings.  
4. Execute the automated deployment script.

For the detailed, step-by-step deployment procedure, refer to the [installation procedure](AUTOMATED_INSTALLATION.md).

## Network Configuration Scenarios

This section outlines the various network configuration scenarios for deploying the GPT-RAG Solution Accelerator. Depending on your requirements and existing infrastructure, you can choose one of the following approaches to manage network resources:

1. **Automatic Network Creation**
2. **Automatic Creation with Custom Addressing**
3. **Manual Network Setup**

### 1. Automatic Network Creation

For a straightforward deployment, GPT-RAG can automatically create all essential network resources. Simply set `azd env set NETWORK_ISOLATION` before running `azd provision` to enable this option.

The setup includes a VNet, five subnets, a Network Security Group (NSG) for each subnet, a private endpoint for each service, a private DNS Zone, and a Network Interface for each private endpoint.

**Default Address Ranges:**

| **Network Item**         | **Address Range**    |
|--------------------------|----------------------|
| **ai-vnet**               | **10.0.0.0/23**      |
| **ai-subnet**            | **10.0.0.0/26**      |
| **app-services-subnet**  | **10.0.0.192/26**    |
| **database-subnet**      | **10.0.1.0/26**      |
| **app-int-subnet**       | **10.0.0.128/26**    |
| **AzureBastionSubnet**   | **10.0.0.64/26**     |

This option is ideal for users who want a hassle-free setup with optimal security and connectivity configurations predefined by GPT-RAG.

> [!NOTE]  
> **DNS Configuration:** When allowing GPT-RAG to create Private DNS Zones automatically, they will be created within the GPT-RAG resource group. If you prefer to configure them in your Connectivity subscription, choose the manual network configuration option (Scenario 3).

### 2. Automatic Creation with Custom Addressing

For deployments integrating with existing infrastructure, GPT-RAG allows you to adjust **network addressing** in the configuration files, preventing address overlaps while automating resource creation.

For detailed instructions on customizing these network settings, refer to the [installation procedure](AUTOMATED_INSTALLATION.md).

### 3. Manual Network Setup

If you need full control over network resources or are integrating GPT-RAG into a complex environment, you can manually create the required network resources. This approach is ideal for organizations with specific networking needs or strict security policies.

For detailed instructions on setting up network resources manually, refer to the [Bring Your Own Resources (BYOR) - Virtual Network (VNet) section](https://github.com/Azure/GPT-RAG/blob/main/docs/CUSTOMIZATIONS_BYOR.md#virtual-network-vnet) in the GPT-RAG documentation. The following steps offer a general overview of the process.

**Manual Setup Steps:**

1. **Create Virtual Networks and Subnets:**
   - Define your VNet and subnets based on your organization's network architecture.
   - Ensure that address ranges do not overlap with existing VNets to maintain connectivity.

2. **Set Up Private Endpoints:**
   - Manually create private endpoints for Azure services that GPT-RAG will use.
   - Ensure they are correctly associated with the appropriate subnets.

3. **Configure Private DNS Zones:**
   - Establish Azure Private DNS Zones within your preferred resource group or subscription.
   - Link the DNS zones to your VNets to enable proper name resolution for private endpoints.

4. **Implement Network Security Groups:**
   - Define NSGs with rules that align with your security policies.
   - Apply NSGs to the relevant subnets to control traffic flow.

5. **Integrate with GPT-RAG:**
   - Reference your manually created VNets, subnets, private endpoints, and DNS zones in the GPT-RAG deployment configuration.
   - Ensure that all dependencies and connections are correctly established.


> [!INFO]
> **User Connectivity:** Regardless of the network configuration approach you select, you may need to configure additional network settings to enable connectivity for external or internal users. Refer to the **Internal User Access** and **Internal User Access** sections in this guide for detailed instructions tailored to your specific access requirements.

### Validation

- Ensure all resources are deployed successfully.
- Verify that access controls and network configurations align with Zero Trust principles.

> [!NOTE]  
> After the initial deployment, you may choose to customize or update specific features, such as adjusting prompts, adding a logo to the frontend, testing different chunking strategies, or configuring a custom orchestration strategy like NL2SQL. For detailed guidance on these optional customizations, refer to the deployment section in each component's repository.

## Accessing the Data Science VM via Bastion

After deploying the Solution Accelerator, administrators and dev teams may need to access a Test Virtual Machine (VM) for configuration, customization, or deployment tasks. This section outlines the procedure for connecting to the Data Science VM using Azure Bastion.

> [!NOTE]
> If these users already have secure access to the VNet through ExpressRoute or VPN, they can perform the required tasks directly from their own machines, removing the need for a Bastion VM and making its creation optional.

### **Prerequisites**

- **Azure Permissions:**
  - **Virtual Machine Contributor** role or higher on the resource group containing the Bastion and VM.
  
- **Access Credentials:**
  - Access to the Azure Key Vault containing the Bastion credentials.
  
### **Procedure**

Follow these steps to securely connect to the Data Science VM through Azure Bastion:

#### **Step 1: Access the Azure Portal**

#### **Step 2: Locate the Virtual Machine Resource**

1. **Go to the Bastion blade:**
   
   - In the Azure Bastion overview page, log into the created VM with the user **gptrag** and authenticate with the password stored in the key vault, similar to the figure below:  

   ![Bastion Connection Screen](../media/readme-keyvault-login.png)
   <br>*Bastion Connection Interface*

> [!NOTE]
> The Data Science VM accessed through Bastion is intended solely for administrators and configuration personnel and is not meant for end-users. It is designed for individuals responsible for configuring, customizing, or updating the solution.

## Internal User Access

After deploying GPT-RAG, you may want to configure additional network settings to allow secure access for internal users. You can achieve this by setting up one of two network configurations designed for internal connectivity.

1. **VNet Peering:**  
   Connects your internal network to the GPT-RAG VNet, allowing users to access services through existing Private Endpoints.

2. **Private Endpoints:**  
   Create Private Endpoints within a VNet that your internal users already use, such as a Hub VNet, enabling secure access without the need for VNet peering.

Choose the option that best fits your network setup and security requirements.

### Configuring VNet Peering

Establish VNet Peering to enable secure and efficient communication between virtual networks for users connected through ExpressRoute or VPN. This setup ensures that internal users can securely access your **App Service**, **Storage Accounts**, and **Search Service**

The following diagram illustrates a scenario using VNet Peering to allow internal users to access the application, along with a DNS configuration based on Azure DNS Private Resolver. This setup ensures that devices on the private network can resolve the Private Endpoints associated with the services.

![Diagram illustrating VNet Peering](../media/admin-guide-vnet-peering-diagram.png)
<br>*VNet Peering*

To simplify, the diagram only includes the App Service frontend’s Private Endpoint and DNS configuration **azurewebsites.net**. Uploading documents requires DNS setup for the Storage Account **blob.core.windows.net**, and reindexing the AI Search index needs DNS configuration for the search service domain **search.windows.net**.

#### Pre-requisites

- **Azure Permissions:**
  - **Network Contributor** role or higher on both virtual networks involved in the peering.

- **Network Configuration:**
  - Ensure that the virtual networks do not have overlapping IP address spaces.
  - Both virtual networks must reside within the same Azure region or in regions that support peering.

#### Procedure

For step-by-step configuration instructions, refer to the [Create a VNet Peering Procedure](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering?tabs=peering-portal).

VNet Peering will enable connectivity with your Private Endpoint. However, to configure name resolution for the Private Endpoint address, DNS settings must be adjusted according to the Private Endpoint DNS Integration Scenarios you intend to use. For more information on scenarios and how to configure them, please see [Private Endpoint DNS Integration Scenarios](https://github.com/dmauser/PrivateLink/tree/master/DNS-Integration-Scenarios).

### Configuring Private Endpoints

Implement Private Endpoints for your **App Service**, **Storage Accounts**, and **Search Service** to ensure secure, direct access for users connected through ExpressRoute or VPN. This setup offers an alternative to VNet Peering by allowing these Private Endpoints to reside in your Connectivity subscription. As a result, DNS will resolve directly to these Private Endpoints, eliminating the need for VNet Peering.

The following diagram illustrates a scenario using Private Endpoints within your Connectivity subscription and a DNS configuration based on Azure DNS Private Resolver. This ensures that devices on the private network can resolve the Private Endpoints associated with the services.

![Diagram illustrating Private Endpoints](../media/admin-guide-private-endpoints-diagram.png)  
<br>*Private Endpoints in Your Connectivity Subscription*

To keep things simple, the diagram only includes the Private Endpoint and DNS setup for the App Service that runs the application's frontend using azurewebsites.net. If users need to upload documents, you'll also need to configure DNS for the Storage Account service at blob.core.windows.net. Additionally, if there's a need to reindex the AI Search index, you'll have to set up DNS for the search service domain at search.windows.net.

#### Pre-requisites

- **Azure Permissions:**
  - **Network Contributor** or **Private Endpoint Contributor** role on the virtual network where the Private Endpoint will be deployed.
  - **Contributor** role or higher on the App Service and Storage Account resources.

- **Network Configuration:**
  - Ensure DNS settings are configured to resolve the Private Endpoints correctly.
  - Verify that the virtual network has sufficient IP address space to accommodate the Private Endpoints.

#### Procedure

For detailed configuration guidance for the App Service, see [Connect privately to an App Service app using a Private Endpoint](https://learn.microsoft.com/en-us/azure/app-service/overview-private-endpoint). The steps for creating a Private Endpoint for a Storage Account and Search Service are similar to those for the App Service.

The previous steps explain how to create the Private Endpoint and provide guidance on DNS configuration. If you need more information about DNS integration scenarios with Private Endpoints and how to configure them, please refer to [Private Endpoint DNS Integration Scenarios](https://github.com/dmauser/PrivateLink/tree/master/DNS-Integration-Scenarios).

## External User Access

Provide user access to external users via secure network configurations.

### Configuring Front Door and Web Application Firewall (WAF)

Configure **Azure Front Door** in conjunction with a **Web Application Firewall (WAF)** to manage external user access. This setup provides global load balancing, ensures high availability, and protects the application from common web threats and vulnerabilities.

<!-- ![Diagram illustrating Front Door and WAF](path/to/front-door-waf-diagram.png) -->

#### **Pre-requisites**

- **Azure Permissions:**
  - **Contributor** role or higher on the Azure subscription or the specific resource group where Front Door and WAF will be deployed, in general deployed in a **Connectivity Subscription**.

- **Configuration Requirements:**
  - Custom domain ownership if you plan to use custom domains with Front Door.
  - SSL certificates for securing HTTPS traffic, if applicable.

#### Procedure

To set up Front Door and WAF, follow the instructions in the [Create an Azure Front Door using Azure portal](https://learn.microsoft.com/en-us/azure/frontdoor/create-front-door-portal) page.

> [!NOTE]
> Alternatively, Front Door and WAF can be deployed within the same Subscription and resource group as GPT-RAG to streamline the configuration process.


### Configuring IP Allowlist

With the **Private Endpoint** already set up for **App Service**, you can still configure an IP allowlist for specific cases, such as temporary access to the frontend for quick testing. This setup ensures that only trusted sources with pre-approved IPs can access the service publicly when necessary.

> [!IMPORTANT]  
> Use this approach for short-term access, such as quick testing or setup for a small group of users. It’s a simple control but relies on a public endpoint, so apply it only when necessary for specific cases.

#### **Pre-requisites**

- **Azure Permissions:**
  - **Contributor** role or higher on the Azure subscription or the specific resource group containing the App Service.

- **Network Configuration:**
  - A list of trusted IP addresses or ranges that will be allowed access to the public endpoints.

#### **Procedure**

1. **Access the Azure Portal:**
   - Sign in to the [Azure Portal](https://portal.azure.com).

2. **Restrict Access to App Services:**
   - Navigate to **App Services** and select the target App Service.
   - Go to **Networking** and configure **Access Restrictions** by adding rules to allow specific IP addresses with assigned priorities.
   - Save the changes to enforce the restrictions.

![IP Allowlist and Access Restrictions](../media/admin-guide-ip-allowlist.png)
<br>*Configuring IP Allowlist for Public Endpoints*

#### Validation

- Test access to the App Service and Storage Account from both permitted and non-permitted IP addresses.
- Monitor access logs regularly to ensure only authorized IPs have access.

## Configuring Entra Authentication

This section outlines the steps to configure Azure Entra authentication for Front-end app service.

#### Prerequisites

- The front-end app deployed in App Service.
- Permission to register your application in Entra ID.*

*\* Use one of these Entra roles: **Application Administrator**, **Cloud Application Administrator**, or **Global Administrator**.*

#### Procedure

If you **have the necessary permissions** to register a new application in Azure Entra ID, simply follow step 3 of the procedure outlined on this page: [Add app authentication](https://learn.microsoft.com/en-us/azure/app-service/scenario-secure-app-authentication-app-service?tabs=workforce-configuration#3-configure-authentication-and-authorization) or [watch this brief tutorial](https://youtu.be/sA-an25jMB4) for step-by-step instructions.

If you **do not have permission** to register a new application in Azure Entra ID, that’s not a problem. You can still set up authentication by collaborating with an Entra ID administrator. Simply follow the procedure described on this page: [How to Apply Easy Auth on Web App under a High-security policy environment](https://learn.microsoft.com/en-us/azure/app-service/scenario-secure-app-authentication-app-service?tabs=workforce-configuration#3-configure-authentication-and-authorization).

#### Validation

- Access your web app URL.
- You should be redirected to the Azure AD sign-in page.
- Upon successful login, you should be redirected back to your app.

## Configuring Authorization

Control user access within front-end application using **user principal IDs**, **usernames**, or **groups**.

#### Prerequisites

- **Configured Authentication**: Ensure that Entra ID authentication is properly set up in your app service.
- **List of Authorized Entities**: Compile lists of authorized user principal IDs, usernames and/or group names.
- **Delegated Microsoft Graph Permissions** *(To define allowed groups)*: Permission to consent your application the **Microsoft Graph `Group.Read.All`** permission in Entra ID.

*\* Use one of these Entra roles: **Application Administrator**, **Cloud Application Administrator**, or **Global Administrator**.*

#### Procedure

1. **Identify Authorized Users and Groups**

   - **User Principal IDs**: Unique identifiers for users (e.g., `user-principal-id-1`).
   - **Usernames**: Typically the user's email address (e.g., `user1@example.com`).
   - **Group Names** *(Optional)*: Entra ID group names.

2. **Configure Microsoft Graph Permissions (If you are allowing Access to Groups)**

   If you plan to use group-based authorization:

   - **Navigate to API Permissions**:

     - In the registered application, go to **API permissions**.

   - **Add `Group.Read.All` Permission**:

     - Click **Add a permission** > **Microsoft Graph** > **Application permissions**.
     - Search for and select **`Group.Read.All`**.
     - Click **Add permissions**.

   - **Grant Admin Consent**:

     - Click on **Grant admin consent for [Your Tenant Name]**.
     - Confirm the action.

   ![Configuring Allowed Groups](../media/admin-guide-authorization-consent.png)
   <br>*Example of consenting Microsoft Graph permission*     

3. **Set Environment Variables**

   In your application's settings, populate the environment variables needed to define which users or groups can access the application. You don’t need to create all three—just the ones relevant to your authorization setup:

   - Use `AUTHORIZED_USER_PRINCIPALS` if you want to specify user principal IDs (e.g., `user-principal-id-1`).
   - Use `AUTHORIZED_USER_NAMES` if you want to specify usernames (e.g., `user1@example.com,user2@example.com`).
   - Use `AUTHORIZED_GROUP_NAMES` if you want to specify group names.

   ![Configuring Allowed Groups](../media/admin-guide-authorization-example.png)
   *Example of configuring allowed groups*

4. **Restart the Application**

   After making changes to environment variables and permissions, restart your application to apply the updates.

#### Validation

Based on your authorization setup, validate access:

- **User Principal ID**: Log in as a user in `AUTHORIZED_USER_PRINCIPALS` to check access.
- **Username**: Log in as a username in `AUTHORIZED_USER_NAMES` and confirm access.
- **Group Membership**: Log in as a group member from `AUTHORIZED_GROUP_NAMES` to ensure access.

> [!NOTE]
> Use and test only the methods you have configured to ensure access controls are functioning correctly.

## Setting Up Git Repos

The GPT-RAG Solution Accelerator comprises four Git repositories, each housing the code for specific application components. Whether you're using GitHub, Azure Repos in Azure DevOps, or another Git service, this section outlines the organization of the codebase and provides instructions for integrating it into your own Git repositories. You can incorporate the Solution Accelerator's code into your Git repositories either by using the repositories as templates or by forking and then creating pull requests in case you want to contribute to the GPT-RAG repo.

### Codebase Organization

The Solution Accelerator is structured across four primary Git repositories:

1. **gpt-rag**: The main repository containing Infrastructure as Code (IaC) templates and comprehensive documentation for the Solution Accelerator.
2. **gpt-rag-ingestion**: Manages the Data Ingestion component, optimizing data chunking and indexing for the Retrieval-Augmented Generation (RAG) retrieval step.
3. **gpt-rag-agentic**: Serves as the orchestrator, coordinating the flow to retrieve information and generate user responses using agents.
4. **gpt-rag-frontend**: Provides the front-end application, delivering a scalable and efficient web interface for the Solution Accelerator.

### Option 1: Using Repositories as Templates (Most Common)

If you'd like to use the repositories as a starting point without making updates to the original, you can use GitHub's template feature. This will create an independent copy of the repository, which you can fully customize. However, keep in mind that this option won’t automatically sync with future updates from the original repository.

> [!NOTE]
> The following steps should be performed for each of the four Solution Accelerator repositories: **gpt-rag**, **gpt-rag-ingestion**, **gpt-rag-agentic**, and **gpt-rag-frontend**.

#### Option 1.1: Setting Up GitHub Repositories

In this case we will use GitHub's template feature to create a copy of the repository.

**Prerequisites**

  - **Read Access** to the template repositories.
  - **Create Repository** permission in your account or organization.

**Procedure**

1. **Navigate to the Repository:**
   - Visit the GitHub page of the repository you wish to use as a template (e.g., [gpt-rag-agentic](https://github.com/Azure/gpt-rag-agentic)).

2. **Use as Template:**
   - Click the **Use this template** button located above the repository files.
   - In the dialog that appears, enter your new repository name, select the owner (your account or organization), and choose the visibility (public or private).

3. **Create Repository:**
   - Click **Create repository from template**. GitHub will generate a new repository in your account with the contents of the template repository.

#### Option 1.2: Importing Repositories into Azure Repos (Azure DevOps)

**Prerequisites**

   - **Access to Azure DevOps Organization and Project.**
   - **Repository Creation Rights** within the target project.

**Procedure**

1. **Prepare Azure DevOps Project:**
   - Ensure you have an Azure DevOps organization with the necessary permissions, typically as a Project Administrator or with explicit repository creation rights.

2. **Access Azure Repos:**
   - Navigate to your Azure DevOps project.
   - Go to **Repos** > **Files**.

3. **Import Repository:**
   - Click the **Import a repository** button.
   - In the import dialog, enter the **Clone URL** of the GitHub repository you wish to import (e.g., `https://github.com/Azure/gpt-rag-agentic.git`).

4. **Authentication for Private Repositories:**
   - If importing a private repository, provide the necessary credentials, such as a Personal Access Token (PAT), to authorize the import.

5. **Start Import:**
   - Click **Import** to begin the process. Azure DevOps will clone the repository into your Azure Repos.

6. **Verify Import:**
   - Once the import is complete, verify that the repository and its branches have been correctly imported by browsing the files in Azure Repos.

**Reference:**
For detailed instructions and advanced import scenarios, refer to the [Importing a GitHub repository into Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/repos/git/import-git-repository) documentation.

#### Option 1.3: Using a different Git service

**Procedure**

1. **Create a New Repository:**
   - Set up a new repository on your preferred Git service (e.g., GitLab, Bitbucket).

2. **Download and Extract:**
   - Download the repository as a ZIP file from GitHub, extract the contents to your local machine.

3. **Add to Your Git Repository:**
   - Initialize your local repository, add the extracted files, commit, and push them to your Git service.

4. **Customize:**
   - Modify the code as per your requirements and push updates to your repository.

### Option 2: Contributing by Forking and Creating Pull Requests

If you intend to contribute to the ongoing development of the Solution Accelerator by submitting pull requests, please refer to our [Contribution Guidelines](https://github.com/Azure/GPT-RAG/blob/main/CONTRIBUTING.md#contribution-guidelines) for detailed instructions on how to fork repositories and create pull requests.

## Troubleshooting

Refer to the [Troubleshooting Guide](TROUBLESHOOTING.md) for common issues and resolutions related to the GPT-RAG Solution Accelerator.
