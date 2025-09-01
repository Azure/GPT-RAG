# Changelog

All notable changes to this project will be documented in this file.  
This format follows [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

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
