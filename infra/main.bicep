// ============================================================================
// AI Landing Zone Bicep Deployment Template
// This infrastructure-as-code template follows best practices for modular,
// reusable, and configuration-aware deployments. Key principles:
//
// - **AZD Integration**: This template is optimized for use with the Azure Developer CLI (`azd`).
//   Use `azd provision` to deploy infrastructure and `azd deploy` to deploy your application.
//   It supports automated, repeatable, and configuration-aware workflows. The `main.json` file
//   can include placeholders (e.g., `${AZURE_LOCATION}`, `${AZURE_PRINCIPAL_ID}`) that are automatically
//   injected by `azd` during execution, enabling seamless parameter resolution.
//
// - **Parameterization**: All configuration values are defined in `main.json`.
//   You can create multiple parameter files to support different deployment configurations,
//   such as variations in scale, resource combinations, or cost constraints.
//
// - **Feature Flags**: Resource provisioning is modular and controlled via feature flags
//   (e.g., `deployAppConfig`). This enables selective deployment of components based on project needs.
//
// - **Azure Verified Modules (AVM)**: Official AVM modules are used as the foundation
//   for resource deployment, ensuring consistency, maintainability, and alignment with Microsoft standards.
//   Reference: https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/
//   When AVM does not cover a specific resource, custom Bicep module is used as fallback.
//
// - **Output Exposure**: Key outputs such as connection strings, endpoints, and resource IDs
//   are exposed as Bicep outputs and can be consumed by downstream processes or deployment scripts.
//
// - **Post-Provisioning Automation**: Supports optional post-provisioning scripts to perform data plane
//   operations or additional configurations. These scripts can run independently or as `azd` hooks,
//   enabling fine-grained control and custom automation after infrastructure deployment.
//
// ============================================================================

targetScope = 'resourceGroup'

//////////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////////

// NOTE: Set parameter values using main.parameters.json

// ----------------------------------------------------------------------
// Imports
// ----------------------------------------------------------------------
import * as const from 'constants/constants.bicep'

// ----------------------------------------------------------------------
// General Parameters
// ----------------------------------------------------------------------

@description('Name of the Azure Developer CLI environment')
param environmentName string

@description('The Azure region where your resources will be created.')
param location string = resourceGroup().location

@description('The Azure region where your AI Foundry resource and project will be created. Defaults to the resource group location.')
param aiFoundryLocation string = resourceGroup().location

@description('Principal ID for role assignments. This is typically the Object ID of the user or service principal running the deployment.')
param principalId string

@description('Principal type for role assignments. This can be "User", "ServicePrincipal", or "Group".')
param principalType string = 'User'

@description('Tags to apply to all resources in the deployment')
param deploymentTags object = {}

@description('Enable network isolation for the deployment. This will restrict public access to resources and require private endpoints where applicable.')
param networkIsolation bool = false

// ----------------------------------------------------------------------
// Feature-flagging Params (as booleans with a default of true)
// ----------------------------------------------------------------------

@description('If false, skips creating platform infrastructure such as Firewall, Jumpbox, Bastion, etc.')
param greenFieldDeployment bool = true

@description('Whether to deploy Bing-powered grounding capabilities alongside your AI services.')
param deployGroundingWithBing bool = true

@description('Deploy Azure App Configuration for centralized feature-flag and configuration management.')
param deployAppConfig bool = true

@description('Deploy an Azure Key Vault to securely store secrets, keys, and certificates.')
param deployKeyVault bool = true

@description('Deploy an Azure Log Analytics workspace for centralized log collection and query.')
param deployLogAnalytics bool = true

@description('Deploy Azure Application Insights for application performance monitoring and diagnostics.')
param deployAppInsights bool = true

@description('Deploy an Azure Cognitive Search service for indexing and querying content.')
param deploySearchService bool = true

@description('Deploy an Azure Storage Account to hold blobs, queues, tables, and files.')
param deployStorageAccount bool = true

@description('Deploy an Azure Cosmos DB account for globally distributed NoSQL data storage.')
param deployCosmosDb bool = true

@description('Deploy Azure Container Apps for running your microservices in a serverless Kubernetes environment.')
param deployContainerApps bool = true

@description('Deploy an Azure Container Registry to store and manage Docker container images.')
param deployContainerRegistry bool = true

@description('Deploy the Container Apps environment (log ingestion, VNet integration, etc.).')
param deployContainerEnv bool = true

@description('Deploy a Virtual Machine (e.g., for jumpbox or specialized workloads).')
param deployVM bool = true

// ----------------------------------------------------------------------
// Reuse Existing Services Parameters
// Note: Reuse is optional. Leave empty to create new resources
// ----------------------------------------------------------------------

// AI Foundry Dependencies

@description('The AI Search Service full ARM resource ID. Optional; if not provided, a new resource will be created.')
param aiSearchResourceId string = ''

@description('The AI Storage Account full ARM resource ID. Optional; if not provided, a new resource will be created.')
param aiFoundryStorageAccountResourceId string = ''

@description('The Cosmos DB account full ARM resource ID. Optional; if not provided, a new resource will be created.')
param aiFoundryCosmosDBAccountResourceId string = ''

// GenAI App Services

@description('The Container Apps Environment full ARM resource ID. Optional; if not provided, a new environment will be created.')
param containerEnvResourceId string = ''

@description('The Container Registry full ARM resource ID. Optional; if not provided, a new registry will be created.')
param containerRegistryResourceId string = ''

@description('The Key Vault full ARM resource ID. Optional; if not provided, a new vault will be created.')
param keyVaultResourceId string = ''

@description('The Cosmos DB account full ARM resource ID for general workloads. Optional; if not provided, a new account will be created.')
param cosmosDbResourceId string = ''

// Common Services (non-AI-Foundry)

@description('The Azure Cognitive Search service full ARM resource ID. Optional; if not provided, a new service will be created.')
param searchServiceResourceId string = ''

@description('The Storage Account full ARM resource ID. Optional; if not provided, a new account will be created.')
param storageAccountResourceId string = ''

@description('The Log Analytics Workspace full ARM resource ID. Optional; if not provided, a new workspace will be created.')
param logAnalyticsWorkspaceResourceId string = ''

@description('The Application Insights full ARM resource ID. Optional; if not provided, a new component will be created.')
param appInsightsResourceId string = ''

@description('Object mapping DNS zone names to their resource group, or empty string to indicate creation')
param existingDnsZones object = {}

@description('Zone Names for Validation of existing Private Dns Zones')
param dnsZoneNames array = []

// ----------------------------------------------------------------------
// AI Foundry Parameters
// ----------------------------------------------------------------------

@description('The name of the project capability host to be used for the AI Foundry project.')
param projectCapHost string = 'caphostproj'

@description('The name of the account capability host to be used for the AI Foundry account.')
param accountCapHost string = 'caphostacc'

// ----------------------------------------------------------------------
// Feature-flagging Params (as booleans with a default of false)
// ----------------------------------------------------------------------
param useUAI bool = false // Use User Assigned Identity (UAI)

// ----------------------------------------------------------------------
// Resource Naming params
// ----------------------------------------------------------------------

@description('Unique token used to build deterministic resource names, derived from subscription ID, environment name, and location.')
param resourceToken string = toLower(uniqueString(subscription().id, environmentName, location))

@description('Name of the Azure AI Foundry account to create or reference.')
param aiFoundryAccountName string = '${const.abbrs.ai.aiFoundry}${resourceToken}'

@description('Name of the AI Foundry project resource.')
param aiFoundryProjectName string = '${const.abbrs.ai.aiFoundryProject}${resourceToken}'

@description('Display name for the AI Foundry project as shown in the portal.')
param aiFoundryProjectDisplayName string = '${const.abbrs.ai.aiFoundryProject}${resourceToken}'

@description('Detailed description for the AI Foundry project.')
param aiFoundryProjectDescription string = '${const.abbrs.ai.aiFoundryProject}${resourceToken} Project'

@description('Name of the Storage Account used by AI Foundry for blobs, queues, tables, and files.')
param aiFoundryStorageAccountName string = replace('${const.abbrs.storage.storageAccount}${const.abbrs.ai.aiFoundry}${resourceToken}', '-', '')

@description('Name of the Cognitive Search service provisioned for AI Foundry.')
param aiFoundrySearchServiceName string = '${const.abbrs.ai.aiSearch}${const.abbrs.ai.aiFoundry}${resourceToken}'

@description('Name of the Azure Cosmos DB account used by AI Foundry.')
param aiFoundryCosmosDbName string = '${const.abbrs.databases.cosmosDBDatabase}${const.abbrs.ai.aiFoundry}${resourceToken}'

@description('Name of the Bing Search resource for grounding capabilities.')
param bingSearchName string = '${const.abbrs.ai.bing}${resourceToken}'

