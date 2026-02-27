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

// Important notes about parameters:
// 1) Before running azd provision, set parameter values using main.parameters.json or 
// the command line: azd env set ENV_VARIABLE_NAME value, for parameters configured to allow substitution.
//
// 2) You can identify these substitutable parameters in main.parameters.json by this format:
// "parameterName": { "value": "${ENV_VARIABLE_NAME}" }.
// This allows the convenience of setting values via the command line (e.g., azd env set ENV_VARIABLE_NAME true).
//
// 3) Substitutable parameters: if an environment variable isn’t set before running `azd provision`, its value will be empty.
// To prevent this, each parameter that uses the substitution mechanism has a corresponding Bicep variable (`_parameterName`) with a default value.
// When adding new substitutable parameters in this Bicep file or in `main.parameters.bicep`, follow the same pattern.

// ---------------------------------------------------------------------
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

@description('The Azure region where Cosmos DB will be created. Defaults to the resource group location.')
param cosmosLocation string = resourceGroup().location

@description('Principal ID for role assignments. This is typically the Object ID of the user or service principal running the deployment.')
param principalId string

@description('Principal type for role assignments. This can be "User", "ServicePrincipal", or "Group".')
param principalType string = 'User'

@description('Tags to apply to all resources in the deployment')
param deploymentTags object = {}

@description('Enable network isolation for the deployment. This will restrict public access to resources and require private endpoints where applicable.')
param networkIsolation bool = false

@description('Use an existing Virtual Network. When false, a new VNet will be created.')
param useExistingVNet bool = false

@description('The full ARM resource ID of an existing Virtual Network. Format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{vnetName}. Leave empty to create a new VNet.')
param existingVnetResourceId string = ''

param agentSubnetName string = 'agent-subnet'
param peSubnetName string = 'pe-subnet'
param gatewaySubnetName string = 'gateway-subnet'
param azureBastionSubnetName string = 'AzureBastionSubnet'
param azureFirewallSubnetName string = 'AzureFirewallSubnet'
param azureAppGatewaySubnetName string = 'AppGatewaySubnet'
param jumpboxSubnetName string = 'jumpbox-subnet'
param apiManagementSubnetName string = 'api-management-subnet'
param acaEnvironmentSubnetName string = 'aca-environment-subnet'
param devopsBuildAgentsSubnetName string = 'devops-build-agents-subnet'

@description('Address prefixes for the virtual network.')
param vnetAddressPrefixes array = [
  '192.168.0.0/21' // 192.168.0.0 – 192.168.7.255 (2048 IPs total)
]

//
// Subnet allocations (non-overlapping, optimized for production workloads)
// PE subnet increased to /26 to support multiple Private Endpoints without race conditions
//

@description('AI Foundry Agents subnet — Recommended /24 (256 IPs)')
param agentSubnetPrefix string = '192.168.0.0/24' // 192.168.0.0–192.168.0.255

@description('Azure Container Apps Environment subnet — /24 (256 IPs)') // Recommended minimum is /23
param acaEnvironmentSubnetPrefix string = '192.168.1.0/24' // 192.168.1.0–192.168.1.255

@description('Private Endpoints subnet — /26 (64 IPs) — Increased to prevent race conditions during parallel PE creation')
param peSubnetPrefix string = '192.168.2.0/26' // 192.168.2.0–192.168.2.63

@description('Azure Bastion subnet — Required /26 (64 IPs, CIDR-aligned)')
param azureBastionSubnetPrefix string = '192.168.2.64/26' // 192.168.2.64–192.168.2.127

@description('Azure Firewall subnet — /26 (64 IPs, CIDR-aligned)')
param azureFirewallSubnetPrefix string = '192.168.2.128/26' // 192.168.2.128–192.168.2.191

@description('Gateway subnet — Required /26 (64 IPs, CIDR-aligned)')
param gatewaySubnetPrefix string = '192.168.2.192/26' // 192.168.2.192–192.168.2.255

@description('Application Gateway subnet — /27 (32 IPs)')
param azureAppGatewaySubnetPrefix string = '192.168.3.0/27' // 192.168.3.0–192.168.3.31

@description('API Management subnet — /27 (32 IPs)')
param apimSubnetPrefix string = '192.168.3.32/27' // 192.168.3.32–192.168.3.63

@description('Jumpbox subnet — /27 (32 IPs)')
param jumpboxSubnetPrefix string = '192.168.3.64/27' // 192.168.3.64–192.168.3.95

@description('DevOps Build Agents subnet — /27 (32 IPs)')
param devopsBuildAgentsSubnetPrefix string = '192.168.3.96/27' // 192.168.3.96–192.168.3.127

// ----------------------------------------------------------------------
// Feature-flagging Params (as booleans with a default of true)
// ----------------------------------------------------------------------

// @description('If false, skips creating platform infrastructure such as Firewall, Jumpbox, Bastion, etc.')
// param greenFieldDeployment bool = true

@description('Whether to deploy Bing-powered grounding capabilities alongside your AI services.')
param deployGroundingWithBing bool = true

@description('Deploy Azure AI Foundry for building and managing AI models.')
param deployAiFoundry bool = true

@description('Deploy Azure AI Foundry agent subnet.')
param deployAiFoundrySubnet bool = true

@description('Deploy Azure App Configuration for centralized feature-flag and configuration management.')
param deployAppConfig bool = true

@description('Deploy an Azure Key Vault to securely store secrets, keys, and certificates.')
param deployKeyVault bool = true

@description('Deploy an Azure Key Vault to securely store VM secrets, keys, and certificates.')
param deployVmKeyVault bool = true

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

@description('Deploy the virtual network subnets.')
param deploySubnets bool = true

@description('Will deploy network security groups.')
param deployNsgs bool = true

@description('Will deploy network resources side by side with the Azure resources.')
param sideBySideDeploy bool = true

@description('Deploy Virtual Machine software.')
param deploySoftware bool = true

@description('Deploy API Management service.')
param deployApim bool = false

@description('Deploy AI Foundry Project.')
param deployAfProject bool = true

@description('Deploy AI Foundry Service.')
param deployAAfAgentSvc bool = true


@description('Enable agentic retrieval features in Azure AI Search indexes. Requires vectorizer configuration and semantic search.')
param enableAgenticRetrieval bool = false

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

@description('The Key Vault full ARM resource ID. Optional; if not provided, a new vault will be created.')
param keyVaultResourceId string = ''

// ----------------------------------------------------------------------
// Feature-flagging Params (as booleans with a default of false)
// ----------------------------------------------------------------------
param useUAI bool = false // Use User Assigned Identity (UAI)
param useCAppAPIKey bool = false // Use API Keys to connect to container apps
param useZoneRedundancy bool = false // Use Zone Redundancy

// ----------------------------------------------------------------------
// Resource Naming params
// ----------------------------------------------------------------------

@description('Unique token used to build deterministic resource names, derived from subscription ID, environment name, and location.')
param resourceToken string = toLower(uniqueString(subscription().id, environmentName, location))

@description('Name of the Azure AI Foundry account to create or reference.')
param aiFoundryAccountName string = '${const.abbrs.ai.aiFoundry}${resourceToken}'

@description('Name of the AI Foundry project resource.')
param aiFoundryProjectName string = '${const.abbrs.ai.aiFoundryProject}${resourceToken}'

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

param acrDnsSuffix string = (environment().name == 'AzureUSGovernment' ? 'azurecr.us' : environment().name == 'AzureChinaCloud'   ? 'azurecr.cn' : 'azurecr.io')

// ----------------------------------------------------------------------
// Cosmos DB Database params
// ----------------------------------------------------------------------

@description('Name of the Cosmos DB account to create')
param databaseContainersList array

// ----------------------------------------------------------------------
// VM params
// ----------------------------------------------------------------------

@description('The name of the Test VM. If left empty, a random name will be generated.')
param vmName string = ''

@description('Test vm user name. Needed only when choosing network isolation and create bastion option. If not you can leave it blank.')
param vmUserName string = ''

@secure()
@description('Admin password for the test VM user')
param vmAdminPassword string

@description('Size of the test VM')
param vmSize string = 'Standard_D8s_v5'

@description('Image SKU (e.g., win11-25h2-ent, win11-23h2-ent, 2022-datacenter).')
param vmImageSku string = 'win11-25h2-ent'

