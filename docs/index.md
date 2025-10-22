<img src="media/logo.png" alt="Enterprise RAG Logo" width="80" align="left"/>

# GPT-RAG Solution Accelerator

GPT-RAG is an enterprise-grade accelerator for building Retrieval-Augmented Generation (RAG) solutions on Azure. It provides a secure, modular, and scalable foundation to develop GenAI conversational assistants and data-driven applications using Azure OpenAI, AI Search, and AI Foundry. Designed with Zero-Trust principles and Infrastructure as Code (IaC), GPT-RAG enables faster time-to-value by combining enterprise security, flexible orchestration, and multimodal support for text, image, and voice experiences.

## 🏗️ Architecture

![Zero Trust Architecture](media/architecture-zero-trust.png)

### Core Components

| Component                                                         | Description                                                                             |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **[Orchestrator](https://github.com/Azure/gpt-rag-orchestrator)** | Manages multi-agent workflows and retrieves context using Semantic Kernel and Azure AI. |
| **[Web UI](https://github.com/Azure/gpt-rag-ui)**                 | User interface for chat interactions, supports streaming and custom themes.             |
| **[Data Ingestion](https://github.com/Azure/gpt-rag-ingestion)**  | Extracts, chunks, and indexes enterprise data for optimized retrieval.                  |
| **[MCP Server](https://github.com/Azure/gpt-rag-mcp)**            | Implements the Model Context Protocol for tool hosting and business logic integration.  |

## 🔐 Security and Compliance

GPT-RAG follows Microsoft’s **Zero-Trust** principles:

* Network isolation via **Private Endpoints** and **VNet Integration**
* Secrets stored in **Azure Key Vault**
* Role-based access with **Managed Identities**
* Full auditability via **Azure Monitor** and **Application Insights**

## 🤝 Contributing

We welcome community contributions!
Please review our [Contribution Page](https://github.com/Azure/GPT-RAG/blob/main/CONTRIBUTING.md) for the Contributor License Agreement (CLA), code of conduct, and PR guidelines.