@description('Name of the Azure App Configuration store for centralized settings.')
param appConfigName string = '${const.abbrs.configuration.appConfiguration}${resourceToken}'

@description('Name of the Application Insights instance for monitoring.')
param appInsightsName string = '${const.abbrs.managementGovernance.applicationInsights}${resourceToken}'

@description('Name of the Azure Container Apps environment (log ingestion, VNet integration, etc.).')
param containerEnvName string = '${const.abbrs.containers.containerAppsEnvironment}${resourceToken}'

@description('Name of the Azure Container Registry for storing Docker images.')
param containerRegistryName string = '${const.abbrs.containers.containerRegistry}${resourceToken}'

@description('Name of the Cosmos DB account (alias for database operations).')
param dbAccountName string = '${const.abbrs.databases.cosmosDBDatabase}${resourceToken}'

@description('Name of the Cosmos DB database to host application data.')
param dbDatabaseName string = '${const.abbrs.databases.cosmosDBDatabase}db${resourceToken}'

@description('Name of the Azure Key Vault for secrets, keys, and certificates.')
param keyVaultName string = '${const.abbrs.security.keyVault}${resourceToken}'

@description('Name of the Log Analytics workspace for collecting and querying logs.')
param logAnalyticsWorkspaceName string = '${const.abbrs.managementGovernance.logAnalyticsWorkspace}${resourceToken}'

@description('Name of the Cognitive Search service.')
param searchServiceName string = '${const.abbrs.ai.aiSearch}${resourceToken}'

@description('Name of the Azure Storage Account for general-purpose blob and file storage.')
param storageAccountName string = '${const.abbrs.storage.storageAccount}${resourceToken}'

@description('Name of the Virtual Network to isolate resources and enable private endpoints.')
param vnetName string = '${const.abbrs.networking.virtualNetwork}${resourceToken}'


// ----------------------------------------------------------------------
// Azure AI Foundry Service params
// ----------------------------------------------------------------------

@description('List of model deployments to create in the AI Foundry account')
param modelDeploymentList array

// ----------------------------------------------------------------------
// Container Apps params
// ----------------------------------------------------------------------

@description('List of container apps to create')
param containerAppsList array

@description('Workload profiles.')
param workloadProfiles array = []

// ----------------------------------------------------------------------
// Cosmos DB Database params
// ----------------------------------------------------------------------

@description('Name of the Cosmos DB account to create')
param databaseContainersList array

// ----------------------------------------------------------------------
// VM params
// ----------------------------------------------------------------------

@description('The name of the VM Key Vault Secret. If left empty, a random name will be generated.')
param vmKeyVaultSecName string = ''

@description('The name of the Test VM. If left empty, a random name will be generated.')
param vmName string = ''

@description('Test vm user name. Needed only when choosing network isolation and create bastion option. If not you can leave it blank.')
param vmUserName string = ''

@secure()
@description('Admin password for the test VM user')
param vmAdminPassword string

@description('Size of the test VM')
param vmSize string = 'Standard_D4s_v3'

// ----------------------------------------------------------------------
// Storage Account params
// ----------------------------------------------------------------------

@description('List of containers to create in the Storage Account')
param storageAccountContainersList array

// ----------------------------------------------------------------------
// CMK params
// ----------------------------------------------------------------------
// Note : Customer Managed Keys (CMK) not implemented in this module yet
// @description('Use Customer Managed Keys for Storage Account and Key Vault')
// param useCMK      bool   = false

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------
// General Variables
// ----------------------------------------------------------------------

var _azdTags = { 'azd-env-name': environmentName }
var _tags = union(_azdTags, deploymentTags)

// ----------------------------------------------------------------------
// Reuse Existing Services Variables
// ----------------------------------------------------------------------

// Azure Cognitive Search Service
var _searchPassedIn = aiSearchResourceId != ''
var _searchParts = split(aiSearchResourceId, '/')
var _aiSearchServiceSubscriptionId = _searchPassedIn ? _searchParts[2] : subscription().subscriptionId
var _aiSearchServiceResourceGroupName = _searchPassedIn ? _searchParts[4] : resourceGroup().name

// Azure Cosmos DB Account
var _cosmosPassedIn = aiFoundryCosmosDBAccountResourceId != ''
var _cosmosParts = split(aiFoundryCosmosDBAccountResourceId, '/')
var _cosmosDBSubscriptionId = _cosmosPassedIn ? _cosmosParts[2] : subscription().subscriptionId
var _cosmosDBResourceGroupName = _cosmosPassedIn ? _cosmosParts[4] : resourceGroup().name

// Azure Storage Account
var _storagePassedIn = aiFoundryStorageAccountResourceId != ''
var _storageParts = split(aiFoundryStorageAccountResourceId, '/')
var _azureStorageSubscriptionId = _storagePassedIn ? _storageParts[2] : subscription().subscriptionId
var _azureStorageResourceGroupName = _storagePassedIn ? _storageParts[4] : resourceGroup().name

// Container Apps Environment
var _containerEnvPassedIn = containerEnvResourceId != ''
var _containerEnvParts = split(containerEnvResourceId, '/')
var _containerEnvSubscriptionId = _containerEnvPassedIn ? _containerEnvParts[2] : subscription().subscriptionId
var _containerEnvResourceGroupName = _containerEnvPassedIn ? _containerEnvParts[4] : resourceGroup().name

// Container Registry
var _containerRegistryPassedIn = containerRegistryResourceId != ''
var _containerRegistryParts = split(containerRegistryResourceId, '/')
var _containerRegistrySubscriptionId = _containerRegistryPassedIn
  ? _containerRegistryParts[2]
  : subscription().subscriptionId
var _containerRegistryResourceGroupName = _containerRegistryPassedIn ? _containerRegistryParts[4] : resourceGroup().name

// Key Vault
var _keyVaultPassedIn = keyVaultResourceId != ''
var _keyVaultParts = split(keyVaultResourceId, '/')
var _keyVaultSubscriptionId = _keyVaultPassedIn ? _keyVaultParts[2] : subscription().subscriptionId
var _keyVaultResourceGroupName = _keyVaultPassedIn ? _keyVaultParts[4] : resourceGroup().name

// ----------------------------------------------------------------------
// Container vars
// ----------------------------------------------------------------------

var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ----------------------------------------------------------------------
// Networking vars
// ----------------------------------------------------------------------

#disable-next-line BCP318
var _peSubnetId = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/pe-subnet' : ''
#disable-next-line BCP318
var _caEnvSubnetId = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/aca-environment-subnet' : ''
#disable-next-line BCP318
var _jumpbxSubnetId = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/jumpbox-subnet' : ''
#disable-next-line BCP318
var _agentSubnetId = networkIsolation ? '${virtualNetwork.outputs.resourceId}/subnets/agent-subnet' : ''

// ----------------------------------------------------------------------
// VM vars
// ----------------------------------------------------------------------

var _vmKeyVaultSecName = !empty(vmKeyVaultSecName) ? vmKeyVaultSecName : 'vmUserInitialPassword'
var _vmBaseName = !empty(vmName) ? vmName : 'testvm${resourceToken}'
var _vmName = substring(_vmBaseName, 0, 15)
var _vmUserName = !empty(vmUserName) ? vmUserName : 'testvmuser'

//////////////////////////////////////////////////////////////////////////
// RESOURCES
//////////////////////////////////////////////////////////////////////////

// Security
///////////////////////////////////////////////////////////////////////////

// Network Watcher
// Note: Automatically provisioned when network isolation is enabled (VNet deployment)

// Azure Defender for Cloud
// Note: By default, free tier (foundational recommendations) is enabled at the subscription level.
//       To enable its advanced threat protection features, Defender plans must be explicitly configured
//       using the Microsoft.Security/pricings resource (e.g., for Storage, Key Vault, App Services).

// Purview Compliance Manager
// Note: Not applicable, it's part of Microsoft 365 Compliance Center, not Azure Resource Manager.

// Networking
///////////////////////////////////////////////////////////////////////////

// Azure DDoS Protection

