# Zero Trust Architecture Installation Checklist

Ensure a successful deployment of your Zero Trust Architecture by following this objective checklist. The checklist is divided into **Pre-Installation** and **Post-Installation** sections to guide you through the verification process.

---

## Table of Contents

1. [Pre-Installation Checks](#pre-installation-checks)
2. [Post-Installation Checks](#post-installation-checks)
3. [Additional Resources](#additional-resources)

---

## 1. Pre-Installation Checks

Complete all the following tasks before starting the installation to ensure a smooth deployment process.

### 1.1. **Deployment Planning**

- [ ] **Basic Information Gathered**
  - [ ] Subscription Name is documented.
  - [ ] Resource Group Name is recorded.
  - [ ] Azure Region is selected and confirmed.
  - [ ] Azure Environment Name (e.g., `gpt-rag-dev`, `gpt-rag-poc`) is defined.

- [ ] **Network Setup Scenario Selected**
  - [ ] Chosen network setup option (Automatic with Default Address Range, Automatic with Custom Address Ranges, or Manual) is identified.
  - [ ] Address ranges do not overlap with existing networks.

- [ ] **Existing Resources Reviewed**
  - [ ] Decision to reuse non-networking resources (e.g., Azure OpenAI, Cosmos DB, Key Vault) is made.
  - [ ] Names and resource group details of existing resources are documented.

- [ ] **Resource Naming and Tagging Prepared**
  - [ ] Naming conventions for resources are established.
  - [ ] Tags (e.g., `business-unit`, `cost-center`) are defined for resource management.

### 1.2. **Repository Setup**

- [ ] **Repository Initialized**
  - [ ] Ran `azd init -t azure/gpt-rag` successfully.
  - [ ] If using Agentic AutoGen-based orchestrator, ran `azd init -t azure/gpt-rag -b agentic` without errors.

### 1.3. **Configuration Settings**

- [ ] **Network Isolation Enabled**
  - [ ] Executed `azd env set AZURE_NETWORK_ISOLATION true` successfully.

- [ ] **Network Setup Option Defined**
  - [ ] Selected network setup option is configured (e.g., set `VNET_REUSE` for manual setup).

- [ ] **Custom Address Ranges Configured** (If applicable)
  - [ ] Executed all necessary `azd env set` commands for custom address ranges.
  - [ ] Verified custom address ranges to prevent overlaps.

- [ ] **Resource Names Customized** (If applicable)
  - [ ] Set environment variables for custom resource names (e.g., `AZURE_STORAGE_ACCOUNT_NAME`).

- [ ] **Azure Resources Reuse Configured** (If applicable)
  - [ ] Set environment variables for resource reuse (e.g., `AI_SERVICES_REUSE`, `AI_SERVICES_RESOURCE_GROUP_NAME`).

### 1.4. **Authentication**

- [ ] **Azure CLI Authentication**
  - [ ] Ran `azd auth login` successfully.
  - [ ] Ran `az login` without issues.

---

## 2. Post-Installation Checks

After completing the installation, verify that all components are correctly deployed and configured to ensure the Zero Trust Architecture functions as intended.

### 2.1. **Infrastructure Deployment Verification**

- [ ] **Infrastructure Components Deployed**
  - [ ] Ran `azd provision` successfully.
  - [ ] Verified all infrastructure components in the Azure Portal (resource groups, VNets, subnets, etc.).

### 2.2. **Network Configuration Verification**

- [ ] **Virtual Networks and Subnets**
  - [ ] Confirmed VNets are created with correct address ranges.
  - [ ] Verified all required subnets (`ai-vnet`, `ai-subnet`, `app-services-subnet`, etc.) are present and correctly configured.

- [ ] **Private Endpoints Setup**
  - [ ] Created private endpoints for all specified Azure services (e.g., Data Ingestion Function App, Azure Storage Account).
  - [ ] Ensured private endpoints are associated with the correct subnets.
  - [ ] Verified Private DNS Zones are correctly configured for name resolution.

- [ ] **Network Security Groups (NSGs)**
  - [ ] Created NSGs with rules aligned to security policies.
  - [ ] Applied NSGs to all relevant subnets.

- [ ] **Shared Private Access Configurations**
  - [ ] Configured shared private links for Azure AI Search with Blob Storage Account.
  - [ ] Configured shared private links for Azure AI Search with Function App.

- [ ] **App Service Plan VNet Integration**
  - [ ] Integrated App Service Plan with `ai-vnet`.
  - [ ] Verified connectivity between App Service and VNet.

- [ ] **Data Science Virtual Machine (Test VM)**
  - [ ] Provisioned VM with correct OS, SKU, and image.
  - [ ] Configured Bastion for secure VM access.
  - [ ] Connected to VM using Azure Bastion.
  - [ ] Verified VM performance and accessibility.

### 2.3. **Access Controls and Security Verification**

- [ ] **Access Controls Alignment**
  - [ ] Verified that access controls adhere to Zero Trust principles.
  - [ ] Tested role-based access controls (RBAC) and conditional access policies.

- [ ] **Network Security Groups (NSGs) Rules**
  - [ ] Verified NSG rules are correctly enforcing traffic flow restrictions.
  - [ ] Ensured only authorized traffic is allowed.

### 2.4. **Resource Naming and Tagging Validation**

- [ ] **Resource Names**
  - [ ] Checked that all resources have correct and consistent names following conventions.

- [ ] **Tags**
  - [ ] Verified that tags (e.g., `business-unit`, `cost-center`) are applied correctly to all resources.

### 2.5. **Connectivity and Integration Tests**

- [ ] **Component Connectivity**
  - [ ] Confirmed connectivity between all deployed components.
  - [ ] Tested VNet peering, VPN gateways, or ExpressRoute connections as applicable.

- [ ] **Service Integrations**
  - [ ] Verified integrations between components (e.g., AI Services with Cosmos DB).

### 2.6. **Application Functionality Verification**

- [ ] **Operational Components**
  - [ ] Tested all deployed application components to ensure they are operational.
  - [ ] Verified that services like Azure OpenAI, Cosmos DB, and Key Vault are functioning as expected.

### 2.7. **Monitoring and Logging Setup**

- [ ] **Monitoring Configuration**
  - [ ] Confirmed that monitoring tools (e.g., Azure Monitor) are configured.
  - [ ] Verified that metrics and logs are being collected.

- [ ] **Alerting Setup**
  - [ ] Ensured that alerts are set up for critical events and anomalies.

---

## 3. Additional Resources

- [Customizing Resource Names](CUSTOMIZATIONS_RESOURCE_NAMES.md)
- [Bring Your Own Resources](CUSTOMIZATIONS_BYOR.md)
- [Orchestrator Repository](https://github.com/azure/gpt-rag-agentic)
- [Front-end Repository](https://github.com/azure/gpt-rag-frontend)
- [Data Ingestion Repository](https://github.com/Azure/gpt-rag-ingestion)

---

## 4. Congratulations

🎉 **Congratulations! Your Zero Trust Architecture deployment has been successfully validated.**

---

> **Note:** After the initial deployment, consider performing periodic reviews and updates to maintain security posture and incorporate new best practices.

