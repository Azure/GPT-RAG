# Changelog

All notable changes to this project will be documented in this file.  
This format follows [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

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
- Fixed a bug in daa ingestion component where the SharePoint ingestion process was unnecessarily re-indexing unchanged files.

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