// VNet
// Note on IP address sizing: https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks#known-limitations
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (networkIsolation) {
  name: 'virtualNetworkDeployment'
  params: {
    // VNet sized /16 to fit all subnets
    addressPrefixes: [
      '192.168.0.0/16'
    ]
    name: vnetName
    location: location

    tags: _tags

    subnets: [
      {
        name: 'agent-subnet'
        addressPrefix: '192.168.0.0/24' // 256 IPs for AI Foundry agents
        delegation: 'Microsoft.app/environments'
        // privateEndpointNetworkPolicies: 'Disabled'
        // privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: 'pe-subnet'
        addressPrefix: '192.168.1.0/24' // 256 IPs for private endpoints
      }
      {
        name: 'gateway-subnet'
        addressPrefix: '192.168.2.0/26' // 64 IPs for VPN/ExpressRoute gateway (min /26)
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '192.168.2.64/26' // 64 IPs for Bastion host (min /26)
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '192.168.2.128/26' // 64 IPs for Firewall (min /26)
      }
      {
        name: 'AppGatewaySubnet'
        addressPrefix: '192.168.3.0/24' // 256 IPs for Application Gateway + WAF
      }
      {
        name: 'jumpbox-subnet'
        addressPrefix: '192.168.4.0/27' // 32 IPs for jumpbox VMs
      }
      {
        name: 'api-management-subnet'
        addressPrefix: '192.168.4.32/27' // 32 IPs for API Management
      }
      {
        name: 'aca-environment-subnet'
        addressPrefix: '192.168.4.64/27' // 32 IPs for Container Apps environment
        delegation: 'Microsoft.app/environments'
      }
      {
        name: 'devops-build-agents-subnet'
        addressPrefix: '192.168.4.96/27' // 32 IPs for DevOps build agents
      }
    ]
  }
}

// Azure virtual machine creation (Jumpbox)
///////////////////////////////////////////////////////////////////////////

// Azure Bastion

//  Key Vault to store that password securely
module testVmKeyVault 'br/public:avm/res/key-vault/vault:0.12.1' = if (deployVM && networkIsolation) {
  name: 'vmKeyVault'
  params: {
    name: '${const.abbrs.security.keyVault}testvm-${resourceToken}'
    location: location
    publicNetworkAccess: 'Disabled'
    sku: 'standard'
    enableRbacAuthorization: true
    tags: _tags
    secrets: [
      {
        name: _vmKeyVaultSecName
        value: vmAdminPassword
      }
    ]
  }
}

// Bastion Host
module testVmBastionHost 'br/public:avm/res/network/bastion-host:0.6.1' = if (deployVM && networkIsolation) {
  name: 'bastionHost'
  params: {
    // Bastion host name
    name: '${const.abbrs.security.bastion}testvm-${resourceToken}'
    #disable-next-line BCP318
    virtualNetworkResourceId: virtualNetwork.outputs.resourceId
    location: location
    skuName: 'Standard'
    tags: _tags

    // Configuration for the Public IP that the module will create
    publicIPAddressObject: {
      // Name for the Public IP resource
      name: '${const.abbrs.networking.publicIPAddress}bastion-${resourceToken}'
      allocationMethod: 'Static'
      skuName: 'Standard'
      skuTier: 'Regional'
      zones: [1, 2, 3]
      tags: _tags
    }
  }
}

// Test VM
module testVm 'br/public:avm/res/compute/virtual-machine:0.15.0' = if (deployVM && networkIsolation) {
  name: 'testVmDeployment'
  params: {
    name: _vmName
    location: location
    adminUsername: _vmUserName
    adminPassword: vmAdminPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    vmSize: vmSize
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    zone: 0
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            #disable-next-line BCP318
            subnetResourceId: _jumpbxSubnetId
          }
        ]
      }
    ]
  }
  dependsOn: [
    virtualNetwork!
    testVmKeyVault
    testVmBastionHost
  ]
}

// Private DNS Zones.
///////////////////////////////////////////////////////////////////////////

// AI Foundry Account
module privateDnsZoneCogSvcs 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation) {
  name: 'dep-cogsvcs-private-dns-zone'
  params: {
    name: 'privatelink.cognitiveservices.azure.com'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-cogsvcs-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// AI Search
module privateDnsZoneSearch 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation) {
  name: 'dep-search-std-private-dns-zone'
  params: {
    name: 'privatelink.search.windows.net'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-search-std-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Cosmos DB
module privateDnsZoneCosmos 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation) {
  name: 'dep-cosmos-std-private-dns-zone'
  params: {
    name: 'privatelink.documents.azure.com'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-cosmos-std-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Storage Account
module privateDnsZoneBlob 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation) {
  name: 'dep-blob-std-private-dns-zone'
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-blob-std-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Key Vault
module privateDnsZoneKeyVault 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation && deployKeyVault) {
  name: 'kv-private-dns-zone'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-kv-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Application Configuration
module privateDnsZoneAppConfig 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation && deployAppConfig) {
  name: 'appconfig-private-dns-zone'
  params: {
    name: 'privatelink.azconfig.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-appcfg-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Application Insights
module privateDnsZoneInsights 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation && deployAppInsights) {
  name: 'ai-private-dns-zone'
  params: {
    name: 'privatelink.applicationinsights.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-ai-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Container Apps
module privateDnsZoneContainerApps 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation) {
  name: 'dep-containerapps-env-private-dns-zone'
  params: {
    name: 'privatelink.${location}.azurecontainerapps.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-containerapps-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Container Registry
module privateDnsZoneAcr 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (networkIsolation && deployContainerRegistry) {
  name: 'acr-private-dns-zone'
  params: {
    name: 'privatelink.azurecr.io'
    location: 'global'
    tags: _tags
    virtualNetworkLinks: [
      {
        name: '${vnetName}-acr-link'
        registrationEnabled: false
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

// Private Endpoints.
///////////////////////////////////////////////////////////////////////////

// AI Foundry dependencies

// AI Foundry Account
module privateEndpointAIFoundryAccount 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation) {
  name: 'dep-cogsvcs-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${aiFoundryAccountName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'cogsvcsConnection'
        properties: {
          privateLinkServiceId: aiFoundryAccount.outputs.accountID
          // for Cognitive Services account the groupId is typically "account"
          groupIds: ['account']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'cogsvcsDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'cogsvcsARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneCogSvcs.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    aiFoundryAccount!
    privateDnsZoneCogSvcs!
  ]
}

// AI Search (AI Foundry dependency)
module privateEndpointSearchDepStd 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation) {
  name: 'dep-search-std-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${aiFoundryDependencies.outputs.aiSearchName}'
    location: empty(aiFoundryLocation) ? location : aiFoundryLocation
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'searchStdConnection'
        properties: {
          privateLinkServiceId: aiFoundryDependencies.outputs.aiSearchID
          groupIds: ['searchService']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'searchStdDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'searchStdARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneSearch.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    aiFoundryDependencies!
    privateDnsZoneSearch!
  ]
}

// Cosmos DB (AI Foundry dependency)
module privateEndpointCosmosDepStd 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation) {
  name: 'dep-cosmos-std-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${aiFoundryDependencies.outputs.cosmosDBName}'
    location: empty(aiFoundryLocation) ? location : aiFoundryLocation
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'cosmosStdConnection'
        properties: {
          privateLinkServiceId: aiFoundryDependencies.outputs.cosmosDBId
          groupIds: ['Sql']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'cosmosStdDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'cosmosStdARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneCosmos.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    aiFoundryDependencies!
    privateDnsZoneCosmos!
  ]
}

// Storage Account (AI Foundry dependency)
module privateEndpointBlobDepStd 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation) {
  name: 'dep-blob-std-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${aiFoundryDependencies.outputs.azureStorageName}'
    location: empty(aiFoundryLocation) ? location : aiFoundryLocation
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'blobStdConnection'
        properties: {
          privateLinkServiceId: aiFoundryDependencies.outputs.azureStorageId
          groupIds: ['blob']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'blobStdDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'blobStdARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneBlob.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    aiFoundryDependencies!
    privateDnsZoneBlob!
  ]
}

// Storage Account
module privateEndpointStorageBlob 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deployStorageAccount) {
  name: 'blob-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${storageAccountName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'blobConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: storageAccount.outputs.resourceId
          groupIds: ['blob']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'blobDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'blobARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneBlob.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    storageAccount!
    privateDnsZoneBlob!
  ]
}

// Cosmos DB
module privateEndpointCosmos 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deployCosmosDb) {
  name: 'cosmos-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${dbAccountName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'cosmosConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: cosmosDBAccount.outputs.resourceId
          groupIds: ['Sql']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'cosmosDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'cosmosARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneCosmos.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    cosmosDBAccount!
    privateDnsZoneCosmos!
  ]
}

// AI Search
module privateEndpointSearch 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deploySearchService) {
  name: 'search-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${searchServiceName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'searchConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: searchService.outputs.resourceId
          groupIds: ['searchService']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'searchDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'searchARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneSearch.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    searchService!
    privateDnsZoneSearch!
  ]
}

// Key Vault
module privateEndpointKeyVault 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deployKeyVault) {
  name: 'kv-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${keyVaultName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'kvConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: keyVault.outputs.resourceId
          groupIds: ['vault']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'kvDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'kvARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneKeyVault.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    keyVault!
    privateDnsZoneKeyVault!
  ]
}

