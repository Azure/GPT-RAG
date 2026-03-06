## Solution Overview

**GPT-RAG** is an enterprise-grade Retrieval-Augmented Generation (RAG) solution accelerator on Azure. It follows a multi-repo architecture with this repository (`Azure/gpt-rag`) serving as the **platform and configuration core**, while four runtime component repositories handle orchestration, data ingestion, user interface, and MCP tool hosting.

- **Documentation**: [azure.github.io/GPT-RAG](https://azure.github.io/GPT-RAG/)
- **Current Release**: v2.5.1 (manifest-defined component versions below)

---

## Key Features

| Feature | Description | Since |
|---|---|---|
| **RAG Retrieval** | Vector + keyword hybrid search via Azure AI Search with text and image embeddings. | v1.0 |
| **NL2SQL** | Natural language to SQL queries against structured databases, with dedicated indexer and orchestration plugin. | v1.0 |
| **Agentic Retrieval** | Agent-driven dynamic retrieval that selects and combines information sources for context-aware responses. | v2.2.0 |
| **Multi-Agent Workflows** | Semantic Kernel strategy pattern coordinating specialized agents (RAG, NL2SQL, MCP) per query. | v2.0 |
| **MCP Tool Hosting** | Model Context Protocol server exposing custom tools, resources, and prompts to the orchestrator. | v2.0 |
| **Multimodal Ingestion** | Processes PDFs, images, spreadsheets, transcripts, and Office documents with text + image embeddings. | v2.0 |
| **SharePoint Integration** | Ingests both SharePoint Online document libraries and generic lists via Microsoft Graph API. | v2.3.0 |
| **Azure Direct Models** | Use Microsoft Foundry "Direct from Azure" models (Mistral, DeepSeek, Grok, Llama) via Foundry inference APIs. | v2.3.0 |
| **User Feedback Loop** | Thumbs-up/down feedback on responses, stored in Cosmos DB alongside conversation history. | v2.1.0 |
| **Authentication & RBAC** | Microsoft Entra ID authentication with document-level authorization and ACL/RBAC enforcement in Azure AI Search. | v2.4.0 |
| **Bring Your Own VNet** | Deploy within existing virtual networks, maintaining full control over network boundaries and routing. | v2.2.0 |
| **Zero Trust Network Isolation** | Optional hardened network posture with private endpoints and guarded provisioning flow. | v2.0 |
| **Responsible AI** | Content safety blocklists and RAI policies applied to model deployments via AI Foundry. | v2.0 |
| **Customizable UI** | Chainlit-based conversational interface with theme, CSS, and layout customization. | v2.0 |

---

## Technical Stack

### Core Technologies

#### Foundation
- **Python 3.x**: Automation and Azure configuration scripts.
- **PowerShell + Bash**: Cross-platform provisioning and deployment hooks.
- **Azure Developer CLI (azd)**: Primary orchestration for infrastructure lifecycle.
- **Bicep**: Infrastructure as Code provider (`infra` module in `azure.yaml`).

#### Python Dependencies (`config/requirements.txt`)
- **azure-identity 1.21.0**: Azure authentication for scripts.
- **azure-appconfiguration 1.7.1**: Centralized configuration retrieval.
- **azure-mgmt-appcontainers 3.2.0**: Container Apps management.
- **azure-mgmt-cognitiveservices 13.6.0**: AI Foundry/OpenAI management operations.
- **azure-keyvault-secrets 4.9.0**: Key Vault secret operations.
- **requests 2.32.4**: REST calls to Azure AI Search APIs.
- **jinja2 3.1.6**: Templated Azure AI Search definitions.

#### Utility CLI Dependencies (`util/requirements.txt`)
- **click 8.2.1**: CLI UX.
- **tabulate >=0.9.0**: Table output formatting.
- **azure-identity 1.23.0**: Credential chain for utility checks.
- **azure-mgmt-resource 24.0.0**: Resource provider checks.
- **azure-mgmt-cosmosdb 9.8.0**: Cosmos DB region/provisioning validation.
- **azure-mgmt-cognitiveservices 13.6.0**: Azure OpenAI usage checks.

### Azure Services in Scope

- **Azure AI Foundry / Azure OpenAI**: Model deployments and RAI configuration.
- **Azure AI Search**: Datasources, indexes, skillsets, and indexers provisioning.
- **Azure App Configuration**: Runtime and deployment metadata source of truth.
- **Azure Key Vault**: Secret management (including evaluation API key flows).
- **Azure Container Apps + ACR**: Runtime hosting and image pull configuration.
- **Azure Cosmos DB**: Conversation/data containers for RAG workloads.
- **Azure Monitor / App Insights / Log Analytics**: Observability components.

### Deployment & Automation Model

- **`azd provision` hooks**:
  - `scripts/preProvision.(ps1|sh)` initializes `infra` submodule and applies local overrides.
  - `scripts/postProvision.(ps1|sh)` installs Python deps and runs:
    - `python -m config.aifoundry.setup`
    - `python -m config.containerapps.setup`
    - `python -m config.search.setup`
- **`azd deploy` hook**:
  - `scripts/preDeploy.ps1` validates environment, reads `manifest.json`, clones component repos, and runs each component deploy script.

---

## Component Repositories

This repository acts as the **platform/configuration core**. Runtime application components are declared in `manifest.json` and deployed as sibling repos. Current manifest versions (v2.5.1 release):

| Component | Repository | Version | Container App |
|---|---|---|---|
| Orchestrator | `Azure/gpt-rag-orchestrator` | v2.4.2 | `orchestrator` |
| Data Ingestion | `Azure/gpt-rag-ingestion` | v2.2.3 | `dataingest` |
| Web UI | `Azure/gpt-rag-ui` | v2.2.2 | `frontend` |
| MCP Server | `Azure/gpt-rag-mcp` | v0.3.5 | `mcp` |

`preDeploy` resolves tag/branch from the manifest, clones each component, reuses `.azure` environment settings, and invokes each component's `scripts/deploy.ps1`.

### gpt-rag-orchestrator

Extensible agentic orchestration layer that coordinates specialized agents to generate context-aware responses. The architecture is built around an **extensible strategy pattern**: each agent strategy is a self-contained class that extends `BaseAgentStrategy` (ABC) and can use **any AI framework or SDK** under the hood. A factory (`AgentStrategyFactory`) selects the active strategy at runtime based on the `AGENT_STRATEGY` configuration key, making it straightforward to add custom strategies without modifying existing code.

**Built-in Strategies and Their Frameworks**:

| Strategy Key | Class | Framework / SDK | Description |
|---|---|---|---|
| `single_agent_rag` | `SingleAgentRAGStrategyV1` | **Azure AI Foundry Agent Service** (`azure.ai.agents`) | Single-agent RAG with function-calling tools (AI Search retrieval, Bing Grounding). Creates agents, threads, and streams responses via the Foundry Agent API. |
| `nl2sql` | `NL2SQLStrategy` | **Semantic Kernel Agents** (`AzureAIAgent` + `AgentGroupChat`) | Multi-agent workflow with Triage, SQL Query, and Synthesizer agents coordinated via Semantic Kernel's group chat and termination strategies. |
| `mcp` | `McpStrategy` | **Semantic Kernel** (`ChatCompletionAgent` + `MCPSsePlugin`) | Connects to an external MCP server via SSE, dynamically discovering and invoking tools exposed by the MCP protocol. |

The `AgentStrategies` enum also defines placeholder keys for future strategies (`multiagent`, `multimodal`), making the framework ready for extension.

**Extensibility**: To create a custom strategy, implement a class that extends `BaseAgentStrategy`, override the `initiate_agent_flow()` method with your orchestration logic (using any framework — Semantic Kernel, LangChain, AutoGen, or direct API calls), register it in the `AgentStrategies` enum and `AgentStrategyFactory`, and set the `AGENT_STRATEGY` config key to activate it.

**Key Capabilities**:
- Extensible strategy pattern — each strategy independently chooses its AI framework
- Factory-based runtime agent selection via `AGENT_STRATEGY` config key
- Semantic Kernel plugins for retrieval, NL2SQL, and common operations
- Prompt template management (file-based with Jinja2 or Cosmos DB-backed)
- OAuth 2.0 user identity validation and RBAC-based access control
- Document-level authorization propagation to Azure AI Search
- Azure Direct Models support (Mistral, DeepSeek, Grok, Llama)
- OpenTelemetry-based observability

**Languages**: Python 80.5%, PowerShell 14.8%, Shell 2.4%, Jinja 1.2%

**Repository Structure**:
```
📁 src/
├── 📁 connectors/               # External service connectors
├── 📁 orchestration/            # Core orchestration logic
├── 📁 plugins/                  # Semantic Kernel plugins
│   ├── 📁 common/              # Shared plugin utilities
│   ├── 📁 nl2sql/              # Natural language to SQL plugin
│   └── 📁 retrieval/           # RAG retrieval plugin
├── 📁 prompts/                  # Agent prompt templates (txt + Jinja2)
├── 📁 strategies/               # Agent strategy implementations
│   ├── 📄 agent_strategies.py         # Strategy enum (single_agent_rag, nl2sql, mcp, multiagent, multimodal)
│   ├── 📄 agent_strategy_factory.py   # Factory for selecting strategy at runtime
│   ├── 📄 base_agent_strategy.py      # Abstract base — extend this to add custom strategies
│   ├── 📄 single_agent_rag_strategy.py  # RAG strategy (Azure AI Foundry Agent Service)
│   ├── 📄 nl2sql_strategy.py           # NL2SQL multi-agent strategy (Semantic Kernel Agents)
│   └── 📄 mcp_strategy.py              # MCP tool-calling strategy (Semantic Kernel + MCP)
├── 📁 telemetry/                # Observability integration
├── 📁 util/                     # Shared utilities
├── 📄 main.py                   # FastAPI application entry point
├── 📄 dependencies.py           # Dependency injection
├── 📄 schemas.py                # Request/response models
└── 📄 constants.py              # Configuration constants
📁 evaluations/                  # Evaluation scripts and datasets
📁 notebooks/                    # Jupyter notebooks for experimentation
📁 samples/                      # Sample configurations
📁 scripts/                      # Deployment scripts (deploy.ps1/deploy.sh)
📁 tests/                        # Test suite
```

### gpt-rag-ingestion

Automates processing of diverse document types—PDFs, images, spreadsheets, transcripts, and SharePoint files—preparing them for indexing in **Azure AI Search**. Uses intelligent chunking strategies tailored to each format, generates text and image embeddings, and enables rich multimodal retrieval.

**Key Capabilities**:
- Smart chunking with format-specific strategies (factory pattern)
- Text and image embedding generation via Azure OpenAI
- Blob Storage document indexing
- SharePoint indexing (document libraries + generic lists via Graph API)
- NL2SQL schema indexing and maintenance
- Multimodal image processing and lifecycle management
- Azure Document Intelligence integration for content extraction

**Languages**: Python 95.6%

**Repository Structure**:
```
📁 chunking/                         # Document chunking engine
├── 📁 chunkers/                    # Format-specific chunker implementations
├── 📄 chunker_factory.py           # Factory for selecting chunker by format
├── 📄 document_chunking.py         # Core chunking orchestration
└── 📄 exceptions.py                # Chunking-specific exceptions
📁 jobs/                             # Indexing and maintenance jobs
├── 📄 blob_storage_indexer.py      # Azure Blob Storage document indexer
├── 📄 sharepoint_indexer.py        # SharePoint document/list indexer
├── 📄 sharepoint_graph_client.py   # Microsoft Graph API client
├── 📄 sharepoint_ingestion_config.py
├── 📄 sharepoint_purger.py         # SharePoint stale data cleanup
├── 📄 nl2sql_indexer.py            # NL2SQL database schema indexer
├── 📄 nl2sql_purger.py             # NL2SQL stale data cleanup
└── 📄 multimodal_images_purger.py  # Image data lifecycle management
📁 tools/                            # Azure service clients
├── 📄 aisearch.py                  # Azure AI Search client
├── 📄 aoai.py                      # Azure OpenAI client (embeddings)
├── 📄 appconfig.py                 # App Configuration client
├── 📄 blob.py                      # Azure Blob Storage client
├── 📄 cosmosdb.py                  # Cosmos DB client
├── 📄 doc_intelligence.py          # Azure Document Intelligence client
├── 📄 keyvault.py                  # Key Vault client
└── 📄 sharepoint.py                # SharePoint connector
📁 utils/                            # Shared utilities
📁 telemetry/                        # Observability integration
📁 samples/                          # Sample data and configurations
📁 scripts/                          # Deployment scripts (deploy.ps1/deploy.sh)
```

### gpt-rag-ui

User interface built with **Chainlit** for conversational interaction with the RAG system. Works seamlessly with the Orchestrator backend, supports theming, authentication, and user feedback.

**Key Capabilities**:
- Chainlit-based conversational chat interface
- Microsoft Entra ID OAuth 2.0 authentication
- User feedback collection (thumbs up/down) stored in Cosmos DB
- Orchestrator API client for backend communication
- Theme and layout customization (`theme.json`, `custom.css`, `config.toml`)
- OpenTelemetry-based observability

**Languages**: Python 82.9%, PowerShell 9.2%, Shell 4.3%, JavaScript 3.1%, Dockerfile 0.3%, CSS 0.2%

**Repository Structure**:
```
📁 .chainlit/                        # Chainlit runtime configuration
📁 connectors/                       # Backend connectors
📁 public/                           # Static assets
├── 📄 theme.json                   # UI theme configuration
└── 📄 custom.css                   # Custom styling
📁 scripts/                          # Deployment scripts (deploy.ps1/deploy.sh)
📄 app.py                            # Chainlit application entry point
📄 main.py                           # Application bootstrap
📄 auth_oauth.py                     # OAuth 2.0 / Entra ID authentication
📄 feedback.py                       # User feedback handling
📄 orchestrator_client.py            # Orchestrator API client
📄 constants.py                      # Configuration constants
📄 dependencies.py                   # Dependency injection
📄 telemetry.py                      # Observability integration
📄 chainlit.config.yaml              # Chainlit settings
📄 Dockerfile                        # Container image definition
📄 requirements.txt                  # Python dependencies
```

### gpt-rag-mcp

Deploys a **Model Context Protocol (MCP)** server that extends the orchestrator with agentic tool-calling capabilities. Built with Semantic Kernel and the MCP standard.

**Key Capabilities**:
- MCP server implementation (SSE transport) exposing tools, resources, and prompts
- Semantic Kernel integration for tool execution
- Extends orchestrator via `mcp_strategy` when `AGENT_STRATEGY=mcp`
- MCP Inspector support for interactive testing
- Managed via `pyproject.toml` + `uv` package manager

**Languages**: PowerShell 51.2%, Shell 27.3%, Python 14.4%

**Post-Deployment Configuration**:
1. Set `AGENT_STRATEGY` to `mcp` in Azure App Configuration
2. Set `MCP_SERVER_URL` to `https://{container-app-name}.{region}.azurecontainerapps.io/mcp`
3. Restart the Orchestrator Container App

**Repository Structure**:
```
📁 src/
├── 📁 prompts/                     # MCP prompt templates
├── 📁 resources/                   # MCP resource definitions
├── 📁 tools/                       # MCP tool implementations
└── 📄 server.py                    # MCP server entry point
📁 scripts/                          # Deployment scripts (deploy.ps1/deploy.sh)
📄 pyproject.toml                    # Python project configuration (uv)
📄 uv.lock                          # Dependency lock file
```

---

## Repository Structure (This Repo)

### Root Level Files

```
📄 azure.yaml              # azd project definition, infra path, and lifecycle hooks
📄 .gitmodules             # Infra submodule mapping (landing-zone Bicep repository)
📄 manifest.json           # Multi-repo component release manifest (UI, MCP, orchestrator, ingestion)
📄 main.parameters.json    # Deployment parameters and service/model topology
📄 README.md               # Project overview and architecture context
📄 CHANGELOG.md            # Release history
📄 CONTRIBUTING.md         # Contribution guidance
📄 SECURITY.md             # Security reporting process
📄 SUPPORT.md              # Support guidance
📄 CODE_OF_CONDUCT.md      # Community standards
📄 LICENSE                 # License terms
📄 AGENTS.md               # Technical stack and structure guide (this file)
📁 .github/                # Issue templates and repository config
```

### `/config` - Post-Provision Configuration Modules

Python package that applies Azure service configuration after infrastructure provisioning.

```
📁 config/
├── 📄 requirements.txt                    # Python dependencies for post-provision setup
├── 📄 __init__.py
│
├── 📁 aifoundry/
│   ├── 📄 setup.py                        # Configures RAI blocklists/policies and deployment policy binding
│   ├── 📄 appconfig.py                    # Bulk settings loader from Azure App Configuration (label: gpt-rag)
│   ├── 📄 keyvault.py                     # Key Vault wrapper for get/set secret operations
│   ├── 📄 raiblocklist.json               # RAI blocklist definition template
│   ├── 📄 raipolicies.json                # RAI policies definition template
│   └── 📄 __init__.py
│
├── 📁 containerapps/
│   └── 📄 setup.py                        # Associates Container Apps with ACR using managed identities
│
└── 📁 search/
    ├── 📄 setup.py                        # Renders templates and provisions Azure AI Search artifacts
    ├── 📄 search.j2                       # Search resources definition template
    └── 📄 search.settings.j2             # Derived settings template persisted to App Config
```

### `/scripts` - Lifecycle Hooks

Cross-platform scripts invoked by `azd` hooks.

```
📁 scripts/
├── 📄 preProvision.ps1 / preProvision.sh  # Infra submodule init + parameter override + Zero Trust warning
├── 📄 postProvision.ps1 / postProvision.sh# Python bootstrap + Foundry/ContainerApps/Search setup
└── 📄 preDeploy.ps1 / preDeploy.sh        # Component repo deployment orchestration
```

### `/util` - Operational Utilities

```
📁 util/
├── 📄 prereqs.py                           # Region readiness checks (Cosmos DB + Azure OpenAI usage)
├── 📄 requirements.txt                     # Utility CLI dependencies
└── 📄 __init__.py
```

### `/infra` - Infrastructure as Code

```
📁 infra/                                   # Bicep infrastructure module (from submodule)
```

Notes:
- This folder is populated by `git submodule update --init --recursive` during pre-provision.
- `manifest.json` and `main.parameters.json` at repository root are copied into `infra/` as project-specific overrides.

### `/docs` and `/media`

```
📁 docs/                                    # Minimal docs content in develop branch (currently PR template)
📁 media/                                   # Architecture and UI images used by README/docs
```

### Documentation Site Branch (`origin/docs`)

The full project documentation site is maintained in the `docs` branch and published with MkDocs.

```
📄 mkdocs.yml                               # Site navigation and theme configuration
📄 requirements-docs.txt                    # Docs dependencies (mkdocs, mkdocs-material, macros)
📁 docs/                                    # Product docs (deployment, architecture, services, how-to guides)
📁 overrides/                               # MkDocs Material custom overrides
```

---

## Provisioning Flow

### 1) Infrastructure Provisioning

```bash
azd provision
```

High-level flow:
1. Initialize infra submodule.
2. Apply root deployment overrides (`manifest.json`, `main.parameters.json`) into `infra/`.
3. Provision Azure resources via Bicep.

### 2) Post-Provision Service Configuration

Executed by post-provision hook:
1. Create temporary Python virtual environment.
2. Install `config/requirements.txt`.
3. Configure AI Foundry safety policies and Key Vault secret flow.
4. Configure Container Apps ACR identity linkage.
5. Configure Azure AI Search resources from templates.

### 3) Component Deployment

```bash
azd deploy
```

High-level flow:
1. Validate prerequisites (Docker, Azure context, resource group).
2. Clone component repositories from `manifest.json`.
3. Execute each component deployment script.

---

## Observability and Security Posture

- **Zero Trust option** via network isolation flags and guarded script flow.
- **Bring Your Own VNet** for deploying within existing virtual networks.
- **Managed identities** preferred for service-to-service auth.
- **Microsoft Entra ID authentication** with document-level security and RBAC enforcement.
- **Azure App Configuration + Key Vault** used for centralized config and secret handling.
- **App Insights / Azure Monitor / Log Analytics** included in deployment parameters for telemetry.
- **Responsible AI** policies and blocklists applied to all model deployments.

---