@description('Image publisher (Windows 11: MicrosoftWindowsDesktop, Windows Server: MicrosoftWindowsServer).')
param vmImagePublisher string = 'MicrosoftWindowsDesktop'

@description('Image offer (Windows 11: windows-11, Windows Server: WindowsServer).')
param vmImageOffer string = 'windows-11'

@description('Image version (use latest unless you need a pinned build).')
param vmImageVersion string = 'latest'


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

var _manifest = loadJsonContent('./manifest.json')
var _azdTags = { 'azd-env-name': environmentName }
var _tags = union(_azdTags, deploymentTags)
var _networkIsolation = empty(string(networkIsolation)) ? false : bool(networkIsolation)


// ----------------------------------------------------------------------
// Container vars
// ----------------------------------------------------------------------

var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ----------------------------------------------------------------------
// Networking vars
// ----------------------------------------------------------------------

// Parse existing VNet Resource ID if provided
var varVnetIdSegments = empty(existingVnetResourceId) ? [''] : split(existingVnetResourceId, '/')
var varExistingVnetSubscriptionId = length(varVnetIdSegments) >= 3 ? varVnetIdSegments[2] : subscription().subscriptionId
var varExistingVnetResourceGroupName = length(varVnetIdSegments) >= 5 ? varVnetIdSegments[4] : resourceGroup().name
var varExistingVnetName = length(varVnetIdSegments) >= 9 ? varVnetIdSegments[8] : ''

var virtualNetworkResourceId = _networkIsolation ? (useExistingVNet ? existingVnetResourceId : virtualNetwork!.outputs.resourceId) : ''

#disable-next-line BCP318
var _peSubnetId = _networkIsolation ? '${virtualNetworkResourceId}/subnets/${peSubnetName}' : ''
#disable-next-line BCP318
var _caEnvSubnetId = _networkIsolation ? '${virtualNetworkResourceId}/subnets/${acaEnvironmentSubnetName}' : ''
#disable-next-line BCP318
var _jumpbxSubnetId = _networkIsolation ? '${virtualNetworkResourceId}/subnets/${jumpboxSubnetName}' : ''
#disable-next-line BCP318
var _agentSubnetId = _networkIsolation ? '${virtualNetworkResourceId}/subnets/${agentSubnetName}' : ''

// ----------------------------------------------------------------------
// VM vars
// ----------------------------------------------------------------------

var _vmBaseName = !empty(vmName) ? vmName : 'testvm${resourceToken}'
var _vmName = substring(_vmBaseName, 0, 15)
var _vmUserName = !empty(vmUserName) ? vmUserName : 'testvmuser'

// ----------------------------------------------------------------------
// Container App vars
// ----------------------------------------------------------------------

var _containerAppsKeyVaultKeysTemp =  [
  for app in containerAppsList: {
    name: '${app.canonical_name}_APIKEY'
    value: resourceToken
    contentType: 'string'
  }
]
var _containerAppsKeyVaultKeys = _useCAppAPIKey ? _containerAppsKeyVaultKeysTemp : []

// ----------------------------------------------------------------------
// // Feature-flagging vars 
// ----------------------------------------------------------------------
var _useUAI         = empty(string(useUAI)) ? false : bool(useUAI)
var _useCAppAPIKey  = empty(string(useCAppAPIKey))? false : bool(useCAppAPIKey)

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

// Base subnets that are always included
var baseSubnets = [
      {
        name: agentSubnetName
        addressPrefix: agentSubnetPrefix 
        delegation: 'Microsoft.app/environments'
        serviceEndpoints: [
          'Microsoft.CognitiveServices'
        ]
      }
      {
        name: peSubnetName
        addressPrefix: peSubnetPrefix 
        serviceEndpoints: [
          'Microsoft.AzureCosmosDB'
        ]        
        delegation: ''
      }
      {
        name: gatewaySubnetName
        addressPrefix: gatewaySubnetPrefix 
        delegation: ''
        serviceEndpoints : []
      }
      {
        name: azureBastionSubnetName
        addressPrefix: azureBastionSubnetPrefix 
        delegation: ''
        serviceEndpoints : []
      }
      {
        name: azureFirewallSubnetName
        addressPrefix: azureFirewallSubnetPrefix 
        delegation: ''
        serviceEndpoints : []
      }
      {
        name: azureAppGatewaySubnetName
        addressPrefix: azureAppGatewaySubnetPrefix  
        delegation: ''
        serviceEndpoints : []
      }
      {
        name: jumpboxSubnetName
        addressPrefix: jumpboxSubnetPrefix 
        natGatewayResourceId: natGateway.id
        delegation: ''
        serviceEndpoints : []
      }
      {
        name: acaEnvironmentSubnetName
        addressPrefix: acaEnvironmentSubnetPrefix  
        delegation: 'Microsoft.app/environments'
        serviceEndpoints: [
          'Microsoft.AzureCosmosDB'
        ]
      }
      {
        name: devopsBuildAgentsSubnetName
        addressPrefix: devopsBuildAgentsSubnetPrefix 
        delegation: ''
        serviceEndpoints : []
      }
]


// Conditional subnet for API Management
var apimSubnet = deployApim ? [
  {
    name: apiManagementSubnetName
    addressPrefix: apimSubnetPrefix 
  }
] : []

// Combine all subnets based on feature flags
var subnets = concat(baseSubnets, apimSubnet)

module virtualNetworkSubnets 'modules/networking/subnets.bicep' = if (_networkIsolation && useExistingVNet && deploySubnets) {
  name: 'virtualNetworkSubnetsDeployment'
  params: {
    vnetName: useExistingVNet ? varExistingVnetName : vnetName
    location: location
    resourceGroupName: useExistingVNet ? varExistingVnetResourceGroupName : resourceGroup().name
    subscriptionId: useExistingVNet ? varExistingVnetSubscriptionId : subscription().subscriptionId
    tags: _tags
    addressPrefixes: vnetAddressPrefixes
    subnets: subnets
    deploySubnets : deploySubnets
    deployNsgs: deployNsgs
    useExistingVNet: useExistingVNet
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// VNet
// Note on IP address sizing: https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks#known-limitations
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (_networkIsolation && !useExistingVNet) {
  name: 'virtualNetworkDeployment'
  params: {
    // VNet sized /16 to fit all subnets
    addressPrefixes: vnetAddressPrefixes
    name: vnetName
    location: location

    tags: _tags
    subnets: subnets
  }
}

// Bastion Host
module testVmBastionHost 'br/public:avm/res/network/bastion-host:0.8.0' = if (deployVM && networkIsolation) {
  name: 'bastionHost'
  params: {
    // Bastion host name
    name: '${const.abbrs.security.bastion}testvm-${resourceToken}'
    #disable-next-line BCP318
    virtualNetworkResourceId: virtualNetworkResourceId
    location: location
    skuName: 'Standard'
    tags: _tags
    availabilityZones: useZoneRedundancy ? [1, 2, 3] : []

    // Configuration for the Public IP that the module will create
    publicIPAddressObject: {
      // Name for the Public IP resource
      name: '${const.abbrs.networking.publicIPAddress}bastion-${resourceToken}'
      publicIPAllocationMethod: 'Static'
      skuName: 'Standard'
      skuTier: 'Regional'
      availabilityZones: useZoneRedundancy ? [1, 2, 3] : []
      tags: _tags
    }
  }
  dependsOn: [
    #disable-next-line BCP321
    !useExistingVNet ? virtualNetwork : null
    #disable-next-line BCP321
    useExistingVNet ? virtualNetworkSubnets : null
  ]
}

//AI Foundry Search User Managed Identity
module testVmUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (_useUAI) {
  name: '${const.abbrs.security.managedIdentity}${_vmName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${_vmName}'
    // Non-required parameters
    location: location
  }
}

// Test VM
module testVm 'br/public:avm/res/compute/virtual-machine:0.15.0' = if (deployVM && _networkIsolation) {
  name: 'testVmDeployment'
  params: {
    name: _vmName
    location: location
    adminUsername: _vmUserName
    adminPassword: vmAdminPassword
    managedIdentities: {
      systemAssigned: _useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: _useUAI ? [testVmUAI.outputs.resourceId] : []
    }
    imageReference: {
      publisher: vmImagePublisher
      offer:     vmImageOffer
      sku:       vmImageSku
      version:   vmImageVersion
    }
    encryptionAtHost: false 
    vmSize: vmSize
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 250
      managedDisk: {
        storageAccountType: 'Standard_LRS'
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
    testVmBastionHost
    #disable-next-line BCP321
    !useExistingVNet ? virtualNetwork : null
    #disable-next-line BCP321
    useExistingVNet ? virtualNetworkSubnets : null
  ]
}

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (deployVM && _networkIsolation) {
  name: '${const.abbrs.networking.publicIPAddress}${const.abbrs.networking.natGateway}${resourceToken}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 30
    dnsSettings: {
      domainNameLabel: '${const.abbrs.networking.publicIPAddress}${const.abbrs.networking.natGateway}${resourceToken}'
    }
  }
  tags: _tags
}

#disable-next-line BCP081
resource natGateway 'Microsoft.Network/natGateways@2024-10-01' = if (deployVM && _networkIsolation) {
  name: '${const.abbrs.networking.natGateway}${resourceToken}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}

// Container Apps
// Container Apps Contributor
// -> TestVm
module assignContainerAppsTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployAppConfig && deployContainerRegistry && _networkIsolation) {
  name: 'assignContainerAppsTestVm'
  params: {
    name: 'assignContainerAppsTestVm'
    roleAssignments: [
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.ContainerAppsContributor.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: ''
        principalType: 'ServicePrincipal'
      }
      
    ]
  }
}