// Application Configuration
module privateEndpointAppConfig 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deployAppConfig) {
  name: 'appconfig-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${appConfigName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'appConfigConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: appConfig.outputs.resourceId
          groupIds: ['configurationStores']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'appConfigDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'appConfigARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneAppConfig.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    appConfig!
    privateDnsZoneAppConfig!
  ]
}

// Container Apps Environment
module privateEndpointContainerAppsEnv 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deployContainerEnv) {
  name: 'dep-containerapps-env-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${containerEnvName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'ccaConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: containerEnv.outputs.resourceId
          groupIds: ['managedEnvironments']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'ccaDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'ccaARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneContainerApps.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    containerEnv!
    privateDnsZoneContainerApps!
  ]
}

// Container Registry
module privateEndpointAcr 'br/public:avm/res/network/private-endpoint:0.11.0' = if (networkIsolation && deployContainerRegistry) {
  name: 'dep-acr-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${containerRegistryName}'
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'acrConnection'
        properties: {
          #disable-next-line BCP318
          privateLinkServiceId: containerRegistry.outputs.resourceId
          groupIds: ['registry']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'acrDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'acrARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneAcr.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    containerRegistry!
    privateDnsZoneAcr!
  ]
}

// Azure Application Gateway
//////////////////////////////////////////////////////////////////////////
// Coming Soon

// Azure Firewall
//////////////////////////////////////////////////////////////////////////
// Coming Soon

// AI Foundry Standard Setup
//////////////////////////////////////////////////////////////////////////

// Custom modules are used for AI Foundry Account and Project (V2) since no published AVM module available at this time.

// 1) In the future, replace this section by AI Foundry Pattern
// https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/ai-ml/ai-foundry

// 2) Custom modules based on AI Foundry Documentation Samples:
// https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/microsoft/infrastructure-setup

module aiFoundryValidateExistingResources 'modules/standard-setup/validate-existing-resources.bicep' = {
  name: 'validate-existing-resources-${resourceToken}-deployment'
  params: {
    aiSearchResourceId: aiSearchResourceId
    azureStorageAccountResourceId: aiFoundryStorageAccountResourceId
    azureCosmosDBAccountResourceId: aiFoundryCosmosDBAccountResourceId
    #disable-next-line BCP321
    existingDnsZones: networkIsolation ? existingDnsZones : {}
    dnsZoneNames: networkIsolation ? dnsZoneNames : []
  }
}

// User Managed Identities for AI Foundry resources

//AI Foundry Account User Managed Identity
module aiFoundryUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${aiFoundryAccountName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${aiFoundryAccountName}'
    // Non-required parameters
    location: location
  }
}

//AI Foundry Search User Managed Identity
module aiFoundrySearchServiceNameUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${aiFoundrySearchServiceName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${aiFoundrySearchServiceName}'
    // Non-required parameters
    location: location
  }
}

//AI Foundry Cosmos User Managed Identity
module aiFoundryCosmosDbNameUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${aiFoundryCosmosDbName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${aiFoundryCosmosDbName}'
    // Non-required parameters
    location: location
  }
}

// AI Foundry Project User Managed Identity
module aiFoundryProjectUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${aiFoundryProjectName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${aiFoundryProjectName}'
    // Non-required parameters
    location: location
  }
}

// This module will create new agent dependent resources
// A Cosmos DB account, an AI Search Service, and a Storage Account are created if they do not already exist
module aiFoundryDependencies 'modules/standard-setup/standard-dependent-resources.bicep' = {
  name: 'dependencies-${aiFoundryAccountName}-${resourceToken}-deployment'
  params: {
    location: empty(aiFoundryLocation) ? location : aiFoundryLocation
    azureStorageName: aiFoundryStorageAccountName
    aiSearchName: aiFoundrySearchServiceName
    cosmosDBName: aiFoundryCosmosDbName
    networkIsolation: networkIsolation

    // AI Search Service parameters
    aiSearchResourceId: aiSearchResourceId
    aiSearchExists: aiFoundryValidateExistingResources.outputs.aiSearchExists

    // Storage Account
    azureStorageAccountResourceId: aiFoundryStorageAccountResourceId
    azureStorageExists: aiFoundryValidateExistingResources.outputs.azureStorageExists

    // Cosmos DB Account
    cosmosDBResourceId: aiFoundryCosmosDBAccountResourceId
    cosmosDBExists: aiFoundryValidateExistingResources.outputs.cosmosDBExists
  }
}

// Create the AI Services account and model deployments
module aiFoundryAccount 'modules/standard-setup/ai-account-identity.bicep' = {
  name: 'ai-${aiFoundryAccountName}-${resourceToken}-deployment'
  params: {
    accountName: aiFoundryAccountName
    location: aiFoundryLocation
    modelDeployments: modelDeploymentList
    networkIsolation: networkIsolation
    agentSubnetId: _agentSubnetId
  }
  dependsOn: [
    aiFoundryValidateExistingResources
    aiFoundryDependencies
  ]
}

// Creates a new project (sub-resource of the AI Services account)
module aiFoundryProject 'modules/standard-setup/ai-project-identity.bicep' = {
  name: 'ai-${aiFoundryProjectName}-${resourceToken}-deployment'
  params: {
    projectName: aiFoundryProjectName
    projectDescription: aiFoundryProjectDescription
    displayName: aiFoundryProjectDisplayName
    location: empty(aiFoundryLocation) ? location : aiFoundryLocation

    aiSearchName: aiFoundryDependencies.outputs.aiSearchName
    aiSearchServiceResourceGroupName: aiFoundryDependencies.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: aiFoundryDependencies.outputs.aiSearchServiceSubscriptionId

    cosmosDBName: aiFoundryDependencies.outputs.cosmosDBName
    cosmosDBSubscriptionId: aiFoundryDependencies.outputs.cosmosDBSubscriptionId
    cosmosDBResourceGroupName: aiFoundryDependencies.outputs.cosmosDBResourceGroupName

    azureStorageName: aiFoundryDependencies.outputs.azureStorageName
    azureStorageSubscriptionId: aiFoundryDependencies.outputs.azureStorageSubscriptionId
    azureStorageResourceGroupName: aiFoundryDependencies.outputs.azureStorageResourceGroupName

    accountName: aiFoundryAccount.outputs.accountName
  }
}

// Format the project workspace ID
module aiFoundryFormatProjectWorkspaceId 'modules/standard-setup/format-project-workspace-id.bicep' = {
  name: 'format-project-workspace-id-${resourceToken}-deployment'
  params: {
    projectWorkspaceId: aiFoundryProject.outputs.projectWorkspaceId
  }
}

// AI Foundry Project Capabilities
module aiFoundryAddProjectCapabilityHost 'modules/standard-setup/add-project-capability-host.bicep' = {
  name: 'capabilityHost-configuration-${resourceToken}-deployment'
  params: {
    accountName: aiFoundryAccount.outputs.accountName
    projectName: aiFoundryProject.outputs.projectName
    cosmosDBConnection: aiFoundryProject.outputs.cosmosDBConnection
    azureStorageConnection: aiFoundryProject.outputs.azureStorageConnection
    aiSearchConnection: aiFoundryProject.outputs.aiSearchConnection

    projectCapHost: projectCapHost
    accountCapHost: accountCapHost
  }
  dependsOn: _capabiityHostDependsAll
}

var _capabiityHostBaseDepends = [
  assignSearchAiFoundryProject
  assignCosmosDBAiFoundryProject
  assignStorageAccountAiFoundryProject
]
var _capabiityHostNetworkDepends = [
  aiFoundryDependencies.outputs.azureStorageName
  aiFoundryDependencies.outputs.aiSearchName
  aiFoundryDependencies.outputs.cosmosDBName
  privateDnsZoneBlob
  privateDnsZoneCosmos
  privateDnsZoneSearch
  privateEndpointBlobDepStd
  privateEndpointCosmosDepStd
  privateEndpointSearchDepStd
]
var _capabiityHostDependsAll = networkIsolation
  ? concat(_capabiityHostBaseDepends, _capabiityHostNetworkDepends)
  : _capabiityHostBaseDepends

// AI Foundry Connections
module aiFoundryBingConnection 'modules/standard-setup/ai-foundry-bing-search-tool.bicep' = if (deployGroundingWithBing) {
  name: '${bingSearchName}-connection'
  params: {
    account_name: aiFoundryAccount.outputs.accountName
    project_name: aiFoundryProject.outputs.projectName
    bingSearchName: bingSearchName
  }
}

module aiFoundryConnectionSearch 'modules/standard-setup/connection-ai-search.bicep' = if (deploySearchService) {
  name: 'connection-ai-search-${resourceToken}'
  params: {
    aiFoundryName: aiFoundryAccount.outputs.accountName
    aiProjectName: aiFoundryProject.outputs.projectName
    #disable-next-line BCP318
    connectedResourceName: searchService.outputs.name
  }
  dependsOn: [
    searchService!
  ]
}

