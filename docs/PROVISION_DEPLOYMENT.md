## Provisioning and Deployment Process Concepts

The **Provisioning and Deployment** processes in this project are designed to be automated using **Bicep templates** and the **Azure Developer CLI (azd)**, ensuring a consistent, secure, and efficient setup of all Azure resources in alignment with Zero Trust principles. 

This article describes a fully automated scenario, but it is important to note that specific steps can be performed manually if needed. The solution deployment page provides a detailed step-by-step guide for installation, including cases where customization or manual processes are required. [Learn more here](https://github.com/Azure/GPT-RAG/blob/main/docs/GUIDE.md#deploying-the-solution-accelerator).

### Provisioning with Bicep Templates

**Bicep** serves as the foundation for defining the infrastructure as code (IaC). The `main.bicep` file is the entry point, orchestrating the deployment of various Azure resources through a modular approach:

1. **Parameter Configuration:**
   - **Environment Parameters:** Parameters such as `environmentName`, `location`, and `resourceGroupName` tailor the deployment to specific environments.
   - **Reuse Configuration:** The `azureReuseConfig` object allows for the reuse of existing resources, reducing redundancy and optimizing resource management.

2. **Resource Group Creation:**
   - A resource group is provisioned to act as a container for all other resources. Tags are applied for organizational purposes, ensuring resources are easily identifiable and manageable.

3. **Networking Setup:**
    - **Virtual Network (VNet):** When network isolation is enabled by setting `AZURE_NETWORK_ISOLATION` to `true`, a VNet is automatically created with predefined subnets for AI services, application integration, app services, databases, and Bastion. While this setup is designed for automation, it is also possible to configure specific components manually if needed.
   - **Private DNS Zones:** To facilitate secure and private communication between services within the VNet.
   - **Private Endpoints:** Secure connections are set up for services like Storage, Cosmos DB, Key Vault, OpenAI, and Search, ensuring that traffic remains within the Azure backbone network.

4. **Security Services:**
   - **Key Vault:** Securely stores and manages secrets used by GPT-RAG services.
   - **Managed Identities:** System-assigned identities are created for services like the orchestrator and data ingestion functions, enabling secure access to other Azure resources without embedding credentials.
   - **Role Assignments:** Specific roles are assigned to various services to grant the necessary permissions. Examples include:
     - **Cognitive Services Contributor** for Data Ingestion and Frontend to enable AI functionalities.
     - **Search Index Data Contributor** for Data Ingestion to allow indexing in Azure AI Search.
     - **Cosmos DB Built-in Data Contributor** for Orchestrator to manage conversation history.
     - **Key Vault** policies or roles for secure secret access.
     - **Storage Blob** roles for data read/write operations.

5. **Compute Resources:**
   - **App Service Plan:** Defines the hosting environment for frontend, data ingestion and orchestrator services.
   - **Function Apps:** Deployed for orchestrator and data ingestion to handle business logic and data processing.
   - **Virtual Machines:** Optionally provisioned for secure administrative access via Bastion.

6. **Storage and Databases:**
   - **Azure Storage Accounts:** Configured with containers for documents, images, and deployment packages, with appropriate access policies.
   - **Cosmos DB:** Stores conversation history and metadata, enabling insights that help improve service quality and optimize future interactions.

7. **AI and Search Services:**
   - **Azure OpenAI:** Configured with specified models and deployments to handle natural language processing tasks.
   - **Azure AI Search:** Indexed to enable efficient data retrieval and search capabilities (e.g., hybrid or vector-based retrieval).

8. **Load Testing (Optional):**
   - Provisioned based on configuration to ensure the solution can handle expected traffic and usage patterns.

### Role Assignments in Bicep

The Bicep templates include role assignments to ensure each service can perform its tasks securely:

| **Service**                           | **Role Assignment**                                 | **Assigned To**                   | **Description**                                                              |
|---------------------------------------|---------------------------------------------------|-----------------------------------|------------------------------------------------------------------------------|
| **AI Services**                        | Cognitive Services Contributor                    | Data Ingestion Function App       | Enables Document Intelligence features for data ingestion.                   |
| **AI Services**                        | Cognitive Services Contributor                    | Frontend App Service              | Grants access to Speech Service (optional).                                  |
| **Azure AI Search**                     | Search Index Data Contributor                     | Data Ingestion Function App       | Allows indexing of data in Azure AI Search.                                  |
| **Azure AI Search**                     | Search Index Data Reader                          | Orchestrator Function App         | Provides read access to the search index.                                    |
| **Azure OpenAI**                         | Cognitive Services OpenAI User                    | Azure AI Search                   | Enables OpenAI capabilities for Azure AI Search.                             |
| **Azure OpenAI**                         | Cognitive Services OpenAI User                    | Data Ingestion Function App       | Grants access to OpenAI capabilities for data ingestion.                     |
| **Azure OpenAI**                         | Cognitive Services OpenAI User                    | Orchestrator Function App         | Allows the orchestrator to use OpenAI services.                              |
| **Cosmos DB**                            | Cosmos DB Built-in Data Contributor               | Orchestrator Function App         | Grants data contribution permissions to Cosmos DB.                           |
| **Key Vault**                            | Key Vault Secrets User / Access Policies          | Data Ingestion Function App       | Provides access to secrets in Key Vault.                                     |
| **Key Vault**                            | Key Vault Secrets User / Access Policies          | Orchestrator Function App         | Provides access to secrets in Key Vault.                                     |
| **Orchestrator Function App**            | Contributor                                       | Frontend App Service              | Grants interaction permissions with the orchestrator.                        |
| **Storage Account (Data Ingestion)**     | Storage Blob Data Contributor                     | Data Ingestion Function App       | Grants read/write access to the storage account.                             |
| **Storage Account (Orchestrator)**       | Storage Blob Data Contributor                     | Orchestrator Function App         | Grants read/write access to the storage account.                             |
| **Storage Account (Source Docs)**        | Storage Blob Data Contributor                     | Data Ingestion Function App       | Enables writing to the storage account for image extraction in multimodal scenario. |
| **Storage Account (Source Docs)**        | Storage Blob Data Reader                          | Frontend App Service              | Provides read access to the storage account.                                 |
| **Storage Account (Source Docs)**        | Storage Blob Data Reader                          | Azure AI Search                   | Grants read access to search service.                                        |
| **Storage Account (Source Docs)**        | Storage Blob Data Reader                          | Orchestrator Function App         | Allows reading source documents from the storage account.                    |


### Azure Developer CLI (azd)

The **Azure Developer CLI (azd)** simplifies the development, provisioning, and deployment of Azure applications. It integrates with Bicep templates for efficient infrastructure management and automates deployment workflows. In this project, azd is used to streamline resource provisioning, configuration management, and service integration, improving productivity and minimizing manual effort.

### Integration with `main.bicep`

The `main.bicep` file orchestrates the deployment of all Azure resources through a modular approach.

**Key aspects include:**

- **Parameter Definitions:** Configurable variables are defined in the `main.parameters.json` file and can be set using the `azd env set VARIABLE_NAME VARIABLE_VALUE` command before you run azd provision. This allows customization of parameters such as environment name, location, and resource group name. For example, to define or update an AI Search Index name, use:

    ```bash
    azd env set AZURE_SEARCH_INDEX ragindex
    ```

    This ensures that parameters are easily configurable, maintaining flexibility in resource deployment.

- **Resource Modules:** Imports and deploys modular Bicep files for networking, security, compute, storage, AI services, and more. This modularity promotes reusability and simplifies the management of complex infrastructure.

- **Role Assignments:** Grants specific permissions (e.g., Cognitive Services Contributor, Search Index Data Contributor) to each service, ensuring least-privilege access. This enhances security by limiting access to only what each service requires.

- **Conditional Deployments:** Utilizes parameters to conditionally deploy resources, such as enabling network isolation or reusing existing resources. This allows for dynamic and adaptable infrastructure setups based on the defined parameters.

- **Output Definitions:** Provides information about deployed resources (e.g., account names, endpoints) to support integration with other services or scripts. These outputs facilitate seamless interoperability and automation across different components of your infrastructure.

### Provision and Deploy Workflow

The deployment process is managed using the **Azure Developer CLI (azd)**, which orchestrates the workflow in two main stages:

1. **Provision Stage**
2. **Deploy Stage**

Each stage involves executing specific hooks and deploying resources or services accordingly.

---

### 1. Provision Stage

**Command:** `azd provision`

**Purpose:** Sets up the necessary Azure infrastructure as defined in the project’s resource templates.

**Process:**

1. **Global Preprovision Hooks:**
   - **Scripts Executed:** `preprovision.sh` or `preprovision.ps1`
   - **Function:** Perform initial setup tasks required before deploying resources, such as validating configurations or setting environment variables.
   - **Scope:** Executed **once globally** before any resources are deployed.

2. **Resource Deployment:**
   - **Tools Used:** Deploys all Azure resources using `main.bicep`.
   - **Function:** Creates the necessary infrastructure components (e.g., databases, storage accounts, networking resources).

3. **Global Postprovision Hooks:**
   - **Scripts Executed:** `postprovision.sh` or `postprovision.ps1`
   - **Function:** Finalize configurations after resource deployment, such as configuring resource-specific settings or initializing services.
   - **Scope:** Executed **once globally** after all resources have been deployed.

---

### 2. Deploy Stage

**Command:** `azd deploy`

**Purpose:** Deploys individual services within the provisioned infrastructure, handling service-specific configurations and integrations.

**Process:**

1. **Global Predeploy Hooks:**
   - **Scripts Executed:** `preDeploy.sh` or `preDeploy.ps1`
   - **Additional Scripts:** `scripts/fetchComponents.sh` or `scripts/fetchComponents.ps1`
   - **Function:** Perform tasks that need to be completed before deploying any service, such as pulling necessary components from repositories.
   - **Scope:** Executed **once globally** before deploying any individual services.

2. **Service Deployments:**
   
   Each service undergoes its specific deployment process, which may include service-specific hooks:

   - **a. Data Ingestion Service:**
     - **Deployment:** Deploys the Data Ingestion Function App.
     - **Postdeploy Hooks:**
       - **Function:** Configures Azure AI Search components like indexers and indexes.
       - **Scripts:** Custom scripts or commands specific to Azure AI Search configuration.

   - **b. Orchestrator Service:**
     - **Deployment:** Deploys the Orchestrator Function App.
     - **Configurations:**
       - Sets up necessary integrations with other services.
       - Configures permissions and access controls.

   - **c. Frontend Service:**
     - **Prepackage Hooks:**
       - **Tasks:** Builds the frontend application using commands like `npm install` and `npm run build`.
     - **Deployment:** Deploys the Frontend App Service.
     - **Postdeploy Hooks:**
       - **Function:** Cleans up temporary artifacts, including removing fetched repositories to maintain a clean deployment environment.

   **Note:** Service-specific hooks are executed **only for their respective services** and are not part of the global hook executions.

3. **Global Postdeploy Hooks:**
   - **Scripts Executed:** `cleanComponents.sh` or `cleanComponents.ps1`
   - **Function:** Cleans up any remaining fetched repositories and finalizes deployment tasks to ensure the environment is tidy and secure.
   - **Scope:** Executed **once globally** after all individual services have been deployed.