// Managed Identity Operator -> TestVm
module assignManagedIdentityOperatorTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployAppConfig && deployContainerRegistry && _networkIsolation) {
  name: 'assignManagedIdentityOperatorTestVm'
  params: {
    name: 'assignManagedIdentityOperatorTestVm'
    roleAssignments: [
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.ManagedIdentityOperator.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: ''
        principalType: 'ServicePrincipal'
      }
      
    ]
  }
}

// Container Registry
// Container Registry Repository Writer, Container Registry Tasks Contributor, Container Registry Contributor and Data Access Configuration Administrator
// -> TestVm

// AppConfig -> AppConfig Data Reader -> TestVm
module assignContainerRegistryTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployAppConfig && deployContainerRegistry && _networkIsolation) {
  name: 'assignContainerRegistryTestVm'
  params: {
    name: 'assignContainerRegistryTestVm'
    roleAssignments: [
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.ContainerRegistryRepositoryWriter.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: containerRegistry.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.ContainerRegistryContributorDataAccessConfigurationAdministrator.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: containerRegistry.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.ContainerRegistryTasksContributor.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: containerRegistry.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// AppConfig -> AppConfig Data Reader -> TestVm
module assignAppConfigAppConfigurationDataReaderTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployAppConfig && _networkIsolation) {
  name: 'assignAppConfigAppConfigurationDataReaderTestVm'
  params: {
    name: 'assignAppConfigAppConfigurationDataReaderTestVm'
    roleAssignments: [
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.AppConfigurationDataOwner.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: appConfig.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Azure Container Registry Service - AcrPush -> TestVm
module assignCrAcrPushTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployContainerRegistry && _networkIsolation) {
  name: 'assignCrAcrPushTestVm'
  params: {
    name: 'assignCrAcrPushTestVm'
    roleAssignments: concat([
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', const.roles.AcrPush.guid)
        #disable-next-line BCP318
        resourceId: containerRegistry.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ])
  }
}

// Key Vault Service - Key Vault Contributor -> TestVm
// Key Vault Service - Key Vault Secrets Officer -> TestVm
module assignKeyVaultContributorAndSecretsOfficerTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployKeyVault && _networkIsolation) {
  name: 'assignKeyVaultContributorAndSecretsOfficerTestVm'
  params: {
    name: 'assignKeyVaultContributorAndSecretsOfficerTestVm'
    roleAssignments: concat([
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.KeyVaultContributor.guid
        )
        #disable-next-line BCP318
        resourceId: keyVault.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.KeyVaultSecretsOfficer.guid
        )
        #disable-next-line BCP318
        resourceId: keyVault.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ])
  }
}

// Search Service - Search Service Contributor -> TestVm
module assignSearchSearchServiceContributorTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deploySearchService && _networkIsolation) {
  name: 'assignSearchSearchServiceContributorTestVm'
  params: {
    name: 'assignSearchSearchServiceContributorTestVm'
    roleAssignments: [
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
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

// Search Service - Search Index Data Contributor -> TestVm
module assignSearchSearchIndexDataContributorTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deploySearchService && _networkIsolation) {
  name: 'assignSearchSearchIndexDataContributorTestVm'
  params: {
    name: 'assignSearchSearchIndexDataContributorTestVm'
    roleAssignments: [
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.SearchIndexDataContributor.guid
        )
        #disable-next-line BCP318
        resourceId: searchService.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Cognitive Services Contributor -> TestVm (for RAI Blocklists)
module assignCognitiveServicesContributorTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployAiFoundry && _networkIsolation) {
  name: 'assignCognitiveServicesContributorTestVm'
  params: {
    name: 'assignCognitiveServicesContributorTestVm'
    roleAssignments: [
      {
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.CognitiveServicesContributor.guid
        )
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        #disable-next-line BCP318
        resourceId: aiFoundryAccountResourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}


// AI Foundry Account - Cognitive Services OpenAI User -> TestVm (for app testing)
module assignAIFoundryCogServOAIUserTestVm  'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry && deployVM && _networkIsolation) {
  name: 'assignAIFoundryCogServOAIUserTestVm'
  params: {
    name: 'assignAIFoundryCogServOAIUserTestVm'
    roleAssignments: [
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.CognitiveServicesOpenAIUser.guid
        )
        #disable-next-line BCP318
        resourceId: aiFoundryAccountResourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Storage Account - Storage Blob Data Contributor -> TestVm
module assignStorageStorageBlobDataContributorTestVm 'modules/security/resource-role-assignment.bicep' = if (deployVM && deployStorageAccount && _networkIsolation) {
  name: 'assignStorageStorageBlobDataContributorTestVm'
  params: {
    name: 'assignStorageStorageBlobDataContributorTestVm'
    roleAssignments: [
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.StorageBlobDataContributor.guid
        )
        #disable-next-line BCP318
        resourceId: storageAccount.outputs.resourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// Cosmos DB Account - Cosmos DB Built-in Data Contributor -> TestVm
module assignCosmosDBCosmosDbBuiltInDataContributorTestVm 'modules/security/cosmos-data-plane-role-assignment.bicep' = if (deployVM && deployCosmosDb && _networkIsolation) {
  name: 'assignCosmosDBCosmosDbBuiltInDataContributorTestVm'
  params: {
    #disable-next-line BCP318
    cosmosDbAccountName: cosmosDBAccount.outputs.name
    #disable-next-line BCP318
    principalId: (_useUAI) ? testVmUAI.outputs.principalId : testVm.outputs.systemAssignedMIPrincipalId!
    roleDefinitionGuid: const.roles.CosmosDBBuiltInDataContributor.guid
    scopePath: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}'
  }
}

var _fileUris = [
  'https://raw.githubusercontent.com/Azure/GPT-RAG/refs/tags/${_manifest.tag}/infra/install.ps1'
]

resource cse 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = if (deployVM && deploySoftware && _networkIsolation) {
  name: '${_vmName}/cse'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    forceUpdateTag: 'alwaysRun'
    settings: {
      fileUris: _fileUris
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File install.ps1 -release ${_manifest.tag} -UseUAI ${_useUAI} -ResourceToken ${resourceToken} -AzureTenantId ${subscription().tenantId} -AzureLocation ${location} -AzureSubscriptionId ${subscription().subscriptionId} -AzureResourceGroupName ${resourceGroup().name} -AzdEnvName ${environmentName}'
    }
    protectedSettings: {
      
    }
  }
  dependsOn: [
    testVm
    appConfigPopulate
    assignContainerAppsTestVm
    assignManagedIdentityOperatorTestVm
    assignContainerRegistryTestVm
    assignAppConfigAppConfigurationDataReaderTestVm
    assignSearchSearchServiceContributorTestVm
    assignSearchSearchIndexDataContributorTestVm
    assignCognitiveServicesContributorTestVm
    assignStorageStorageBlobDataContributorTestVm
    assignCosmosDBCosmosDbBuiltInDataContributorTestVm
  ]
}

// Private DNS Zones.
///////////////////////////////////////////////////////////////////////////

// AI Foundry Account
module privateDnsZoneCogSvcs 'modules/networking/private-dns.bicep' = if(_networkIsolation) {
  name: 'dep-cogsvcs-private-dns-zone'
  params: {
    dnsName: 'privatelink.cognitiveservices.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-cogsvcs-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// Open AI
module privateDnsZoneOpenAi 'modules/networking/private-dns.bicep' = if(_networkIsolation) {
  name: 'dep-openai-private-dns-zone'
  params: {
    dnsName: 'privatelink.openai.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-openai-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// AI Services
module privateDnsZoneAiServices 'modules/networking/private-dns.bicep' = if (_networkIsolation) {
  name: 'dep-aiservices-private-dns-zone'
  params: {
    dnsName: 'privatelink.services.ai.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-aiservices-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// AI Search
module privateDnsZoneSearch 'modules/networking/private-dns.bicep' = if (_networkIsolation){
  name: 'dep-search-std-private-dns-zone'
  params: {
    dnsName: 'privatelink.search.windows.net'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-search-std-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// Cosmos DB
module privateDnsZoneCosmos 'modules/networking/private-dns.bicep' = if (_networkIsolation) {
  name: 'dep-cosmos-std-private-dns-zone'
  params: {
    dnsName: 'privatelink.documents.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-cosmos-std-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// Storage Account
module privateDnsZoneBlob 'modules/networking/private-dns.bicep' = if (_networkIsolation) {
  name: 'dep-blob-std-private-dns-zone'
  params: {
    dnsName: 'privatelink.blob.${environment().suffixes.storage}'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-blob-std-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// Key Vault
module privateDnsZoneKeyVault 'modules/networking/private-dns.bicep' = if (_networkIsolation) {
  name: 'dep-kv-std-private-dns-zone'
  params: {
    dnsName: 'privatelink.vaultcore.azure.net'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-kv-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}


// Application Configuration
module privateDnsZoneAppConfig 'modules/networking/private-dns.bicep' = if (_networkIsolation){
  name: 'appconfig-private-dns-zone'
  params: {
    dnsName: 'privatelink.azconfig.io'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-appcfg-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}


// Application Insights
module privateDnsZoneInsights 'modules/networking/private-dns.bicep' = if (_networkIsolation){
  name: 'appinsights-private-dns-zone'
  params: {
    dnsName: 'privatelink.applicationinsights.io'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-appi-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// Container Apps
module privateDnsZoneContainerApps 'modules/networking/private-dns.bicep' = if (_networkIsolation && deployContainerApps)  {
  name: 'containerapps-private-dns-zone'
  params: {
    dnsName: 'privatelink.${location}.azurecontainerapps.io'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-containerapps-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}


// Container Registry 
module privateDnsZoneAcr 'modules/networking/private-dns.bicep' = if (_networkIsolation && deployContainerRegistry) {
  name: 'containerregistry-private-dns-zone'
  params: {
    dnsName: 'privatelink.${acrDnsSuffix}'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName: '${vnetName}-containerregistry-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
  dependsOn: [
    virtualNetwork!
    virtualNetworkSubnets!
  ]
}

// Private Endpoints.
///////////////////////////////////////////////////////////////////////////


// Storage Account
module privateEndpointStorageBlob 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deployStorageAccount) {
  name: 'blob-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${storageAccountName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'blobConnection${useExistingVNet?'-byon':''}'
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
module privateEndpointCosmos 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deployCosmosDb) {
  name: 'cosmos-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${dbAccountName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'cosmosConnection${useExistingVNet?'-byon':''}'
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
    privateEndpointStorageBlob // Serialize PE operations to avoid conflicts
  ]
}

// AI Search
module privateEndpointSearch 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deploySearchService) {
  name: 'search-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${searchServiceName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'searchConnection${useExistingVNet?'-byon':''}'
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
    privateEndpointCosmos // Serialize PE operations to avoid conflicts
  ]
}

// Key Vault
module privateEndpointKeyVault 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deployKeyVault) {
  name: 'kv-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${keyVaultName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'kvConnection${useExistingVNet?'-byon':''}'
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
    privateEndpointSearch // Serialize PE operations to avoid conflicts
  ]
}

// Application Configuration
module privateEndpointAppConfig 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deployAppConfig) {
  name: 'appconfig-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${appConfigName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'appConfigConnection${useExistingVNet?'-byon':''}'
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
    privateEndpointKeyVault // Serialize PE operations to avoid conflicts
  ]
}

// Container Apps Environment
module privateEndpointContainerAppsEnv 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deployContainerEnv) {
  name: 'dep-containerapps-env-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${containerEnvName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
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
    privateEndpointAppConfig // Serialize PE operations to avoid conflicts
  ]
}

module privateEndpointAcr 'modules/networking/private-endpoint.bicep' = if (_networkIsolation && deployContainerRegistry) {
  name: 'dep-acr-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${containerRegistryName}'
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    location: location
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: '${containerRegistryName}-registry-connection'
        properties: {
          privateLinkServiceId: containerRegistry!.outputs.resourceId
          groupIds: ['registry'] 
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'acrDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'acr'
          privateDnsZoneResourceId: privateDnsZoneAcr!.outputs.resourceId // privatelink.azurecr.io
        }
      ]
    }
  }
  dependsOn: [
    containerRegistry!
    privateDnsZoneAcr!
    privateEndpointContainerAppsEnv
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


var _dnsZonesSubscriptionId = useExistingVNet && !sideBySideDeploy ? varExistingVnetSubscriptionId : subscription().subscriptionId
var _dnsZonesResourceGroupName = useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
var _dnsZoneCogSvcsId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.cognitiveservices.azure.com')
var _dnsZoneOpenAiId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.openai.azure.com')
var _dnsZoneAiServicesId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.services.ai.azure.com')
var _dnsZoneSearchId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.search.windows.net')
var _dnsZoneCosmosId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.documents.azure.com')
var _dnsZoneBlobId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
var _dnsZoneKeyVaultId = resourceId(_dnsZonesSubscriptionId, _dnsZonesResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')

//AI Foundry Account User Managed Identity
module aiFoundryUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (_useUAI) {
  name: '${const.abbrs.security.managedIdentity}${aiFoundryAccountName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${aiFoundryAccountName}'
    // Non-required parameters
    location: location
  }
}

// 16.1 AI Foundry Configuration
module aiFoundry 'modules/ai-foundry/main.bicep' = if (deployAiFoundry) {
  name: '${aiFoundryAccountName}-${resourceToken}-deployment'
  params: {
    // Required
    baseName: substring(resourceToken, 0, 10)

    includeAssociatedResources: true
    location: location
    tags: deploymentTags

    privateEndpointSubnetResourceId: varPeSubnetId

    aiFoundryConfiguration: {
      accountName: aiFoundryAccountName
      allowProjectManagement: deployAfProject
      createCapabilityHosts: deployAAfAgentSvc
      location: location

      networking: varAfNetworkingOverride

      project: deployAfProject
        ? {
            name: 'aifoundry-default-project'
            displayName: 'Default AI Foundry Project.'
            description: 'This is the default project for AI Foundry.'
          }
        : null
    }

    aiModelDeployments: !empty(modelDeploymentList)
      ? modelDeploymentList
      : [
          {
            model: {
              format: 'OpenAI'
              name: 'gpt-5-mini'
              version: '2025-08-07'
            }
            name: 'gpt-5-mini'
            sku: {
              name: 'GlobalStandard'
              capacity: 10
            }
          }
          {
            model: {
              format: 'OpenAI'
              name: 'text-embedding-3-large'
              version: '1'
            }
            name: 'text-embedding-3-large'
            sku: {
              name: 'Standard'
              capacity: 1
            }
          }
        ]

    aiSearchConfiguration: varAfAiSearchCfgComplete
    cosmosDbConfiguration: varAfCosmosCfgComplete
    keyVaultConfiguration: varAfKVCfgComplete
    storageAccountConfiguration: varAfStorageCfgComplete

    enableTelemetry: true
  }
  dependsOn: [
    #disable-next-line BCP321
    (aiSearchResourceId == '' && deploySearchService) ? searchService : null
    #disable-next-line BCP321
    (_networkIsolation && !useExistingVNet) ? virtualNetwork : null
    #disable-next-line BCP321
    (_networkIsolation && useExistingVNet && deploySubnets) ? virtualNetworkSubnets : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneSearch : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneCogSvcs : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneOpenAi : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneAiServices : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneBlob : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneCosmos : null
    #disable-next-line BCP321
    _networkIsolation ? privateDnsZoneKeyVault : null
  ]
}


var varPeSubnetId = empty(existingVnetResourceId!)
  ? '${virtualNetworkResourceId}/subnets/pe-subnet'
  : '${existingVnetResourceId!}/subnets/pe-subnet'

var varAfNetworkingOverride = _networkIsolation ? {
  agentServiceSubnetResourceId: deployAiFoundrySubnet ? _agentSubnetId : null
  cognitiveServicesPrivateDnsZoneResourceId: _dnsZoneCogSvcsId
  openAiPrivateDnsZoneResourceId: _dnsZoneOpenAiId
  aiServicesPrivateDnsZoneResourceId: _dnsZoneAiServicesId
} : null

var varAfAiSearchCfgComplete = {
  existingResourceId: aiSearchResourceId != '' ? aiSearchResourceId : null
  name: aiFoundrySearchServiceName
  privateDnsZoneResourceId: _networkIsolation ? _dnsZoneSearchId : null
  roleAssignments: []
}

var varAfCosmosCfgComplete = {
  existingResourceId: aiFoundryCosmosDBAccountResourceId != '' ? aiFoundryCosmosDBAccountResourceId : null
  name: aiFoundryCosmosDbName
  privateDnsZoneResourceId: _networkIsolation ? _dnsZoneCosmosId : null
  roleAssignments: []
}

var varAfKVCfgComplete = {
  existingResourceId: keyVaultResourceId != '' ? keyVaultResourceId : null
  name: '${const.abbrs.security.keyVault}ai-${resourceToken}'
  privateDnsZoneResourceId: _networkIsolation ? _dnsZoneKeyVaultId : null
  roleAssignments: []
}

var varAfStorageCfgComplete = {
  existingResourceId: aiFoundryStorageAccountResourceId != '' ? aiFoundryStorageAccountResourceId : null
  name: aiFoundryStorageAccountName
  blobPrivateDnsZoneResourceId: _networkIsolation ? _dnsZoneBlobId : null
  roleAssignments: []
}

var aiFoundryAccountResourceId = resourceId('Microsoft.CognitiveServices/accounts', aiFoundry!.outputs.aiServicesName)

var aiFoundryProjectResourceId = resourceId(
  'Microsoft.CognitiveServices/accounts/projects', 
  aiFoundry!.outputs.aiServicesName, 
  aiFoundry!.outputs.aiProjectName 
)

var aiFoundryAccountEndpoint = 'https://${aiFoundry!.outputs.aiServicesName}.cognitiveservices.azure.com/'

var aiFoundryProjectEndpoint = 'https://${aiFoundry!.outputs.aiServicesName}.services.ai.azure.com/api/projects/${aiFoundry!.outputs.aiProjectName}'

// Bing Search Connection (optional)
module bingSearchConnection 'modules/bing-search/main.bicep' = if (deployAiFoundry && deployGroundingWithBing) {
  name: 'bingSearchConnection-${resourceToken}'
  params: {
    accountName: aiFoundry!.outputs.aiServicesName
    projectName: aiFoundry!.outputs.aiProjectName
    bingSearchName: bingSearchName
  }
  dependsOn: [
    aiFoundry!
  ]
}

// AI Foundry Connections
//////////////////////////////////////////////////////////////////////////

// Bing Search Connection
module aiFoundryBingConnection 'modules/ai-foundry/connection-bing-search-tool.bicep' = if (deployAiFoundry && deployGroundingWithBing) {
  name: '${bingSearchName}-connection'
  params: {
    account_name: aiFoundry!.outputs.aiServicesName
    project_name: aiFoundry!.outputs.aiProjectName
    bingSearchName: bingSearchName
  }
  dependsOn: [
    aiFoundry!
  ]
}

// AI Search Connection
module aiFoundryConnectionSearch 'modules/ai-foundry/connection-ai-search.bicep' = if (deployAiFoundry && deploySearchService) {
  name: 'connection-ai-search-${resourceToken}'
  params: {
    aiFoundryName: aiFoundry!.outputs.aiServicesName
    aiProjectName: aiFoundry!.outputs.aiProjectName
    connectedResourceName: searchService!.outputs.name
  }
  dependsOn: [
    aiFoundry!
    searchService!
  ]
}

// Application Insights Connection
module aiFoundryConnectionInsights 'modules/ai-foundry/connection-application-insights.bicep' = if (deployAiFoundry && deployAppInsights) {
  name: 'connection-appinsights-${resourceToken}'
  params: {
    aiFoundryName: aiFoundry!.outputs.aiServicesName
    connectedResourceName: appInsights!.outputs.name
  }
  dependsOn: [
    aiFoundry!
    appInsights!
  ]
}

// Storage Account Connection
module aiFoundryConnectionStorage 'modules/ai-foundry/connection-storage-account.bicep' = if (deployAiFoundry && deployStorageAccount) {
  name: 'connection-storage-account-${resourceToken}'
  params: {
    aiFoundryName: aiFoundry!.outputs.aiServicesName
    connectedResourceName: storageAccount!.outputs.name
  }
  dependsOn: [
    aiFoundry!
    storageAccount!
  ]
}

// Application Insights
//////////////////////////////////////////////////////////////////////////
var appInsightsInvalidLocations = ['westcentralus']

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (deployAppInsights) {
  name: 'appInsights'
  params: {
    name: appInsightsName
    location: contains(appInsightsInvalidLocations, location) ? 'eastus' : location
    #disable-next-line BCP318
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                _tags
  }
}

//private link scope
resource privateLinkScope 'microsoft.insights/privatelinkscopes@2021-07-01-preview' = if (_networkIsolation && deployAppInsights) {
  name: '${const.abbrs.networking.privateLinkScope}${resourceToken}'
  location: 'global'
  properties :{
    accessModeSettings : {
      queryAccessMode : 'Open'
      ingestionAccessMode : 'Open'
    }
  }
  dependsOn: [
    appInsights!
  ]
}

module privateDnsZoneAzureMonitor 'modules/networking/private-dns.bicep' = if (_networkIsolation && deployContainerRegistry)  {
  name: 'azure-monitor-private-dns-zone'
  params: {
    dnsName: 'privatelink.monitor.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-azure-monitor-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

module privateDnsZoneOmsOpsInsights 'modules/networking/private-dns.bicep' = if (_networkIsolation && deployContainerRegistry)  {
  name: 'oms-opinsights-private-dns-zone'
  params: {
    dnsName: 'privatelink.oms.opinsights.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-oms-opinsights-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

module privateDnsZoneOdsOpsInsights 'modules/networking/private-dns.bicep' = if (_networkIsolation && deployContainerRegistry)  {
  name: 'ods-opinsights-private-dns-zone'
  params: {
    dnsName: 'privatelink.ods.opinsights.azure.com'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-ods-opinsights-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

module privateDnsZoneAzureAutomation 'modules/networking/private-dns.bicep' = if (_networkIsolation && deployContainerRegistry)  {
  name: 'azure-automation-private-dns-zone'
  params: {
    dnsName: 'privatelink.agentsvc.azure.automation.net'
    location: 'global'
    tags: _tags
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    virtualNetworkLinkName : '${vnetName}-azure-automation-link${useExistingVNet?'-byon':''}'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

module privateEndpointPrivateLinkScope 'modules/networking/private-endpoint.bicep' = if (_networkIsolation) {
  name: 'privatelink-scope-private-endpoint'
  params: {
    name: '${const.abbrs.networking.privateEndpoint}${const.abbrs.networking.privateLinkScope}${resourceToken}'
    location: location
    resourceGroupName: useExistingVNet && !sideBySideDeploy ? varExistingVnetResourceGroupName : resourceGroup().name
    tags: _tags
    subnetResourceId: _peSubnetId
    privateLinkServiceConnections: [
      {
        name: 'privateLinkScopeConnection'
        properties: {
          privateLinkServiceId: privateLinkScope.id
          groupIds: ['azuremonitor']
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'privateLinkDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'azuremonitorARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneAzureMonitor.outputs.resourceId
        }
        {
          name: 'omsinsightsARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneOmsOpsInsights.outputs.resourceId
        }
        {
          name: 'odsinsightsARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneOdsOpsInsights.outputs.resourceId
        }
        {
          name: 'automationARecord'
          #disable-next-line BCP318
          privateDnsZoneResourceId: privateDnsZoneAzureAutomation.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    privateLinkScope!
    privateEndpointAcr // Serialize PE operations to avoid conflicts
  ]
}

resource privateLinkScopedResources1 'microsoft.insights/privatelinkscopes/scopedresources@2021-07-01-preview' = if (_networkIsolation && deployAppInsights) {
  name: '${const.abbrs.networking.privateLinkScope}${resourceToken}/${logAnalyticsWorkspaceName}'!
  properties :{
    #disable-next-line BCP318
    linkedResourceId: logAnalytics.outputs.resourceId
  }
  dependsOn: [
    privateLinkScope
  ]
}

resource privateLinkScopedResources2 'microsoft.insights/privatelinkscopes/scopedresources@2021-07-01-preview' = if (_networkIsolation && deployAppInsights) {
  name: '${const.abbrs.networking.privateLinkScope}${resourceToken}/${appInsightsName}'!
  properties :{
    #disable-next-line BCP318
    linkedResourceId: appInsights.outputs.resourceId
  }
  dependsOn: [
    privateLinkScope
  ]
}

// Container Resources
//////////////////////////////////////////////////////////////////////////

//Container Apps Env User Managed Identity
module containerEnvUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (_useUAI) {
  name: '${const.abbrs.security.managedIdentity}${containerEnvName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${containerEnvName}'
    // Non-required parameters
    location: location
  }
}

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.11.3' = if (deployContainerEnv) {
  name: 'containerEnv'
  params: {
    name: containerEnvName
    location: location
    tags: _tags
    // log & insights
    #disable-next-line BCP318
    appLogsConfiguration: {
      //destination: deployAppInsights ? 'log-analytics' : 'none'
      //logAnalyticsConfiguration: {
      //  customerId: appInsights.outputs.applicationId
      //  sharedKey: appInsights.outputs.instrumentationKey
      //}
    }
    #disable-next-line BCP318
    appInsightsConnectionString: appInsights.outputs.connectionString
    zoneRedundant: useZoneRedundancy
    workloadProfiles: workloadProfiles
    managedIdentities: {
      systemAssigned: _useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: _useUAI ? [containerEnvUAI.outputs.resourceId] : []
    }
    infrastructureSubnetResourceId: networkIsolation ? _caEnvSubnetId : ''
    internal: networkIsolation ? true : false
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
  }
  dependsOn: [
    appInsights!
    logAnalytics!
    #disable-next-line BCP321
    !useExistingVNet ? virtualNetwork : null
    #disable-next-line BCP321
    useExistingVNet ? virtualNetworkSubnets : null
  ]
}

//Container Registry User Managed Identity
module containerRegistryUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (_useUAI) {
  name: '${const.abbrs.security.managedIdentity}${containerRegistryName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${containerRegistryName}'
    // Non-required parameters
    location: location
  }
}

// Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.3' = if (deployContainerRegistry) {
  name: 'containerRegistry'
  params: {
    name: containerRegistryName
    publicNetworkAccess: _networkIsolation ? 'Disabled' : 'Enabled'
    location: location
    acrSku: _networkIsolation ? 'Premium' : 'Basic'
    tags: _tags
    zoneRedundancy: useZoneRedundancy ? 'Enabled' : 'Disabled'
    managedIdentities: {
      systemAssigned: _useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: _useUAI ? [containerRegistryUAI.outputs.resourceId] : []
    }
    exportPolicyStatus: 'enabled'
    dataEndpointEnabled: _networkIsolation ? true : false    
  }
}

//Container Apps User Managed Identity
module containerAppsUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = [
  for app in containerAppsList: if (_useUAI) {
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
module containerApps 'br/public:avm/res/app/container-app:0.18.1' = [
  for (app, index) in containerAppsList: if (deployContainerApps) {
    name: empty(app.name) ? '${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}' : app.name
    params: {
      name: empty(app.name) ? '${const.abbrs.containers.containerApp}${resourceToken}-${app.service_name}' : app.name
      location: location
      #disable-next-line BCP318
      environmentResourceId: containerEnv.outputs.resourceId
      workloadProfileName: app.profile_name

      ingressExternal: app.external
      ingressTargetPort: 8080
      ingressTransport: 'auto'
      ingressAllowInsecure: false

      dapr: {
        enabled: true
        appId: app.service_name
        appPort: 8080
        appProtocol: 'http'
      }

      managedIdentities: {
        systemAssigned: (_useUAI) ? false : true
        #disable-next-line BCP318
        userAssignedResourceIds: (_useUAI) ? [containerAppsUAI[index].outputs.resourceId] : []
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
              value: _useUAI ? containerAppsUAI[index].outputs.clientId : ''
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
module cosmosUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (_useUAI) {
  name: '${const.abbrs.security.managedIdentity}${dbAccountName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${dbAccountName}'
    // Non-required parameters
    location: location
  }
}

module cosmosDBAccount 'br/public:avm/res/document-db/database-account:0.15.1' = if (deployCosmosDb) {
  name: 'CosmosDBAccount'
  params: {
    name: dbAccountName
    location: cosmosLocation
    managedIdentities: {
      systemAssigned: _useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: _useUAI ? [cosmosUAI.outputs.resourceId] : []
    }
    failoverLocations: [
      {
        locationName: cosmosLocation
        failoverPriority: 0
        isZoneRedundant: useZoneRedundancy
      }
    ]
    defaultConsistencyLevel: 'Session'
    capabilitiesToAdd: ['EnableServerless']
    enableAnalyticalStorage: true
    enableFreeTier: false
    networkRestrictions: {
      publicNetworkAccess: _networkIsolation ? 'Disabled' : 'Enabled'
      virtualNetworkRules: _networkIsolation ? [
        {
          subnetResourceId: _peSubnetId
          ignoreMissingVnetServiceEndpoint: true
        }
        {
          subnetResourceId: _caEnvSubnetId
          ignoreMissingVnetServiceEndpoint: true
        }
      ] : []
    }
    tags: _tags
    sqlDatabases: [
      {
        name: dbDatabaseName
        throughput: 400
        containers: [
          for container in databaseContainersList: {
            name: container.name
            paths: [container.partitionKey]
            defaultTtl: -1
            throughput: 400
            indexingPolicy: contains(container, 'indexingPolicy') ? container.indexingPolicy : null
          }
        ]
      }
    ]
  }
  dependsOn: [
    #disable-next-line BCP321
    (_networkIsolation) ? virtualNetwork : null
  ]
}

// Key Vault
//////////////////////////////////////////////////////////////////////////

module keyVault 'br/public:avm/res/key-vault/vault:0.13.3' = if (deployKeyVault) {
  name: 'keyVault'
  params: {
    name: keyVaultName
    location: location
    publicNetworkAccess: _networkIsolation ? 'Disabled' : 'Enabled'
    sku: 'standard'
    enableRbacAuthorization: true
    tags: _tags
  }
}

resource existingkeyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
  dependsOn: [
    keyVault
  ]
}

// Provision Container App secrets in Key Vault (only happens when useAPIKeys is true)
resource secret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = [for (config, i) in _containerAppsKeyVaultKeys: {
  parent: existingkeyVault
  name: replace(config.name, '_', '-')
  properties: {
      contentType: config.contentType
      value:  config.value
  }
  tags: {}
}
]

// Log Analytics Workspace
//////////////////////////////////////////////////////////////////////////

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.12.0' = if (deployLogAnalytics) {
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
module searchServiceUAI 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (_useUAI) {
  name: '${const.abbrs.security.managedIdentity}${searchServiceName}'
  params: {
    // Required parameters
    name: '${const.abbrs.security.managedIdentity}${searchServiceName}'
    // Non-required parameters
    location: location
  }
}

module searchService 'br/public:avm/res/search/search-service:0.11.1' = if (deploySearchService) {
  name: 'searchService'
  params: {
    name: searchServiceName
    location: location
    publicNetworkAccess: _networkIsolation ? 'Disabled' : 'Enabled'
    tags: _tags

    // SKU & capacity
    sku: 'standard'
    replicaCount: 1
    semanticSearch: enableAgenticRetrieval ? 'standard' : 'disabled'

    // Identity & Auth
    managedIdentities: {
      systemAssigned: _useUAI ? false : true
      #disable-next-line BCP318
      userAssignedResourceIds: _useUAI ? [searchServiceUAI.outputs.resourceId] : []
    }

    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sharedPrivateLinkResources: _networkIsolation
      ? [
          // {
          //   groupId: 'blob'
          //   #disable-next-line BCP318
          //   privateLinkResourceId: storageAccount.outputs.resourceId
          //   requestMessage: 'Automated link for Storage'
          //   provisioningState: 'Succeeded'
          //   status: 'Approved'
          // }
        ]
      : []
  }
  dependsOn: [
    containerEnv!
    storageAccount!
  ]
}

// Storage Accounts
//////////////////////////////////////////////////////////////////////////

// Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.26.2' = if (deployStorageAccount) {
  name: 'storageAccountSolution'
  params: {
    name: storageAccountName
    location: location
    publicNetworkAccess: _networkIsolation ? 'Disabled' : 'Enabled'
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

// Azure Container Registry Service - AcrPush -> Executor
module assignCrAcrPushPullExecutor 'modules/security/resource-role-assignment.bicep' = if (deployContainerRegistry) {
  name: 'assignCrAcrPushPullExecutor'
  params: {
    name: 'assignCrAcrPushPullExecutor'
    roleAssignments: concat([
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', const.roles.AcrPush.guid)
        #disable-next-line BCP318
        resourceId: containerRegistry.outputs.resourceId
        principalType: principalType
      }
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', const.roles.AcrPull.guid)
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: keyVault.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

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

// Search Service - Search Index Data Reader -> Executor
module assignSearchSearchIndexDataReaderExecutor 'modules/security/resource-role-assignment.bicep' = if (deploySearchService) {
  name: 'assignSearchSearchIndexDataReaderExecutor'
  params: {
    name: 'assignSearchSearchIndexDataReaderExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.SearchIndexDataReader.guid
        )
        #disable-next-line BCP318
        resourceId: searchService.outputs.resourceId
        principalType: principalType
      }
    ]
  }
}

// AI Foundry Account - Cognitive Services OpenAI User -> Executor
module assignAIFoundryCogServOAIUserExecutor 'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry) {
  name: 'assignAIFoundryCogServOAIUserExecutor'
  params: {
    name: 'assignAIFoundryCogServOAIUserExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.CognitiveServicesOpenAIUser.guid
        )
        #disable-next-line BCP318
        resourceId: aiFoundryAccountResourceId
        principalType: principalType
      }
    ]
  }
}

// AI Foundry Account - Cognitive Services  User -> Executor
module assignAIFoundryCogServUserExecutor 'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry) {
  name: 'assignAIFoundryCogServUserExecutor'
  params: {
    name: 'assignAIFoundryCogServUserExecutor'
    roleAssignments: [
      {
        principalId: principalId
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.CognitiveServicesUser.guid
        )
        #disable-next-line BCP318
        resourceId: aiFoundryAccountResourceId
        principalType: principalType
      }
    ]
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
  for (app, i) in containerAppsList: if (deployAiFoundry && contains(
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          resourceId: aiFoundryAccountResourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// AI Foundry Account - Cognitive Services OpenAI User -> ContainerApp
module assignAIFoundryCogServOAIUserContainerApps 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployAiFoundry && contains(
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          resourceId: aiFoundryAccountResourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// AI Foundry Account - Cognitive Services User -> Search Service (for agentic retrieval vectorizers)
module assignAiFoundryAccountCognitiveServicesUserSearch 'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry && deploySearchService) {
  name: 'assignAiFoundryAccountCognitiveServicesUserSearch'
  params: {
    name: 'assignAiFoundryAccountCognitiveServicesUserSearch'
    roleAssignments: [
      {
        #disable-next-line BCP318
        principalId: (_useUAI) ? searchServiceUAI.outputs.principalId : searchService.outputs.systemAssignedMIPrincipalId!
        roleDefinitionId: subscriptionResourceId(
          'Microsoft.Authorization/roleDefinitions',
          const.roles.CognitiveServicesUser.guid
        )
        resourceId: aiFoundryAccountResourceId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
      principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
          principalId: (_useUAI)  ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId  : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
          principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
          principalId: (_useUAI)  ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
          #disable-next-line BCP318
          resourceId: storageAccount.outputs.resourceId
          principalType: 'ServicePrincipal'
        }
      ]
    }
  }
]

// Storage Account - Storage Blob Data Delegator -> ContainerApp
module assignStorageStorageBlobDataDelegatorAca 'modules/security/resource-role-assignment.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(
    app.roles,
    const.roles.StorageBlobDelegator.key
  )) {
    name: 'assignStorageStorageBlobDataDelegatorAca-${app.service_name}'
    params: {
      name: 'assignStorageStorageBlobDataDelegatorAca-${app.service_name}'
      roleAssignments: [
        {
          roleDefinitionId: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            const.roles.StorageBlobDelegator.guid
          )
          #disable-next-line BCP318
          principalId: (_useUAI)  ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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
        principalId: (_useUAI) ? searchServiceUAI.outputs.principalId : searchService.outputs.systemAssignedMIPrincipalId!
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
module assignSearchSearchIndexDataReaderAIFoundryProject 'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry && deploySearchService) {
  name: 'assignSearchSearchIndexDataReaderAIFoundryProject'
  params: {
    name: 'assignSearchSearchIndexDataReaderAIFoundryProject'
    roleAssignments: [
      {
        principalId: aiFoundry!.outputs.aiProjectPrincipalId
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
module assignSearchSearchServiceContributorAIFoundryProject 'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry && deploySearchService) {
  name: 'assignSearchSearchServiceContributorAIFoundryProject'
  params: {
    name: 'assignSearchSearchServiceContributorAIFoundryProject'
    roleAssignments: [
      {
        principalId: aiFoundry!.outputs.aiProjectPrincipalId
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
module assignStorageStorageBlobDataReaderAIFoundryProject 'modules/security/resource-role-assignment.bicep' = if (deployAiFoundry && deployStorageAccount) {
  name: 'assignStorageStorageBlobDataReaderAIFoundryProject'
  params: {
    name: 'assignStorageStorageBlobDataReaderAIFoundryProject'
    roleAssignments: [
      {
        principalId: aiFoundry!.outputs.aiProjectPrincipalId
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

module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.9.1' = if (deployAppConfig) {
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
        principalId: (_useUAI) ? containerAppsUAI[i].outputs.principalId : containerApps[i].outputs.systemAssignedMIPrincipalId!
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

var _modelDeploymentSettings = [
  for modelDeployment in modelDeploymentList: { 
    canonical_name: modelDeployment.canonical_name 
    capacity: modelDeployment.sku.capacity          
    model: modelDeployment.model.name                  
    modelFormat: modelDeployment.model.format          
    name: modelDeployment.name
    version: modelDeployment.model.version         
    apiVersion: modelDeployment.?apiVersion ?? '2025-01-01-preview' 
    endpoint: 'https://${aiFoundryAccountName}.openai.azure.com/' 
  }
]

// Populate App Configuration store with Container App API keys (only when useAPIKeys is true).
module appConfigKeyVaultPopulate 'modules/app-configuration/app-configuration.bicep' = if (deployAppConfig && deployKeyVault && _useCAppAPIKey) {
  name: 'appConfigKeyVaultPopulate'
  params: {
    #disable-next-line BCP318
    storeName: appConfig.outputs.name
    keyValues:  [ 
      for app in containerAppsList: {
            name: '${app.canonical_name}_APIKEY'
            #disable-next-line BCP318
            value: '{"uri":"${keyVault.outputs.uri}secrets/${replace(app.canonical_name, '_', '-')}-APIKEY"}'
            label: 'gpt-rag'
            contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
      }
    ]
  }
}

module cosmosConfigKeyVaultPopulate 'modules/app-configuration/app-configuration.bicep' = if (deployCosmosDb && deployAppConfig) {
  name: 'cosmosConfigKeyVaultPopulate'
  params: {
    #disable-next-line BCP318
    storeName: appConfig.outputs.name
    keyValues: concat(
      [
        #disable-next-line BCP318
      { name: 'COSMOS_DB_ACCOUNT_RESOURCE_ID', value: cosmosDBAccount.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'COSMOS_DB_ENDPOINT',              value: cosmosDBAccount.outputs.endpoint,            label: 'gpt-rag', contentType: 'text/plain' }
      ]
    )
  }
}

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
      { name: 'AZURE_TENANT_ID',     value: tenant().tenantId,                      label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'SUBSCRIPTION_ID',     value: subscription().subscriptionId,          label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AZURE_RESOURCE_GROUP', value: resourceGroup().name,                  label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'LOCATION',            value: location,                               label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'ENVIRONMENT_NAME',    value: environmentName,                        label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'DEPLOYMENT_NAME',     value: deployment().name,                      label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'RESOURCE_TOKEN',      value: resourceToken,                          label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'ENABLE_AGENTIC_RETRIEVAL', value: toLower(string(enableAgenticRetrieval)), label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'NETWORK_ISOLATION',   value: toLower(string(_networkIsolation)),     label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'USE_UAI',             value: string(_useUAI),                        label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'LOG_LEVEL',           value: 'INFO',                                 label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'ENABLE_CONSOLE_LOGGING', value: 'true',                              label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'PROMPT_SOURCE',       value: 'file',                                 label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'GPT_RAG_RELEASE',     value: _manifest.release,                      label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.outputs.connectionString,   label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'APPLICATIONINSIGHTS__INSTRUMENTATIONKEY', value: appInsights.outputs.instrumentationKey, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AGENT_STRATEGY', value: 'single_agent_rag', label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AGENT_ID', value: '', label: 'gpt-rag', contentType: 'text/plain' }

      //── Resource IDs ─────────────────────────────────────────────────────
      #disable-next-line BCP318
      { name: 'KEY_VAULT_RESOURCE_ID', value: keyVault.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'STORAGE_ACCOUNT_RESOURCE_ID', value: storageAccount.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'APP_INSIGHTS_RESOURCE_ID', value: appInsights.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'LOG_ANALYTICS_RESOURCE_ID', value: logAnalytics.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'CONTAINER_ENV_RESOURCE_ID', value: containerEnv.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_ACCOUNT_RESOURCE_ID', value: (deployAiFoundry) ? aiFoundryAccountResourceId : '', label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_RESOURCE_ID', value: (deployAiFoundry) ? aiFoundryProjectResourceId : '', label: 'gpt-rag', contentType: 'text/plain' }
      // { name: 'AI_FOUNDRY_PROJECT_WORKSPACE_ID', value: (deployAiFoundry) ? aiFoundryFormatProjectWorkspaceId!.outputs.projectWorkspaceIdGuid : '', label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_UAI_RESOURCE_ID', value: (_useUAI) ? searchServiceUAI.outputs.resourceId : '', label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_RESOURCE_ID', value: searchService.outputs.resourceId, label: 'gpt-rag', contentType: 'text/plain' }
      
      // ── Resource Names ───────────────────────────────────────────────────
      { name: 'AI_FOUNDRY_ACCOUNT_NAME', value: aiFoundryAccountName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_PROJECT_NAME', value: aiFoundryProjectName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_STORAGE_ACCOUNT_NAME', value: aiFoundryStorageAccountName, label: 'gpt-rag', contentType: 'text/plain'}
      { name: 'APP_CONFIG_NAME', value: appConfigName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'APP_INSIGHTS_NAME', value: appInsightsName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'CONTAINER_ENV_NAME', value: containerEnvName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'CONTAINER_REGISTRY_NAME', value: containerRegistryName, label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'CONTAINER_REGISTRY_LOGIN_SERVER', value: '${containerRegistryName}.azurecr.io', label: 'gpt-rag', contentType: 'text/plain' }
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
      #disable-next-line BCP318
      { name: 'KEY_VAULT_URI',                   value: keyVault.outputs.uri,                        label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'STORAGE_BLOB_ENDPOINT',           value: storageAccount.outputs.primaryBlobEndpoint,  label: 'gpt-rag', contentType: 'text/plain' }
      { name: 'AI_FOUNDRY_ACCOUNT_ENDPOINT',     value: (deployAiFoundry) ? aiFoundryAccountEndpoint : '', label: 'gpt-rag', contentType: 'text/plain' }      
      { name: 'AI_FOUNDRY_PROJECT_ENDPOINT',     value: (deployAiFoundry) ? aiFoundryProjectEndpoint : '', label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_QUERY_ENDPOINT',   value: searchService.outputs.endpoint,              label: 'gpt-rag', contentType: 'text/plain' }

      // ── Connections ───────────────────────────────────────────────────────
      #disable-next-line BCP318
      { name: 'SEARCH_CONNECTION_ID', value: deploySearchService && deployAiFoundry ? aiFoundryConnectionSearch.outputs.searchConnectionId : '', label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'BING_CONNECTION_ID', value: deployGroundingWithBing && deployAiFoundry ? bingSearchConnection!.outputs.bingConnectionId : '', label: 'gpt-rag', contentType: 'text/plain' }

      //── Managed Identity Principals ───────────────────────────────────────
      #disable-next-line BCP318
      { name: 'CONTAINER_ENV_PRINCIPAL_ID', value: (_useUAI) ? containerEnvUAI.outputs.principalId : containerEnv.outputs.systemAssignedMIPrincipalId!, label: 'gpt-rag', contentType: 'text/plain' }
      #disable-next-line BCP318
      { name: 'SEARCH_SERVICE_PRINCIPAL_ID', value: (_useUAI) ? searchServiceUAI.outputs.principalId : searchService.outputs.systemAssignedMIPrincipalId!, label: 'gpt-rag', contentType: 'text/plain' }

      // ── Container Apps List & Model Deployments ────────────────────────────
      #disable-next-line BCP318
      { name: 'CONTAINER_APPS', value: string(containerAppsSettings.outputs.containerAppsList), label: 'gpt-rag', contentType: 'application/json' }
      { name: 'MODEL_DEPLOYMENTS', value: string(_modelDeploymentSettings), label: 'gpt-rag', contentType: 'application/json' }

      // ── Service-specific (gpt-rag-ingestion) settings. 
      //    In future releases, these should be removed here and defined with default values directly in the ingestion service. ─────────────
      { name: 'CRON_RUN_BLOB_PURGE', value: '0 * * * *', label: 'gpt-rag-ingestion', contentType: 'text/plain' }      
      { name: 'CRON_RUN_BLOB_INDEX', value: '10 * * * *', label: 'gpt-rag-ingestion', contentType: 'text/plain' }

    ]
    )
  }
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// General / Deployment
// ──────────────────────────────────────────────────────────────────────
output TENANT_ID string = tenant().tenantId
output SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = resourceGroup().name
output LOCATION string = location
output ENVIRONMENT_NAME string = environmentName
output DEPLOYMENT_NAME string = deployment().name
output RESOURCE_TOKEN string = resourceToken
output NETWORK_ISOLATION bool = _networkIsolation
output USE_UAI bool = _useUAI
output USE_CAPP_API_KEY bool = _useCAppAPIKey
output GPT_RAG_RELEASE string = _manifest.release

// ──────────────────────────────────────────────────────────────────────
// Feature flagging
// ──────────────────────────────────────────────────────────────────────
output DEPLOY_APP_CONFIG bool = deployAppConfig
output DEPLOY_SOFTWARE bool = deploySoftware
output DEPLOY_KEY_VAULT bool = deployKeyVault
output DEPLOY_LOG_ANALYTICS bool = deployLogAnalytics
output DEPLOY_APP_INSIGHTS bool = deployAppInsights
output DEPLOY_SEARCH_SERVICE bool = deploySearchService
output DEPLOY_STORAGE_ACCOUNT bool = deployStorageAccount
output DEPLOY_COSMOS_DB bool = deployCosmosDb
output DEPLOY_CONTAINER_APPS bool = deployContainerApps
output DEPLOY_CONTAINER_REGISTRY bool = deployContainerRegistry
output DEPLOY_CONTAINER_ENV bool = deployContainerEnv
output DEPLOY_VM_KEY_VAULT bool = deployVmKeyVault

// ──────────────────────────────────────────────────────────────────────
// Endpoints / URIs
// ──────────────────────────────────────────────────────────────────────
#disable-next-line BCP318
output APP_CONFIG_ENDPOINT string = deployAppConfig ? appConfig.outputs.endpoint : ''