module aiFoundryConnectionInsights 'modules/standard-setup/connection-application-insights.bicep' = if (deployAppInsights) {
  name: 'connection-appinsights-${resourceToken}'
  params: {
    aiFoundryName: aiFoundryAccount.outputs.accountName
    #disable-next-line BCP318
    connectedResourceName: appInsights.outputs.name
  }
  dependsOn: [
    appInsights!
  ]
}

module aiFoundryConnectionStorage 'modules/standard-setup/connection-storage-account.bicep' = if (deployStorageAccount) {
  name: 'connection-storage-account-${resourceToken}'
  params: {
    aiFoundryName: aiFoundryAccount.outputs.accountName
    #disable-next-line BCP318
    connectedResourceName: storageAccount.outputs.name
  }
  dependsOn: [
    storageAccount!
  ]
}

// Application Insights
//////////////////////////////////////////////////////////////////////////

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (deployAppInsights) {
  name: 'appInsights'
  params: {
    name: appInsightsName
    location: location
    #disable-next-line BCP318
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                _tags
  }
}

// Container Resources
//////////////////////////////////////////////////////////////////////////

//Container Apps Env User Managed Identity
module containerEnvUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${containerEnvName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${containerEnvName}'
    // Non-required parameters
    location: location
  }
}

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = if (deployContainerEnv) {
  name: 'containerEnv'
  params: {
    name: containerEnvName
    location: location
    tags: _tags
    // log & insights
    #disable-next-line BCP318
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    #disable-next-line BCP318
    appInsightsConnectionString: appInsights.outputs.connectionString
    zoneRedundant: false
    workloadProfiles: workloadProfiles
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [containerEnvUAI.outputs.resourceId] : []
    }
    infrastructureSubnetId: networkIsolation ? _caEnvSubnetId : ''
    internal: networkIsolation ? true : false
  }
}

//Container Registry User Managed Identity
module containerRegistryUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${containerRegistryName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${containerRegistryName}'
    // Non-required parameters
    location: location
  }
}

// Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = if (deployContainerRegistry) {
  name: 'containerRegistry'
  params: {
    name: containerRegistryName
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    location: location
    acrSku: networkIsolation ? 'Premium' : 'Basic'
    tags: _tags
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [containerRegistryUAI.outputs.resourceId] : []
    }
  }
}

//Container Apps User Managed Identity
module containerAppsUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = [
  for app in containerAppsList: if (useUAI) {
    name: '${const.abbrs.security.managedIdentity}${app.service_name}'
    params: {
      // Required parameters
      name: '${const.abbrs.security.managedIdentity}${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}'
      // Non-required parameters
      location: location
    }
  }
]

// Container Apps
@batchSize(4)
module containerApps 'br/public:avm/res/app/container-app:0.17.0' = [
  for (app, index) in containerAppsList: if (deployContainerApps) {
    name: empty(app.name) ? '${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}' : app.name
    params: {
      name: empty(app.name) ? '${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}' : app.name
      location: location
      #disable-next-line BCP318
      environmentResourceId: containerEnv.outputs.resourceId
      workloadProfileName: app.profile_name

      ingressExternal: networkIsolation ? false : true
      ingressTargetPort: 80
      ingressTransport: 'auto'
      ingressAllowInsecure: false

      dapr: {
        enabled: true
        appId: app.service_name
        appPort: 80
        appProtocol: 'http'
      }

      managedIdentities: {
        systemAssigned: (useUAI) ? false : true
        #disable-next-line BCP318
        userAssignedResourceIds: (useUAI) ? [containerAppsUAI[index].outputs.resourceId] : []
      }

      scaleSettings: {
        minReplicas: app.min_replicas
        maxReplicas: app.max_replicas
      }

      containers: [
        {
          name: app.service_name
          image: _containerDummyImageName
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'APP_CONFIG_ENDPOINT'
              value: 'https://${appConfigName}.azconfig.io'
            }
            {
              name: 'AZURE_TENANT_ID'
              value: subscription().tenantId
            }
            {
              name: 'AZURE_CLIENT_ID'
              #disable-next-line BCP318
              value: useUAI ? containerAppsUAI[index].outputs.clientId : ''
            }
          ]
        }
      ]

      tags: union(_tags, {
        'azd-service-name': app.service_name
      })
    }
    dependsOn: [
      containerEnv!                   
      privateDnsZoneContainerApps    
      privateEndpointContainerAppsEnv  
    ]
  }
]

// Cosmos DB Account and Database
//////////////////////////////////////////////////////////////////////////

//Cosmos User Managed Identity
module cosmosUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${dbAccountName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${dbAccountName}'
    // Non-required parameters
    location: location
  }
}

module cosmosDBAccount 'br/public:avm/res/document-db/database-account:0.12.0' = if (deployCosmosDb) {
  name: 'CosmosDBAccount'
  params: {
    name: dbAccountName
    location: location
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [cosmosUAI.outputs.resourceId] : []
    }

    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    defaultConsistencyLevel: 'Session'
    capabilitiesToAdd: ['EnableServerless']
    enableAnalyticalStorage: true
    enableFreeTier: false
    networkRestrictions: {
      publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    }
    tags: _tags
    sqlDatabases: [
      {
        name: dbDatabaseName
        throughput: 400
        containers: [
          for container in databaseContainersList: {
            name: container.name
            paths: ['/id']
            defaultTtl: -1
            throughput: 400
          }
        ]
      }
    ]
  }
}

// Key Vault
//////////////////////////////////////////////////////////////////////////

module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = if (deployKeyVault) {
  name: 'keyVault'
  params: {
    name: keyVaultName
    location: location
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    sku: 'standard'
    enableRbacAuthorization: true
    tags: _tags
  }
}

// Log Analytics Workspace
//////////////////////////////////////////////////////////////////////////

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = if (deployLogAnalytics) {
  name: 'logAnalytics'
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
    tags: _tags
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// AI Search
//////////////////////////////////////////////////////////////////////////

//Search Service User Managed Identity
module searchServiceUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (useUAI) {
  name: '${const.abbrs.security.managedIdentity}${searchServiceName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${searchServiceName}'
    // Non-required parameters
    location: location
  }
}

module searchService 'br/public:avm/res/search/search-service:0.10.0' = if (deploySearchService) {
  name: 'searchService'
  params: {
    name: searchServiceName
    location: location
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    tags: _tags

    // SKU & capacity
    sku: 'standard'
    replicaCount: 1
    semanticSearch: 'disabled'

    // Identity & Auth
    managedIdentities: {
      systemAssigned: useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: useUAI ? [searchServiceUAI.outputs.resourceId] : []
    }

    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sharedPrivateLinkResources: networkIsolation
      ? [
          // Storage (blob)
          {
            groupId: 'blob'
            #disable-next-line BCP318
            privateLinkResourceId: storageAccount.outputs.resourceId
            requestMessage: 'Automated link for Storage'
            provisioningState: 'Succeeded'
            status: 'Approved'
          }
          // AI Foundry Account
          {
            groupId: 'openai_account'
            #disable-next-line BCP318
            privateLinkResourceId: aiFoundryAccount.outputs.accountID
            requestMessage: 'Automated link for AI Foundry Account'
            provisioningState: 'Succeeded'
            status: 'Approved'
          }
        ]
      : []
  }
  dependsOn: [
    containerEnv!
    aiFoundryAccount!
    storageAccount!
  ]
}

// Storage Accounts
//////////////////////////////////////////////////////////////////////////

// Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = if (deployStorageAccount) {
  name: 'storageAccountSolution'
  params: {
    name: storageAccountName
    location: location
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    requireInfrastructureEncryption: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      defaultAction: 'Allow'
    }
    tags: _tags
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        for container in storageAccountContainersList: {
          name: container.name
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicyDays: 7
      deleteRetentionPolicyEnabled: true
      lastAccessTimeTrackingPolicyEnabled: true
    }
  }
}

// API Management
//////////////////////////////////////////////////////////////////////////
// Coming Soon

//////////////////////////////////////////////////////////////////////////
// ROLE ASSIGNMENTS
//////////////////////////////////////////////////////////////////////////

// Role assignments are centralized in this section to make it easier to view all permissions granted in this template.
// Custom modules are used for role assignments since no published AVM module available for this at the time we created this template.

