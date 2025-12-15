# Changelog

All notable changes to this project will be documented in this file.  
This format follows [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [v2.3.0] – 2025-12-15
### Added
- Support for **SharePoint Lists** in the ingestion component.
- Refactored **Single Agent Strategy** to simplify citation handling. [#161]
- Simplified **MCP Strategy**. [#159]
### Changed
- Improved robustness of **Blob Storage indexing** in the ingestion pipeline.
- Enhanced **data ingestion logging** for better observability and troubleshooting.
### Tested
- Compatibility with **Azure direct models for inference** in the orchestration layer.

## [v2.2.6] – 2025-12-05
### Fixed
- Fixed Issue [#409](https://github.com/Azure/GPT-RAG/issues/409) by updating the main Bicep template to ensure the `SEARCH_CONNECTION_ID` app setting points to the correct AI Search connection ID. It was previously pointing to the AI Foundry AI Search dependency.

## [v2.2.5] – 2025-12-02
### Fixed
- Fixed Issue [#406](https://github.com/Azure/GPT-RAG/issues/406) by updating networking and private endpoint configuration to prevent the `cosmos_vnet_blocked` error in Cosmos DB private-only setups.
### Changed
- Automated the creation and registration of the Azure AI Search connection, removing the need for the previous manual workaround.

## [v2.2.4] – 2025-11-26
### Fixed
- Fixed a bug in data ingestion component where the Blob storage ingestion process was re-indexing unchanged files when AI Search index had more than 1,000 chunks. Fixed in gpt-rag-ingestion v2.0.6.
### Changed
- Small update in `scripts/postProvision.sh` to make the Container Apps API Key check more robust by always converting the `USE_CAPP_API_KEY` variable to lowercase, even when it is unset.


## [v2.2.3] – 2025-11-15
### Fixed
- Intermittent AI Foundry post provisioning setup authentication timeout by increasing `AzureCliCredential` and `ManagedIdentityCredential` process timeout to 30 seconds in `config/aifoundry/setup.py`
- Compatibility with older AZD versions by removing string interpolation syntax from capability host connection arrays in AI Foundry project module (infra/modules/ai-foundry/modules/project/main.bicep lines 229-231)
### Changed
- Suppressed BCP081 warnings for future-dated API versions (2025-01-01, 2025-04-01, 2025-05-01, 2025-06-01) in AI Foundry project module by adding #disable-next-line directives
- Improved PR and Issue templates
- Moved documentation to https://aka.ms/gpt-rag-docs
- Bumped **gpt-rag-mcp** to **v0.2.3**

## [v2.2.2] – 2025-11-09
### Changed
- Updated infra templates to create the **data** private endpoint for Azure Container Registry when in network isolation mode.
- Updated Bastion configuration to retrieve credentials from Key Vault. Users can now simply reset the `testvmuser` password to access the VM for the first time.

## [v2.2.1] – 2025-10-21
### Added
- Added more troubleshooting logs.
### Fixed
- Citations [387](https://github.com/Azure/GPT-RAG/issues/387)

## [v2.2.0] – 2025-10-16
### Added
- Bring your own VNet. [#370](https://github.com/Azure/GPT-RAG/issues/370).
- Agentic Retrieval. [#359](https://github.com/Azure/GPT-RAG/issues/359).

### Fixed
- Citation links opens up new chat windows instead of rendering files [#387](https://github.com/Azure/GPT-RAG/issues/387)
## [v2.1.2] – 2025-10-02
### Changed
- Fixed a bug in data ingestion component where the SharePoint ingestion process was unnecessarily re-indexing unchanged files.

## [v2.1.1] – 2025-09-22
### Changed
- Limit `azd` environment variables to the script process (no longer persisted to the user profile) to reduce secret exposure. Resolves [#378](https://github.com/Azure/GPT-RAG/issues/378).
- Streamline AI Search provisioning: now creates **only** the AI Search index. Previously we also created indexers, skillsets, and data sources that are no longer used and caused confusion about expected runtime behavior. Indexing is performed by the `gpt-rag-ingestion` jobs — see the ingestion docs for how to run, schedule, or troubleshoot ingest jobs. Resolves [#377](https://github.com/Azure/GPT-RAG/issues/377).

## [v2.1.0] – 2025-08-31
### Added
- **User Feedback Loop**. [#358](https://github.com/Azure/GPT-RAG/issues/358). **[Documentation](https://github.com/Azure/GPT-RAG/blob/release/2.1.0/docs/GUIDE.md#configuring-user-feedback-loop)**.

### Changed
- Standardized resource group variable as `AZURE_RESOURCE_GROUP`. [#365](https://github.com/Azure/GPT-RAG/issues/365)

## [v2.0.5] - 2025-08-26
### Fixed
- Resolved VM deployment errors when using CustomScriptExtension under network isolation.

## [v2.0.4] - 2025-08-21
### Added
- Updated orchestrator to version 2.0.3, which includes NL2SQL docs and improved settings checks.

## [v2.0.3] - 2025-08-19
### Fixed
- Resolved issue with using Azure Container Apps under a private endpoint in AI Search as a custom web skill.
### Added 
- Blob Storage Data Source Ingestion.
- NL2SQL Metadata Ingestion from Blob Storage.

## [v2.0.2] - 2025-08-08
### Changed
- Updated deployment documentation.

## [v2.0.1]
### Changed
- Updated deployment documentation.

### Fixed
- Resolved deployment issues introduced in v2.0.0.

## [v2.0.0] - 2025-07-15
### Changed
- Major architecture refactor to support the vNext architecture.
