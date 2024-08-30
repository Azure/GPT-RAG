
# Change Log
All notable changes to this project will be documented in this file.
 
## Changelog

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