// AI Foundry Storage Account - Storage Blob Data Contributor -> AI Foundry Project
module assignStorageAccountAiFoundryProject 'modules/standard-setup/azure-storage-account-role-assignment.bicep' = {
  name: 'assignStorageAccountAiFoundryProject'
  scope: resourceGroup(_azureStorageSubscriptionId, _azureStorageResourceGroupName)
  params: {
    azureStorageName: aiFoundryDependencies.outputs.azureStorageName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
}

// AI Foundry Cosmos DB Account - Cosmos DB Operator -> AI Foundry Project
module assignCosmosDBAiFoundryProject 'modules/standard-setup/cosmosdb-account-role-assignment.bicep' = {
  name: 'assignCosmosDBAiFoundryProject'
  scope: resourceGroup(_cosmosDBSubscriptionId, _cosmosDBResourceGroupName)
  params: {
    cosmosDBName: aiFoundryDependencies.outputs.cosmosDBName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
  dependsOn: [
    assignStorageAccountAiFoundryProject
  ]
}

// AI Foundry Search Service - Search Index Data Contributor -> AI Foundry Project
// AI Foundry Search Service - Search Service Contributor -> AI Foundry Project
module assignSearchAiFoundryProject 'modules/standard-setup/ai-search-role-assignments.bicep' = {
  name: 'assignSearchAiFoundryProject'
  scope: resourceGroup(_aiSearchServiceSubscriptionId, _aiSearchServiceResourceGroupName)
  params: {
    aiSearchName: aiFoundryDependencies.outputs.aiSearchName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
  dependsOn: [
    assignCosmosDBAiFoundryProject
    assignStorageAccountAiFoundryProject
  ]
}

// AI Foundry Storage Account - Storage Blob Data Owner (workspace-limited) -> AI Foundry Project
module assignStorageContainersAiFoundryProject 'modules/standard-setup/blob-storage-container-role-assignments.bicep' = {
  name: 'assignStorageContainersAiFoundryProject'
  scope: resourceGroup(_azureStorageSubscriptionId, _azureStorageResourceGroupName)
  params: {
    aiProjectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
    storageName: aiFoundryDependencies.outputs.azureStorageName
    workspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
  }
  dependsOn: [
    aiFoundryAddProjectCapabilityHost
  ]
}

// AI Foundry Cosmos DB Containers - Cosmos DB Built-in Data Contributor -> AI Foundry Project
module assignCosmosDBContainersAiFoundryProject 'modules/standard-setup/cosmos-container-role-assignments.bicep' = {
  name: 'assignCosmosDBContainersAiFoundryProject'
  scope: resourceGroup(_cosmosDBSubscriptionId, _cosmosDBResourceGroupName)
  params: {
    cosmosAccountName: aiFoundryDependencies.outputs.cosmosDBName
    projectWorkspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
  dependsOn: [
    aiFoundryAddProjectCapabilityHost
    assignStorageContainersAiFoundryProject
  ]
}

// Azure Container Registry Service - AcrPush -> Executor
module assignCrAcrPushExecutor 'modules/security/resource-role-assignment.bicep' = if (deployContainerRegistry) {
  name: 'assignCrAcrPushExecutor'
  params: {
    name: 'assignCrAcrPushExecutor'
    roleAssignments: concat([
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', const.roles.AcrPush.guid)
        #disable-next-line BCP318
        resourceId: containerRegistry.outputs.resourceId
        principalType: principalType
      }
    ])
  }
}

// Key Vault Service - Key Vault Contributor -> Executor
// Key Vault Service - Key Vault Secrets Officer -> Executor
module assignKeyVaultContributorAndSecretsOfficerExecutor 'modules/security/resource-role-assignment.bicep' = if (deployKeyVault) {
  name: 'assignKeyVaultContributorAndSecretsOfficerExecutor'
  params: {
    name: 'assignKeyVaultContributorAndSecretsOfficerExecutor'
    roleAssignments: concat([
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.KeyVaultContributor.guid
        )
        #disable-next-line BCP318
        resourceId: keyVault.outputs.resourceId
        principalType: principalType
      }
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.KeyVaultSecretsOfficer.guid
        )
        #disable-next-line BCP318
        resourceId: keyVault.outputs.resourceId
        principalType: principalType
      }
    ])
  }
}

// Key Vault Service - Key Vault Secrets User -> ContainerApp
module assignKeyVaultSecretsUserAca 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployKeyVault && contains(app.roles, const.roles.KeyVaultSecretsUser.key)) {
    name: 'assignKeyVaultSecretsUserAca-${app.service_name}'
    params: {
      name: 'assignKeyVaultSecretsUserAca-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.KeyVaultSecretsUser.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: keyVault.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Bastion Key Vault Service - Key Vault Secrets Officer  -> Executor
module assignKeyVaultSecretsOffExecutor 'modules/security/resource-role-assignment.bicep' = if (deployVM && networkIsolation) {
  name: 'assignKeyVaultSecretsOffExecutor'
  params: {
    name: 'assignKeyVaultSecretsOffExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.KeyVaultSecretsOfficer.guid
        )
        #disable-next-line BCP318
        resourceId: testVmKeyVault.outputs.resourceId
        principalType: principalType
      }
    ]
  }
}

// Search Service - Search Service Contributor -> Executor
module assignSearchSearchServiceContributorExecutor 'modules/security/resource-role-assignment.bicep' = if (deploySearchService) {
  name: 'assignSearchSearchServiceContributorExecutor'
  params: {
    name: 'assignSearchSearchServiceContributorExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.SearchServiceContributor.guid
        )
        #disable-next-line BCP318
        resourceId: searchService.outputs.resourceId
        principalType: principalType
      }
    ]
  }
}

// Search Service - Search Index Data Contributor -> Executor
module assignSearchSearchIndexDataContributorExecutor 'modules/security/resource-role-assignment.bicep' = if (deploySearchService) {
  name: 'assignSearchSearchIndexDataContributorExecutor'
  params: {
    name: 'assignSearchSearchIndexDataContributorExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.SearchIndexDataContributor.guid
        )
        #disable-next-line BCP318
        resourceId: searchService.outputs.resourceId
        principalType: principalType
      }
    ]
  }
}

// Storage Account - Storage Blob Data Contributor -> Executor
module assignStorageStorageBlobDataContributorExecutor 'modules/security/resource-role-assignment.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataContributorExecutor'
  params: {
    name: 'assignStorageStorageBlobDataContributorExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.StorageBlobDataContributor.guid
        )
        #disable-next-line BCP318
        resourceId: storageAccount.outputs.resourceId
        principalType: principalType
      }
    ]
  }
}

// AI Foundry Account - Azure AI Project Manager -> Executor
module assignAiFoundryAccountAzureAiProjectManagerExecutor 'modules/security/resource-role-assignment.bicep' = {
  name: 'assignAiFoundryAccountAzureAiProjectManagerExecutor'
  params: {
    name: 'assignAiFoundryAccountAzureAiProjectManagerExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.AzureAIProjectManager.guid
        )
        resourceId: aiFoundryAccount.outputs.accountID
        principalType: principalType
      }
    ]
  }
}

// Cosmos DB Account - Cosmos DB Built-in Data Contributor -> Executor
module assignCosmosDBCosmosDbBuiltInDataContributorExecutor 'modules/security/cosmos-data-plane-role-assignment.bicep' = if (deployCosmosDb) {
  name: 'assignCosmosDBCosmosDbBuiltInDataContributorExecutor'
  params: {
    #disable-next-line BCP318
    cosmosDbAccountName: cosmosDBAccount.outputs.name
    principalId: principalId
    roleDefinitionGuid: const.roles.CosmosDBBuiltInDataContributor.guid
    scopePath: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}'
  }
}

// App Configuration Settings Service - App Configuration Data Reader -> ContainerApp
module assignAppConfigAppConfigurationDataReaderContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployAppConfig && contains(
    app.roles,
    const.roles.AppConfigurationDataReader.key
  )) {
    name: 'assignAppConfigAppConfigurationDataReader-${app.service_name}'
    params: {
      name: 'assignAppConfigAppConfigurationDataReader-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.AppConfigurationDataReader.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: appConfig.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// AI Foundry Account - Cognitive Services User -> ContainerApp
module assignAiFoundryAccountCognitiveServicesUserContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(
    app.roles,
    const.roles.CognitiveServicesUser.key
  )) {
    name: 'assignAIFoundryAccountCognitiveServicesUser-${app.service_name}'
    params: {
      name: 'assignAIFoundryAccountCognitiveServicesUser-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.CognitiveServicesUser.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          resourceId: aiFoundryAccount.outputs.accountID
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// AI Foundry Account - Cognitive Services OpenAI User -> ContainerApp
module assignAIFoundryCogServOAIUserContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(
    app.roles,
    const.roles.CognitiveServicesOpenAIUser.key
  )) {
    name: 'assignAIFoundryCogServOAIUserContainerApps-${app.service_name}'
    params: {
      name: 'assignAIFoundryCogServOAIUserContainerApps-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.CognitiveServicesOpenAIUser.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          resourceId: aiFoundryAccount.outputs.accountID
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Azure Container Registry Service - AcrPull -> ContainerApp
module assignCrAcrPullContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployContainerRegistry && contains(app.roles, const.roles.AcrPull.key)) {
    name: 'assignCrAcrPull-${app.service_name}'
    params: {
      name: 'assignCrAcrPull-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', const.roles.AcrPull.guid)
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: containerRegistry.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Cosmos DB Account - Cosmos DB Built-in Data Contributor -> ContainerApp
module assignCosmosDBCosmosDbBuiltInDataContributorContainerApps 'modules/security/cosmos-data-plane-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployCosmosDb && contains(
    app.roles,
    const.roles.CosmosDBBuiltInDataContributor.key
  )) {
    name: 'assignCosmosDBCosmosDbBuiltInDataContributor-${app.service_name}'
    params: {
      #disable-next-line BCP318
      cosmosDbAccountName: cosmosDBAccount.outputs.name
      #disable-next-line BCP318
      principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinitionGuid: const.roles.CosmosDBBuiltInDataContributor.guid
      scopePath: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}'
    }
  }
]

