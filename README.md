<!-- 
page_type: sample
languages:
- azdeveloper
- powershell
- bicep
products:
- azure
- azure-ai-foundry
- azure-openai
- azure-ai-search
urlFragment: GPT-RAG
name: Agentic RAG on Microsoft Foundry with Foundry IQ retrieval
description: Enterprise-grade accelerator for agentic RAG on Azure, built on Microsoft Foundry with Foundry IQ as the default retrieval backend and Microsoft Agent Framework orchestration, under a Zero-Trust, IaC-first architecture.
-->
<img src="media/logo.png" alt="Enterprise RAG Logo" width="80" align="left"/>

# GPT-RAG Solution Accelerator

This solution accelerator provides architecture templates and deployment assets to help organizations build secure, scalable, and enterprise-ready **agentic RAG** solutions on **Microsoft Foundry**. Orchestration runs on the **Microsoft Agent Framework**, and **Foundry IQ** is the default retrieval backend, blending Blob, Azure AI Search, Work IQ, Fabric, SharePoint, OneLake, Web and MCP sources with permission trimming. Azure AI Search direct remains fully supported as a rollback path. It applies proven Azure design patterns with **Zero-Trust security**, **Responsible AI**, and **end-to-end observability**.

For full documentation, visit the **[GPT-RAG documentation site](https://azure.github.io/GPT-RAG/)**.

GPT-RAG is built on a Zero-Trust architecture to ensure that all components operate within a controlled, isolated environment. Network access is tightly governed, and communication between services follows least-privilege principles.

## Getting started

Head to the documentation site for the complete guides:

- **[Grounding sources overview](https://azure.github.io/GPT-RAG/howto_grounding_overview/)** start here: Foundry IQ (default), Azure AI Search direct, Work IQ, Fabric, SharePoint, OneLake, Web and MCP sources, and how to choose.
- **[Deployment Guide](https://azure.github.io/GPT-RAG/deploy/)** covers Basic, Zero Trust, and network-isolated deployments, preflight checks, jumpbox workflow, and container image builds.
- **[What's New](https://azure.github.io/GPT-RAG/whatisnew/)** highlights the notable features added over time.

## Architecture

![Zero Trust Architecture](media/architecture_zero_trust.png)
*Zero-Trust Architecture*

### Hosted conversation continuity

Hosted continuity uses Responses protocol 2.0.0 with delegated
`x-ms-user-identity` ownership from the trusted UI BFF. Activation fails closed
until the UI identity has the exact Foundry Agent Consumer role and GPT-RAG
user-identity impersonation role directly at the individual agent scope. The
hosted container receives neither role, no ownership key, and no Cosmos DB in
the no-panel topology. See the [shared ownership contract](contracts/README.md)
for role IDs, validation rules, and the disabled capability fallback.

## Foundry-based agent capabilities

The accelerator supports a broad range of enterprise scenarios, from customer support to decision automation, by enabling systems to process complex queries across large data collections. It is designed for seamless integration into existing environments and can be adapted to both straightforward and advanced operational patterns.

The agent layer is built with the **Microsoft Agent Framework on Microsoft Foundry**. It supports scenarios such as **NL2SQL query generation**, multi-source grounding through **Foundry IQ**, and tool integration via **MCP servers**, so organizations can build workflows that retrieve, interpret, and act on enterprise data with contextual precision.

![Zero Trust UI](media/gpt-rag-homepage.png)
*GPT-RAG UI*

## Contributing

We welcome contributions! See the [contribution guidelines](https://azure.github.io/GPT-RAG/contributing/) for details on how to contribute.

## Trademarks

This project may contain trademarks or logos. Authorized use of Microsoft trademarks or logos must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Modified versions must not imply sponsorship or cause confusion. Third-party trademarks are subject to their own policies.
