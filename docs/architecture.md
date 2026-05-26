## Architecture

GPT-RAG is modular. The full Zero Trust diagram shows a hardened, full-capability reference architecture; it is not the minimum footprint required to evaluate or run the accelerator. Start with the **Basic Deployment** baseline, then add network isolation, enterprise integration, public ingress, or AI capabilities only when the scenario requires them.

## Full Zero Trust reference

The existing architecture diagram remains the full network-isolated reference view. Use it when discussing hardened deployments, while the complementary diagrams below explain the baseline and optional layers.

![Zero Trust Architecture](media/architecture_zero_trust.png)

[Download Visio Diagram](media/GPT-RAG.vsdx)

---

## Complementary modular views

!!! note "How to read these diagrams"
    The modular view is organized around **Basic Deployment**, **Common platform services**, and **Zero Trust additions**. Solid-color chips are standard resources, dashed orange chips are default-on or BYO-capable parameters, and solid orange chips are opt-in add-ons.

![Basic Deployment architecture](media/architecture_basic_deployment.svg)

The baseline corresponds to the [Basic Deployment](deploy.md#basic-deployment) flow with `NETWORK_ISOLATION=false`. It focuses on the default application and data path: users access the frontend, the orchestrator coordinates AI and retrieval, ingestion indexes enterprise content, and shared platform services provide configuration, secrets, identity, storage, search, and conversation state.

![Modular architecture layers](media/architecture_modular_layers.svg)

Use the table below for the deployment parameters behind each layer, and the [Deployment Guide](deploy.md) for the full `azd env set` flows.

## Deployment component table

| Layer | Posture | Controlled by | Include when |
| --- | --- | --- | --- |
| Frontend, orchestrator, ingestion | Required baseline | `manifest.json` components and `containerAppsList` | Running the default GPT-RAG web, orchestration, and ingestion services. |
| AI Foundry account, project, and model deployments | Required AI control plane | `deployAiFoundry`, `deployAfProject`, `deployAAfAgentSvc`, `modelDeploymentList` | Provisioning Azure AI Foundry / Azure OpenAI and the model deployments used by GPT-RAG. |
| AI Foundry associated resources | Default-created or BYO-capable | `aiSearchResourceId`, `aiFoundryStorageAccountResourceId`, `aiFoundryCosmosDBAccountResourceId`, `keyVaultResourceId`, `aiFoundryStorageSku` | Letting the AI Foundry module create its required Storage, Search, Cosmos DB, and Key Vault resources, or reusing existing ones. |
| RAG workload data services | Required for default RAG, parameter-controlled | `deploySearchService`, `deployStorageAccount`, `deployCosmosDb`, `storageAccountContainersList`, `databaseContainersList` | Running the standard indexed-document, conversation-state, and file-storage data path. Disable only for a customized topology that replaces those dependencies. |
| App Configuration, managed identity / RBAC, Container Apps, Container Registry | Required platform baseline | `deployAppConfig`, `deployContainerApps`, `deployContainerEnv`, `deployContainerRegistry`, `useUAI`, service role lists | Hosting the runtime services and centralizing runtime settings without hard-coded credentials. |
| Workload Key Vault and observability | Default support, parameter-controlled or reusable | `deployKeyVault`, `deployLogAnalytics`, `deployAppInsights`, `EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID`, `EXISTING_APPLICATION_INSIGHTS_RESOURCE_ID`, `EXISTING_APPLICATION_INSIGHTS_CONNECTION_STRING` | Storing workload secrets and capturing telemetry. Application Insights is created or wired only when an effective Log Analytics workspace is available. |
| Zero Trust private networking | Optional security posture | `networkIsolation`, `allowedIpRanges`, `useExistingVNet`, `deploySubnets`, `policyManagedPrivateDns`, `EXISTING_PRIVATE_DNS_ZONE_*` | Requiring private endpoints, private DNS, VNet integration, NSGs, and internal Container Apps ingress. |
| Azure Firewall, Jumpbox, Bastion, NAT Gateway, private ACR build pool | Zero Trust operations/build options | `DEPLOY_AZURE_FIREWALL`, `DEPLOY_JUMPBOX`, `DEPLOY_BASTION`, `DEPLOY_NAT_GATEWAY`, `DEPLOY_ACR_TASK_AGENT_POOL`, `EXISTING_JUMPBOX_RESOURCE_ID`, `EXISTING_BASTION_RESOURCE_ID`, `EXISTING_NAT_GATEWAY_RESOURCE_ID` | Operating from inside the VNet, reusing central access/egress resources, or enabling a private ACR Task agent pool. In GPT-RAG, the ACR agent pool defaults to off and is opt-in. |
| Application Gateway WAF public ingress | Optional entry layer | `publicIngress.enabled` | Exposing one private Container App through controlled public HTTPS/WAF. See [Application Gateway](howto_app_gateway.md). |
| Existing platform / AI Landing Zone integration | Optional enterprise integration | `DEPLOYMENT_MODE=ailz-integrated`, `USE_EXISTING_VNET`, `EXISTING_*_RESOURCE_ID`, `HUB_INTEGRATION_*` | Reusing central network, DNS, observability, Bastion, NAT, or hub-spoke resources. |
| Scenario capabilities | Optional feature add-ons | `DEPLOY_SPEECH_SERVICE`, `DEPLOY_GROUNDING_WITH_BING`, `ENABLE_AGENTIC_RETRIEVAL` | Enabling voice, Bing grounding, or agentic retrieval scenarios. MCP/tool-hosting and NL2SQL application behavior are configured outside the Bicep-deployed infrastructure shown in this diagram. |

## Key Capabilities

- **Enterprise-Grade Security**  
  Optional Zero Trust architecture with private endpoints, Azure Key Vault integration, and comprehensive monitoring.

- **Flexible & Customizable**  
  Modular design with customizable orchestration, multiple interface options, and bring-your-own-resources support.

- **Multimodal Experience**  
  Native support for text, images, and voice with SharePoint and Fabric connectors for seamless data integration.

- **Production Ready**  
  Enterprise-ready infrastructure with support for CI/CD pipelines and quality evaluation integration.