// Key Vault Service - Key Vault Secrets User -> ContainerApp
module assignKeyVaultKeyVaultSecretsUserContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployKeyVault && contains(app.roles, const.roles.KeyVaultSecretsUser.key)) {
    name: 'assignKeyVaultKeyVaultSecretsUser-${app.service_name}'
    params: {
      name: 'assignKeyVaultKeyVaultSecretsUser-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.KeyVaultSecretsUser.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: keyVault.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Search Service - Search Index Data Reader -> ContainerApp
module assignSearchSearchIndexDataReaderContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deploySearchService && contains(
    app.roles,
    const.roles.SearchIndexDataReader.key
  )) {
    name: 'assignSearchSearchIndexDataReader-${app.service_name}'
    params: {
      name: 'assignSearchSearchIndexDataReader-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.SearchIndexDataReader.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI)  ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: searchService.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Search Service - Search Index Data Contributor -> ContainerApp
module assignSearchSearchIndexDataContributorContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deploySearchService && contains(
    app.roles,
    const.roles.SearchIndexDataContributor.key
  )) {
    name: 'assignSearchSearchIndexDataContributor-${app.service_name}'
    params: {
      name: 'assignSearchSearchIndexDataContributor-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.SearchIndexDataContributor.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId  : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: searchService.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Storage Account - Storage Blob Data Contributor -> ContainerApp
module assignStorageStorageBlobDataContributorAca 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(
    app.roles,
    const.roles.StorageBlobDataContributor.key
  )) {
    name: 'assignStorageStorageBlobDataContributor-${app.service_name}'
    params: {
      name: 'assignStorageStorageBlobDataContributor-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.StorageBlobDataContributor.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: storageAccount.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Storage Account - Storage Blob Data Reader -> ContainerApp
module assignStorageStorageBlobDataReaderAca 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(
    app.roles,
    const.roles.StorageBlobDataReader.key
  )) {
    name: 'assignStorageStorageBlobDataReaderAca-${app.service_name}'
    params: {
      name: 'assignStorageStorageBlobDataReaderAca-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.StorageBlobDataReader.guid
          )
          #disable-next-line BCP318
          principalId: (useUAI)  ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: storageAccount.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Storage Account - Storage Blob Data Reader -> Search Service
module assignStorageStorageBlobDataReaderSearch 'modules/security/resource-role-assignment.bicep' = if (deployStorageAccount && deploySearchService) {
  name: 'assignStorageStorageBlobDataReaderSearch'
  params: {
    name: 'assignStorageStorageBlobDataReaderSearch'
    roleAssignments: [
      {
        #disable-next-line BCP318
        principalId: (useUAI) ? searchServiceUAI.outputs.principalId : searchService.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.StorageBlobDataReader.guid
        )
        #disable-next-line BCP318
        resourceId: storageAccount.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Search Service - Search Index Data Reader -> AiFoundryProject
module assignSearchSearchIndexDataReaderAIFoundryProject 'modules/security/resource-role-assignment.bicep' = if (deploySearchService) {
  name: 'assignSearchSearchIndexDataReaderAIFoundryProject'
  params: {
    name: 'assignSearchSearchIndexDataReaderAIFoundryProject'
    roleAssignments: [
      {
        principalId: aiFoundryProject.outputs.projectPrincipalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.SearchIndexDataReader.guid
        )
        #disable-next-line BCP318
        resourceId: searchService.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Search Service - Search Service Contributor -> AiFoundryProject
module assignSearchSearchServiceContributorAIFoundryProject 'modules/security/resource-role-assignment.bicep' = if (deploySearchService) {
  name: 'assignSearchSearchServiceContributorAIFoundryProject'
  params: {
    name: 'assignSearchSearchServiceContributorAIFoundryProject'
    roleAssignments: [
      {
        principalId: aiFoundryProject.outputs.projectPrincipalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.SearchServiceContributor.guid
        )
        #disable-next-line BCP318
        resourceId: searchService.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Storage Account - Storage Blob Data Reader -> AiFoundry Project
module assignStorageStorageBlobDataReaderAIFoundryProject 'modules/security/resource-role-assignment.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataReaderAIFoundryProject'
  params: {
    name: 'assignStorageStorageBlobDataReaderAIFoundryProject'
    roleAssignments: [
      {
        principalId: aiFoundryProject.outputs.projectPrincipalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.StorageBlobDataReader.guid
        )
        #disable-next-line BCP318
        resourceId: storageAccount.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    assignSearchSearchServiceContributorAIFoundryProject
  ]
}

//////////////////////////////////////////////////////////////////////////
// App Configuration Settings Service
//////////////////////////////////////////////////////////////////////////

// App Configuration Store
//////////////////////////////////////////////////////////////////////////

module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = if (deployAppConfig) {
  name: 'appConfig'
  params: {
    name: appConfigName
    location: location
    sku: 'Standard'
    managedIdentities: {
      systemAssigned: true
    }
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionIdOrName: const.roles.AppConfigurationDataOwner.guid
      }
    ]
    tags: _tags
    dataPlaneProxy: {
      authenticationMode: 'Pass-through'
      privateLinkDelegation: 'Disabled'
    }
  }
}

// prepare the container apps settings for the app configuration store
module containerAppsSettings 'modules/container-apps/container-apps-list.bicep' = if (deployContainerApps) {
  name: 'containerAppsSettings'
  params: {
    containerAppsList: [
      for i in range(0, length(containerAppsList)): {
        #disable-next-line BCP318
        name: containerApps[i].outputs.name
        serviceName: containerAppsList[i].service_name
        canonical_name: containerAppsList[i].canonical_name
        #disable-next-line BCP318
        principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        fqdn: containerApps[i].outputs.fqdn
      }
    ]
  }
}

// prepare the model deployment names for the app configuration store
var _modelDeploymentNamesSettings = [
  for modelDeployment in modelDeploymentList: {
    name: modelDeployment.canonical_name
    value: modelDeployment.name
    label: 'gpt-rag'
    contentType: 'text/plain'
  }
]

// prepare the database container names for the app configuration store
var _databaseContainerNamesSettings = [
  for databaseContainer in databaseContainersList: {
    name: databaseContainer.canonical_name
    value: databaseContainer.name
    label: 'gpt-rag'
    contentType: 'text/plain'
  }
]

// prepare the storage container names for the app configuration store
var _storageContainerNamesSettings = [
  for storageContainer in storageAccountContainersList: {
    name: storageContainer.canonical_name
    value: storageContainer.name
    label: 'gpt-rag'
    contentType: 'text/plain'
  }
]

var outputModelDeploymentSettings = [
  for modelDeployment in modelDeploymentList: { 
    canonical_name: modelDeployment.canonical_name 
    capacity: modelDeployment.capacity
    model : modelDeployment.model
    modelFormat: modelDeployment.modelFormat
    name: modelDeployment.name
    version: modelDeployment.version
    endpoint: 'https://${const.abbrs.ai.aiFoundry}${resourceToken}.openai.azure.com/'
  }
]

module appConfigPopulate 'modules/app-configuration/app-configuration.bicep' = if (deployAppConfig) {
  name: 'appConfigPopulate'
  params: {
    #disable-next-line BCP318
    storeName: appConfig.outputs.name
    keyValues: concat(
      #disable-next-line BCP318
      containerAppsSettings.outputs.containerAppsEndpoints,
      #disable-next-line BCP318
      containerAppsSettings.outputs.containerAppsName,
      _modelDeploymentNamesSettings,
      _databaseContainerNamesSettings,
      _storageContainerNamesSettings,
      [
        // ── General / Deployment ─────────────────────────────────────────────
      { name: 'AZURE_TENANT_ID',     value: tenant().tenantId,                        label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'SUBSCRIPTION_ID',     value: subscription().subscriptionId,            label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'RESOURCE_GROUP_NAME', value: resourceGroup().name,                     label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'LOCATION',            value: location,                                 label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'ENVIRONMENT_NAME',    value: environmentName,                          label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOYMENT_NAME',     value: deployment().name,                        label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'RESOURCE_TOKEN',      value: resourceToken,                            label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'NETWORK_ISOLATION',   value: string(networkIsolation),                 label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'USE_UAI',             value: string(useUAI),                           label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'LOG_LEVEL',           value: 'INFO',                                   label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'ENABLE_CONSOLE_LOGGING',value: 'true',                                 label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'PROMPT_SOURCE',         value: 'file',                                 label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING',       value: appInsights.outputs.connectionString,   label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'APPLICATIONINSIGHTS__INSTRUMENTATIONKEY',     value: appInsights.outputs.instrumentationKey, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AGENT_STRATEGY',      value: 'single_agent_rag',                       label: 'gpt-rag', contentType: 'text/plain' }

      // ── Resource IDs ─────────────────────────────────────────────────────
      #disable-next-line BCP318
      { name: 'KEY_VAULT_RESOURCE_ID', value: keyVault.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'STORAGE_ACCOUNT_RESOURCE_ID', value: storageAccount.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'COSMOS_DB_ACCOUNT_RESOURCE_ID', value: cosmosDBAccount.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'APP_INSIGHTS_RESOURCE_ID', value: appInsights.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'LOG_ANALYTICS_RESOURCE_ID', value: logAnalytics.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'CONTAINER_ENV_RESOURCE_ID', value: containerEnv.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'CONTAINER_REGISTRY_RESOURCE_ID', value: containerRegistry.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_UAI_RESOURCE_ID', value: (useUAI) ? searchServiceUAI.outputs.resourceId : '', label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_RESOURCE_ID', value: searchService.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_ACCOUNT_RESOURCE_ID', value: aiFoundryAccount.outputs.accountID, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_RESOURCE_ID', value: aiFoundryProject.outputs.projectId, label: 'gpt-rag', contentType: 'text/plain' }

      // ── Resource Names ───────────────────────────────────────────────────
      { name: 'AI_FOUNDRY_ACCOUNT_NAME', value: aiFoundryAccountName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_NAME', value: aiFoundryProjectName, label: 'gpt-rag', contentType: 'text/plain' }
      {
        name: 'AI_FOUNDRY_STORAGE_ACCOUNT_NAME'
        value: aiFoundryStorageAccountName
        label: 'gpt-rag'
        contentType: 'text/plain'
      }
      { name: 'APP_CONFIG_NAME', value: appConfigName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'APP_INSIGHTS_NAME', value: appInsightsName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'CONTAINER_ENV_NAME', value: containerEnvName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'CONTAINER_REGISTRY_NAME', value: containerRegistryName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DATABASE_ACCOUNT_NAME', value: dbAccountName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DATABASE_NAME', value: dbDatabaseName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'SEARCH_SERVICE_NAME', value: searchServiceName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'STORAGE_ACCOUNT_NAME', value: storageAccountName, label: 'gpt-rag', contentType: 'text/plain' }

      // ── Feature flagging ─────────────────────────────────────────────────
      { name: 'DEPLOY_APP_CONFIG', value: string(deployAppConfig), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_KEY_VAULT', value: string(deployKeyVault), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_LOG_ANALYTICS', value: string(deployLogAnalytics), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_APP_INSIGHTS', value: string(deployAppInsights), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_SEARCH_SERVICE', value: string(deploySearchService), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_STORAGE_ACCOUNT', value: string(deployStorageAccount), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_COSMOS_DB', value: string(deployCosmosDb), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_CONTAINER_APPS', value: string(deployContainerApps), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_CONTAINER_REGISTRY', value: string(deployContainerRegistry), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOY_CONTAINER_ENV', value: string(deployContainerEnv), label: 'gpt-rag', contentType: 'text/plain' }

      // ── Endpoints / URIs ──────────────────────────────────────────────────
      { name: 'KEY_VAULT_URI',                   value: keyVault.outputs.uri,                        label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'CONTAINER_REGISTRY_LOGIN_SERVER', value: containerRegistry.outputs.loginServer,       label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'STORAGE_BLOB_ENDPOINT',           value: storageAccount.outputs.primaryBlobEndpoint,  label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'SEARCH_SERVICE_QUERY_ENDPOINT',   value: searchService.outputs.endpoint,              label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_ACCOUNT_ENDPOINT',     value: aiFoundryAccount.outputs.accountTarget,      label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_ENDPOINT',     value: aiFoundryProject.outputs.endpoint,           label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_WORKSPACE_ID', value: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'COSMOS_DB_ENDPOINT',              value: cosmosDBAccount.outputs.endpoint,            label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'ORCHESTRATOR_APP_APIKEY',         value: resourceToken,  label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'MCP_APP_APIKEY',                  value: resourceToken,  label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'INGESTION_APP_APIKEY',            value: resourceToken,  label: 'gpt-rag', contentType: 'text/plain' }
    
      // ── Connections ───────────────────────────────────────────────────────
      #disable-next-line BCP318
      { name: 'SEARCH_CONNECTION_ID', value: deploySearchService ? aiFoundryConnectionSearch.outputs.seachConnectionId : '', label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'BING_CONNECTION_ID', value: deployGroundingWithBing ? aiFoundryBingConnection.outputs.bingConnectionId : '', label: 'gpt-rag', contentType: 'text/plain' }

      // ── Managed Identity Principals ───────────────────────────────────────
      #disable-next-line BCP318
      { name: 'CONTAINER_ENV_PRINCIPAL_ID', value: containerEnv.outputs.systemAssignedMIPrincipalId!, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_PRINCIPAL_ID', value: searchService.outputs.systemAssignedMIPrincipalId!, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_ACCOUNT_PRINCIPAL_ID', value: aiFoundryAccount.outputs.accountPrincipalId, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_PRINCIPAL_ID', value: aiFoundryProject.outputs.projectPrincipalId, label: 'gpt-rag', contentType: 'text/plain' }

      // ── Module-Specific Connection Objects ─────────────────────────────────
      { name: 'AI_FOUNDRY_STORAGE_CONNECTION', value: aiFoundryProject.outputs.azureStorageConnection, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_COSMOS_DB_CONNECTION', value: aiFoundryProject.outputs.cosmosDBConnection, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_SEARCH_CONNECTION', value: aiFoundryProject.outputs.aiSearchConnection, label: 'gpt-rag', contentType: 'text/plain' }

      // ── Container Apps List & Model Deployments ────────────────────────────
      #disable-next-line BCP318
      { name: 'CONTAINER_APPS', value: string(containerAppsSettings.outputs.containerAppsList), label: 'gpt-rag', contentType: 'application/json' }
      { name: 'MODEL_DEPLOYMENTS', value: string(outputModelDeploymentSettings), label: 'gpt-rag', contentType: 'application/json' }
      ]
    )
  }
  dependsOn: [
    appConfig!
  ]
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// General / Deployment
// ──────────────────────────────────────────────────────────────────────
output TENANT_ID string = tenant().tenantId
output SUBSCRIPTION_ID string = subscription().subscriptionId
output RESOURCE_GROUP_NAME string = resourceGroup().name
output LOCATION string = location
output ENVIRONMENT_NAME string = environmentName
output DEPLOYMENT_NAME string = deployment().name
output RESOURCE_TOKEN string = resourceToken
output NETWORK_ISOLATION bool = networkIsolation

// ──────────────────────────────────────────────────────────────────────
// Feature flagging
// ──────────────────────────────────────────────────────────────────────
output DEPLOY_APP_CONFIG bool = deployAppConfig
output DEPLOY_KEY_VAULT bool = deployKeyVault
output DEPLOY_LOG_ANALYTICS bool = deployLogAnalytics
output DEPLOY_APP_INSIGHTS bool = deployAppInsights
output DEPLOY_SEARCH_SERVICE bool = deploySearchService
output DEPLOY_STORAGE_ACCOUNT bool = deployStorageAccount
output DEPLOY_COSMOS_DB bool = deployCosmosDb
output DEPLOY_CONTAINER_APPS bool = deployContainerApps
output DEPLOY_CONTAINER_REGISTRY bool = deployContainerRegistry
output DEPLOY_CONTAINER_ENV bool = deployContainerEnv

// ──────────────────────────────────────────────────────────────────────
// Endpoints / URIs
// ──────────────────────────────────────────────────────────────────────
#disable-next-line BCP318
output APP_CONFIG_ENDPOINT string = appConfig.outputs.endpoint
