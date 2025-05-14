
# Change Log
All notable changes to this project will be documented in this file.
 
## Changelog

### 2025-05-14

- **Added**: Application Configuration support
- **Added**: Azure Container Apps (ACA) support
- **Added**: Azure Kubernetes (AKS) support
- **Added**: Model Context Protocol (MPC) support
- **Added**: Bring your own Resource Group for Virtual Network
- **Added**: Bicep parameters:
  - `AZURE_USE_ACA` (true|false) - Will enable deployment of ACA infrastructure
  - `AZURE_USE_AKS` (true|false) - Will enable deployment of AKS infrastructure
  - `INSTALL_KEDA` (true|false) - When used with AKS, will install KEDA (for function scaling)
  - `AZURE_USE_MCP` (true|false) - Will deploy the function app/ACA/AKS compute to support MCP server deployment
  - `AZURE_USE_AGENTIC` (true|false) - Will switch the orchestrator func/container to use the Basic Orchestrator or Agentic repo
  - `REPOSITORY_URL` (docker.io, acr registry) - Will default to using this repo for container deployment for ACA/AKS
  - `AZURE_TLS_CERTIFCATE_NAME` (TLS Certificat in Key Vault) - The TLS/SSL certificate used in AKS custom domain DNS deployment.

**BREAKING CHANGES**

- Naming convention of resources was changed to map to the recommended Azure naming best practices (Note the `infra\abbreviations.json` file).
- Extra permissions are needed in the custom role to support AppConfig, Container Registry, ACA and AKS
- Code in supporting repos (Agentic, Orchestrator, Ingestion, Mcp) has been refactored to suport Docker containerization.

### 2024-06-15
- **Added**: Option to install just some specific GPT-RAG components: data ingestion, orchestrator and frontend.

### 2024-06-10
- **Added**: Optional Reuse of Pre-Created Resources: You can now optionally reuse existing resources such as VNets, Azure OpenAI instances, etc.
- **Added**: Use five subnets to align with the idealized architecture.
- **Added**: Custom Addressing to allow specifying custom addressing for VNets and subnets, providing greater flexibility in network configuration.
- **Added**: AI Integration Hub to leverage the power of various external data sources to enhance its capabilities. Currently, we have integrated the following products:
    - **AI Search**: Enables access to vast online databases, providing precise and up-to-date information.
    - **Bing Custom Services**: Customizes search results for specific business needs, ensuring relevance and quality.
    - **SQL Service**: Queries extensive internal databases for accurate and current organizational data, performing analytical functions like count, sum, average, and more.
    - **Teradata**: Integrates large-scale data warehousing capabilities, enhancing data retrieval and analysis.

### 2024-05-22
- **Added**: AOAI content filtering and blocklist configuration.
- **Changed**: Changed sample documents and test dataset.

### 2024-04-15
- **Added**: Load testing.
- **Changed**: Increased Zero Trust VM SKU to 4vCPU and 16GB.

### 2024-03-18
- **Added**: Blob storage data source soft deletion support.
- **Changed**: Disabled blob anonymous access.
- **Changed**: AI Search API version defaults to 2023-10-01-Preview for indexProjections and MIS authResourceId support.