// ============================================================================
// GPT-RAG Main Bicep Deployment Template
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
// General Parameters
// ----------------------------------------------------------------------
@description('Name of the Azure Developer CLI environment')
param environmentName    string                            

@description('The Azure region where your AI Foundry resource and project will be created.')
param location           string = resourceGroup().location 

@description('Principal ID for role assignments. This is typically the Object ID of the user or service principal running the deployment.')
param principalId        string                             

@description('Tags to apply to all resources in the deployment')
param deploymentTags     object = {}                       

@description('Enable network isolation for the deployment. This will restrict public access to resources and require private endpoints where applicable.')
param networkIsolation   bool   = false 

// ----------------------------------------------------------------------
// Standard Setup Parameters
// ----------------------------------------------------------------------

// Optionally bring existing resources
@description('The AI Search Service full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiSearchResourceId string = ''

@description('The AI Storage Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiFoundryStorageAccountResourceId string = ''

@description('The Cosmos DB Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiFoundryCosmosDBAccountResourceId string = ''

@description('The name of the project capability host to be used for the AI Foundry project.')
param projectCapHost string = 'caphostproj'

@description('The name of the account capability host to be used for the AI Foundry account.')
param accountCapHost string = 'caphostacc'

// ----------------------------------------------------------------------
// Feature-flagging Params (as booleans with a default of true)
// ----------------------------------------------------------------------

param deployGroundingWithBing          bool = true
param deployAppConfig                  bool = true
param deployKeyVault                   bool = true
param deployLogAnalytics               bool = true
param deployAppInsights                bool = true
param deploySearchService              bool = true
param deployStorageAccount             bool = true
param deployCosmosDb                   bool = true
param deployContainerApps              bool = true
param deployContainerRegistry          bool = true
param deployContainerEnv               bool = true

// ----------------------------------------------------------------------
// Resource Naming params
// ----------------------------------------------------------------------

@description('Unique token for resource names, derived from the subscription ID, environment name, and location')
param resourceToken                string = toLower(uniqueString(subscription().id, environmentName, location))

param aiFoundryAccountName         string = '${abbrs.aiFoundry}-${resourceToken}'
param aiFoundryProjectName         string = '${abbrs.aiFoundryProject}-${resourceToken}' 
param aiFoundryProjectDisplayName  string = '${abbrs.aiFoundryProject}-${resourceToken}' 
param aiFoundryProjectDescription  string = '${abbrs.aiFoundryProject}-${resourceToken} Project' 
param aiFoundryStorageAccountName  string = '${abbrs.storageAccounts}foundry0${resourceToken}'
param aiFoundrySearchServiceName   string = '${abbrs.searchSearchServices}-foundry-${resourceToken}'
param aiFoundryCosmosDbName        string = '${abbrs.cosmosDbAccount}-foundry-${resourceToken}'
param bingSearchName               string = '${abbrs.bingSearch}-${resourceToken}'  
param appConfigName                string = '${abbrs.appConfigurationStores}-${resourceToken}'
param appInsightsName              string = '${abbrs.insightsComponents}-${resourceToken}'
param containerEnvName             string = '${abbrs.containerEnvs}${resourceToken}'
param containerRegistryName        string = '${abbrs.containerRegistries}${resourceToken}'
param dbAccountName                string = '${abbrs.cosmosDbAccount}-${resourceToken}'
param dbDatabaseName               string = '${abbrs.cosmosDbDatabase}-${resourceToken}'
param keyVaultName                 string = '${abbrs.keyVaultVaults}-${resourceToken}'
param logAnalyticsWorkspaceName    string = '${abbrs.operationalInsightsWorkspaces}-${resourceToken}'
param searchServiceName            string = '${abbrs.searchSearchServices}-${resourceToken}'
param storageAccountName           string = '${abbrs.storageAccounts}${resourceToken}'

param abbrs object = {
  aiFoundry:                     'aif'
  aiFoundryProject:              'proj'
  storageAccounts:               'st'
  keyVaultVaults:                'kv'
  searchSearchServices:          'srch'
  cosmosDbAccount:               'cosmos'
  cosmosDbDatabase:              'cosmos'
  appConfigurationStores:        'appcs'
  insightsComponents:            'appi'
  containerEnvs:                 'cae'
  containerRegistries:           'cr'
  operationalInsightsWorkspaces: 'log'
  bingSearch:                    'bing'
  containerApps:                 'ca'
}

// ----------------------------------------------------------------------
// Azure AI Foundry Service params
// ----------------------------------------------------------------------

@description('List of model deployments to create in the AI Foundry account')
param modelDeploymentList                 array  

// ----------------------------------------------------------------------
// Container Apps params
// ----------------------------------------------------------------------

@description('List of container apps to create')
param containerAppsList                   array 

// ----------------------------------------------------------------------
// Cosmos DB Database params
// ----------------------------------------------------------------------

@description('Name of the Cosmos DB account to create')
param databaseContainersList             array 

// ----------------------------------------------------------------------
// Storage Account params
// ----------------------------------------------------------------------

@description('List of containers to create in the Storage Account')
param storageAccountContainersList        array 

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
var _roles = loadJsonContent('./roles.json')

// ----------------------------------------------------------------------
// Container vars
// ----------------------------------------------------------------------

var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ----------------------------------------------------------------------
// Standard Setup vars
// ----------------------------------------------------------------------

// Check if existing resources have been passed in
var storagePassedIn = aiFoundryStorageAccountResourceId != ''
var searchPassedIn = aiSearchResourceId != ''
var cosmosPassedIn = aiFoundryCosmosDBAccountResourceId != ''

var acsParts = split(aiSearchResourceId, '/')
var aiSearchServiceSubscriptionId = searchPassedIn ? acsParts[2] : subscription().subscriptionId
var aiSearchServiceResourceGroupName = searchPassedIn ? acsParts[4] : resourceGroup().name

var cosmosParts = split(aiFoundryCosmosDBAccountResourceId, '/')
var cosmosDBSubscriptionId = cosmosPassedIn ? cosmosParts[2] : subscription().subscriptionId
var cosmosDBResourceGroupName = cosmosPassedIn ? cosmosParts[4] : resourceGroup().name

var storageParts = split(aiFoundryStorageAccountResourceId, '/')
var azureStorageSubscriptionId = storagePassedIn ? storageParts[2] : subscription().subscriptionId
var azureStorageResourceGroupName = storagePassedIn ? storageParts[4] : resourceGroup().name

//////////////////////////////////////////////////////////////////////////
// RESOURCES 
//////////////////////////////////////////////////////////////////////////

// AI Foundry Standard Setup
//////////////////////////////////////////////////////////////////////////

// Custom modules are used for AI Foundry Account and Project (V2) since no published AVM module available at this time.
// Custom modules based on AI Foundry Documentation Samples:
// https://github.com/azure-ai-foundry/foundry-samples/tree/main/samples/microsoft/infrastructure-setup

module aiFoundryValidateExistingResources 'modules/standard-setup/validate-existing-resources.bicep' = {
  name: 'validate-existing-resources-${resourceToken}-deployment'
  params: {
    aiSearchResourceId: aiSearchResourceId
    azureStorageAccountResourceId: aiFoundryStorageAccountResourceId
    azureCosmosDBAccountResourceId: aiFoundryCosmosDBAccountResourceId
  }
}

// This module will create new agent dependent resources
// A Cosmos DB account, an AI Search Service, and a Storage Account are created if they do not already exist
module aiFoundryDependencies 'modules/standard-setup/standard-dependent-resources.bicep' = {
  name: 'dependencies-${aiFoundryAccountName}-${resourceToken}-deployment'
  params: {
    location: location
    azureStorageName: aiFoundryStorageAccountName
    aiSearchName: aiFoundrySearchServiceName
    cosmosDBName: aiFoundryCosmosDbName

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
    location: location
    modelDeployments: modelDeploymentList
  }
  dependsOn: [
    aiFoundryValidateExistingResources, aiFoundryDependencies
  ]
}

// Creates a new project (sub-resource of the AI Services account)
module aiFoundryProject 'modules/standard-setup/ai-project-identity.bicep' = {
  name: 'ai-${aiFoundryProjectName}-${resourceToken}-deployment'
  params: {
    projectName: aiFoundryProjectName
    projectDescription: aiFoundryProjectDescription
    displayName: aiFoundryProjectDisplayName
    location: location

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

module aiFoundryFormatProjectWorkspaceId 'modules/standard-setup/format-project-workspace-id.bicep' = {
  name: 'format-project-workspace-id-${resourceToken}-deployment'
  params: {
    projectWorkspaceId: aiFoundryProject.outputs.projectWorkspaceId
  }
}

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
  dependsOn: [
    assignSearchAiFoundryProject, assignCosmosDBAiFoundryProject, assignStorageAccountAiFoundryProject
  ]
}


// AI Foundry Connections

module aiFoundryBingConnection 'modules/standard-setup/ai-foundry-bing-search-tool.bicep' = if (deployGroundingWithBing) {
  name:  '${bingSearchName}-connection' 
  params: {
    account_name: aiFoundryAccount.outputs.accountName
    project_name: aiFoundryProject.outputs.projectName
    bingSearchName: bingSearchName   
  }
}

module aiFoundryConnectionSearch 'modules/standard-setup/connection-ai-search.bicep' = if (deploySearchService) {
  name: 'connection-ai-search-${resourceToken}'
  params: {
    aiFoundryName:         aiFoundryAccount.outputs.accountName
    aiProjectName:         aiFoundryProject.outputs.projectName 
    connectedResourceName: searchService.outputs.name
  }
  dependsOn: [
    searchService!
  ]
}

module aiFoundryConnectionInsights 'modules/standard-setup/connection-application-insights.bicep' = if (deployAppInsights) {
  name: 'connection-appinsights-${resourceToken}'
  params: {
    aiFoundryName:         aiFoundryAccount.outputs.accountName
    connectedResourceName: appInsights.outputs.name
  }
  dependsOn: [
    appInsights!
  ]
}

module aiFoundryConnectionStorage 'modules/standard-setup/connection-storage-account.bicep' = if (deployStorageAccount) {
  name: 'connection-storage-account-${resourceToken}'
  params: {
    aiFoundryName:         aiFoundryAccount.outputs.accountName
    connectedResourceName: storageAccount.outputs.name
  }
  dependsOn: [
    storageAccount!
  ]
}

// App Configuration Store
//////////////////////////////////////////////////////////////////////////

module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = if (deployAppConfig) {
  name: 'appConfig'
  params: {
    name:     appConfigName
    location: location
    managedIdentities: {
      systemAssigned: true
    }    
    sku:      'Standard'
    publicNetworkAccess : 'Enabled'
    tags:     _tags
    dataPlaneProxy: {
      authenticationMode: 'Pass-through'
      privateLinkDelegation: 'Disabled'
    }
  }
}

// Application Insights
//////////////////////////////////////////////////////////////////////////

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (deployAppInsights) {
  name: 'appInsights'
  params: {
    name:                appInsightsName
    location:            location    
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                _tags
  }
}

// Container Resources
//////////////////////////////////////////////////////////////////////////

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = if (deployContainerEnv) {
  name: 'containerEnv'
  params: {
    name:     containerEnvName
    location: location
    tags:     _tags
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    appInsightsConnectionString: appInsights.outputs.connectionString
    zoneRedundant: false
    managedIdentities: {
      systemAssigned: true
    }    
  }
}

// Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = if (deployContainerRegistry) {
  name: 'containerRegistry'
  params: {
    name:     containerRegistryName
    publicNetworkAccess : 'Enabled'
    location: location
    acrSku:   'Basic'
    tags:     _tags
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// Container Apps
module containerApps 'br/public:avm/res/app/container-app:0.16.0' = [for app in containerAppsList: if (deployContainerApps) {
  name: empty(app.name)
    ? '${abbrs.containerApps}-${resourceToken}-${app.service_name}'
    : app.name  
  params: {
    name: empty(app.name)
    ? '${abbrs.containerApps}-${resourceToken}-${app.service_name}'
    : app.name
    location:              location
    environmentResourceId: containerEnv.outputs.resourceId

    ingressExternal:       true
    ingressTargetPort:     80
    ingressTransport:      'auto'
    ingressAllowInsecure:  false

    dapr: {
      enabled:     true
      appId:       app.service_name
      appPort:     80
      appProtocol: 'http'
    }

    managedIdentities: {
      systemAssigned: true
    }

    scaleSettings: {
      minReplicas: app.min_replicas
      maxReplicas: app.max_replicas
    }
    
    containers: [
      {
        name:     app.service_name
        image:    _containerDummyImageName
        resources: {
          cpu:    '0.5'
          memory: '1.0Gi'
        }
        env: [
          {
            name:  'APP_CONFIG_ENDPOINT'
            value: appConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(_tags, {
      'azd-service-name': app.service_name
    })
  }
}]

// Cosmos DB Account and Database
//////////////////////////////////////////////////////////////////////////

module CosmosDBAccount 'br/public:avm/res/document-db/database-account:0.12.0' = if (deployCosmosDb) {
  name: 'CosmosDBAccount'
  params: {
    name:                   dbAccountName  
    location:               location
    managedIdentities: {
      systemAssigned: true
    }    
    locations: [
      {
        locationName:    location  
        failoverPriority: 0   
        isZoneRedundant:  false 
      }
    ]
    defaultConsistencyLevel:'Session'
    capabilitiesToAdd: ['EnableServerless']
    networkRestrictions: {
      publicNetworkAccess: 'Enabled'
    }
    tags: _tags
    sqlDatabases: [
      {
        name:       dbDatabaseName
        throughput: 400
        containers: [for container in databaseContainersList: {
            name:       container.name
            paths:      ['/id']
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
    name:                  keyVaultName
    location:              location
    publicNetworkAccess:   'Enabled'
    sku:                   'standard'
    enableRbacAuthorization: true
    tags:                  _tags    
  }
}

// Log Analytics Workspace
//////////////////////////////////////////////////////////////////////////

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = if (deployLogAnalytics) {
  name: 'logAnalytics'
  params: {
    name:          logAnalyticsWorkspaceName
    location:      location
    skuName:       'PerGB2018'  
    dataRetention: 30           
    tags:          _tags
    managedIdentities: {
      systemAssigned: true
    }    
  }
}

// AI Search
//////////////////////////////////////////////////////////////////////////

// Azure AI Search Service
module searchService 'br/public:avm/res/search/search-service:0.10.0' =  if (deploySearchService) {
  name: 'searchService'
  params: {
    name: searchServiceName
    location: location
    publicNetworkAccess:   'Enabled'
    tags: _tags
    // SKU & capacity
    sku: 'standard'
    replicaCount: 1
    semanticSearch: 'disabled'
    managedIdentities : {
      systemAssigned: true
    }
    disableLocalAuth: false
    authOptions: { aadOrApiKey: { aadAuthFailureMode: 'http401WithBearerChallenge'}} 
  }
}

// Storage Accounts
//////////////////////////////////////////////////////////////////////////

// Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = if (deployStorageAccount) {
  name: 'storageAccountSolution'
  params: {
    name:                     storageAccountName
    location:                 location
    publicNetworkAccess:      'Enabled'
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []  
      defaultAction: 'Allow'  
    }    
    tags:                     _tags
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers:[for container in storageAccountContainersList: {
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

//////////////////////////////////////////////////////////////////////////
// ROLE ASSIGNMENTS
//////////////////////////////////////////////////////////////////////////

// Role assignments are centralized in this section to make it easier to view all permissions granted in this template.
// Custom modules are used for role assignments since no published AVM module available for this at the time we created this template.

// AI Foundry Storage Account - Storage Blob Data Contributor -> AI Foundry Project
module assignStorageAccountAiFoundryProject 'modules/standard-setup/azure-storage-account-role-assignment.bicep' = {
  name: 'assignStorageAccountAiFoundryProject'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    azureStorageName: aiFoundryDependencies.outputs.azureStorageName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
}

// AI Foundry Cosmos DB Account - Cosmos DB Operator -> AI Foundry Project
module assignCosmosDBAiFoundryProject 'modules/standard-setup/cosmosdb-account-role-assignment.bicep' = {
  name: 'assignCosmosDBAiFoundryProject'
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
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
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
  params: {
    aiSearchName: aiFoundryDependencies.outputs.aiSearchName
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
  }
  dependsOn:[
    assignCosmosDBAiFoundryProject, assignStorageAccountAiFoundryProject
  ]
}

// AI Foundry Storage Account - Storage Blob Data Owner (workspace-limited) -> AI Foundry Project
module assignStorageContainersAiFoundryProject 'modules/standard-setup/blob-storage-container-role-assignments.bicep' = {
  name: 'assignStorageContainersAiFoundryProject'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
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
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
  params: {
    cosmosAccountName: aiFoundryDependencies.outputs.cosmosDBName
    projectWorkspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId

  }
dependsOn: [
  aiFoundryAddProjectCapabilityHost, assignStorageContainersAiFoundryProject
  ]
}

// App Configuration Settings Service - App Configuration Data Reader -> Executor
module assignAppConfigAppConfigurationDataReaderExecutor 'modules/role-assignment/role-assignment-appconfig.bicep' = if (deployAppConfig) {
    name: 'assignAppConfigAppConfigurationDataReaderExecutor'
    params: {
      principalId: principalId 
      roleDefinition: _roles.configuration.appConfigurationDataOwner
      appConfigName: appConfig.outputs.name
    }  
}

// Azure Container Registry Service - AcrPush -> Executor
module assignCrAcrPushExecutor 'modules/role-assignment/role-assignment-containerregistry.bicep' = if (deployContainerRegistry) {
  name: 'assignCrAcrPushExecutor'
  params: {
    registryName:   containerRegistry.outputs.name
    principalId: principalId
    roleDefinition: _roles.containers.acrPush     
  }
}

// Key Vault Service - Key Vault Contributor -> Executor
module assignKeyVaultKeyVaultContributorExecutor 'modules/role-assignment/role-assignment-keyvault.bicep' = if (deployKeyVault) {
    name: 'assignKeyVaultKeyVaultContributorExecutor'
    params: {
      vaultName: keyVault.outputs.name
      principalId: principalId
      roleDefinition: _roles.security.keyVaultContributor 
    }
}

// Search Service - Search Service Contributor -> Executor
module assignSearchSearchServiceContributorExecutor 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deploySearchService) {
    name: 'assignSearchSearchServiceContributorExecutor'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: principalId
      roleDefinition: _roles.ai.searchServiceContributor
    }
}

// Search Service - Search Index Data Contributor -> Executor
module assignSearchSearchIndexDataContributorExecutor 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deploySearchService) {
    name: 'assignSearchSearchIndexDataContributorExecutor'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: principalId
      roleDefinition: _roles.ai.searchIndexDataContributor
    }
}

// Storage Account - Storage Blob Data Contributor -> Executor
module assignStorageStorageBlobDataContributorExecutor 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataContributorExecutor'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: principalId
      roleDefinition: _roles.storage.storageBlobDataContributor
  }
}

// AI Foundry Account - Azure AI Project Manager -> Executor
module assignAiFoundryAccountAzureAiProjectManagerExecutor 'modules/role-assignment/role-assignment-aiservices.bicep' = {
    name: 'assignAiFoundryAccountAzureAiProjectManagerExecutor'
    params: {
      cognitiveAccountName: aiFoundryAccount.outputs.accountName
      principalId: principalId
      roleDefinition: _roles.ai.azureAIProjectManager       
    }
}

// Cosmos DB Account - Cosmos DB Built-in Data Contributor -> Executor
module assignCosmosDBCosmosDbBuiltInDataContributorExecutor 'modules/role-assignment/role-assignment-cosmosdb-data-plane.bicep' =  if (deployCosmosDb) {
  name: 'assignCosmosDBCosmosDbBuiltInDataContributorExecutor'
  params: {
    cosmosDbAccountName: CosmosDBAccount.outputs.name
    principalId: principalId
    roleDefinitionGuid: _roles.databases.CosmosDBBuiltInDataContributor
    scopePath: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}'
  }
}

// App Configuration Settings Service - App Configuration Data Reader -> ContainerApp
module assignAppConfigAppConfigurationDataReaderContainerApps 'modules/role-assignment/role-assignment-appconfig.bicep' = [
  for (app, i) in containerAppsList: if (deployAppConfig && contains(app.roles, 'App Configuration Data Reader')) {
    name: 'assignAppConfigAppConfigurationDataReader-${app.service_name}'
    params: {
      appConfigName:  appConfig.outputs.name
      principalId:    containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.configuration.appConfigurationDataReader
    }
  }
]

// AI Foundry Account - Cognitive Services User -> ContainerApp
module assignAiFoundryAccountCognitiveServicesUserContainerApps 'modules/role-assignment/role-assignment-aiservices.bicep' = [
  for (app, i) in containerAppsList: if (contains(app.roles, 'Cognitive Services User')) {    
    name: 'assignAIFoundryAccountCognitiveServicesUser-${app.service_name}'
    params: {
      cognitiveAccountName: aiFoundryAccount.outputs.accountName
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.ai.cognitiveServicesUser 
    }
  }
]

// AI Foundry Account - Cognitive Services OpenAI User -> ContainerApp
module assignAIFoundryAccountCognitiveServicesOpenAIUserContainerApps 'modules/role-assignment/role-assignment-aiservices.bicep' = [
  for (app, i) in containerAppsList: if (contains(app.roles, 'Cognitive Services OpenAI User')) {    
    name: 'assignAIFoundryAccountCognitiveServicesOpenAIUser-${app.service_name}'
    params: {
      cognitiveAccountName: aiFoundryAccount.outputs.accountName
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.ai.cognitiveServicesOpenAIUser 
    }
  }
]

// Azure Container Registry Service - AcrPull -> ContainerApp
module assignCrAcrPullContainerApps 'modules/role-assignment/role-assignment-containerregistry.bicep' = [
  for (app, i) in containerAppsList: if (deployContainerRegistry && contains(app.roles, 'AcrPull')) {
    name: 'assignCrAcrPull-${app.service_name}'
    params: {
      registryName:   containerRegistry.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.containers.acrPull
    }
  }
]

// Cosmos DB Account - Cosmos DB Built-in Data Contributor -> ContainerApp
module assignCosmosDBCosmosDbBuiltInDataContributorContainerApps 'modules/role-assignment/role-assignment-cosmosdb-data-plane.bicep' = [
  for (app, i) in containerAppsList: if (deployContainerRegistry && contains(app.roles, 'Cosmos DB Built-in Data Contributor')) {
    name: 'assignCosmosDBCosmosDbBuiltInDataContributor-${app.service_name}'
    params: {
      cosmosDbAccountName: CosmosDBAccount.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinitionGuid: _roles.databases.CosmosDBBuiltInDataContributor
      scopePath: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${dbAccountName}/dbs/${dbDatabaseName}'
    }
  }
]

// Key Vault Service - Key Vault Secrets User -> ContainerApp
module assignKeyVaultKeyVaultSecretsUserContainerApps 'modules/role-assignment/role-assignment-keyvault.bicep' = [
  for (app, i) in containerAppsList: if (deployKeyVault && contains(app.roles, 'Key Vault Secrets User')) {
    name: 'assignKeyVaultKeyVaultSecretsUser-${app.service_name}'
    params: {
      vaultName: keyVault.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.security.keyVaultSecretsUser
    }
  }
]

// Search Service - Search Index Data Reader -> ContainerApp
module assignSearchSearchIndexDataReaderContainerApps 'modules/role-assignment/role-assignment-searchservice.bicep' = [
  for (app, i) in containerAppsList: if (deploySearchService && contains(app.roles, 'Search Index Data Reader')) {
    name: 'assignSearchSearchIndexDataReader-${app.service_name}'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.ai.searchIndexDataReader       
    }
  }
]

// Search Service - Search Index Data Contributor -> ContainerApp
module assignSearchSearchIndexDataContributorContainerApps 'modules/role-assignment/role-assignment-searchservice.bicep' = [
  for (app, i) in containerAppsList: if (deploySearchService && contains(app.roles, 'Search Index Data Contributor')) {
    name: 'assignSearchSearchIndexDataContributor-${app.service_name}'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.ai.searchIndexDataContributor   
    }
  }
]

// Storage Account - Storage Blob Data Contributor -> ContainerApp
module assignStorageStorageBlobDataContributorContainerApps 'modules/role-assignment/role-assignment-storageaccount.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(app.roles, 'Storage Blob Data Contributor')) {
    name: 'assignStorageStorageBlobDataContributor-${app.service_name}'
    params: {
      storageAccountName: storageAccount.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.storage.storageBlobDataContributor    
    }
  }
]

// Storage Account - Storage Blob Data Reader -> ContainerApp
module assignStorageStorageBlobDataReaderContainerApps 'modules/role-assignment/role-assignment-storageaccount.bicep' = [
  for (app, i) in containerAppsList: if (deployStorageAccount && contains(app.roles, 'Storage Blob Data Reader')) {
    name: 'assignStorageStorageBlobDataReader-${app.service_name}'
    params: {
      storageAccountName: storageAccount.outputs.name
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _roles.storage.storageBlobDataReader
    }
  }
]

// Storage Account - Storage Blob Data Reader -> Search Service
module assignStorageStorageBlobDataReaderSearch 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataReaderSearch'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: searchService.outputs.systemAssignedMIPrincipalId!
    roleDefinition: _roles.storage.storageBlobDataReader   
  }
}

// Search Service - Search Index Data Reader -> AiFoundryProject
module assignSearchSearchIndexDataReaderAIFoundryProject 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deploySearchService) {
  name: 'assignSearchSearchIndexDataReaderAIFoundryProject'
  params: {
    searchServiceName: searchService.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _roles.ai.searchIndexDataReader
  }
  dependsOn:[
    assignSearchAiFoundryProject, assignCosmosDBAiFoundryProject, assignStorageAccountAiFoundryProject
  ]    
}

// Storage Account - Storage Blob Data Reader -> AiFoundry Project
module assignStorageStorageBlobDataReaderAIFoundryProject 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataReaderAIFoundryProject'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _roles.storage.storageBlobDataReader     
  }
  dependsOn:[
    assignSearchAiFoundryProject, assignCosmosDBAiFoundryProject, assignStorageAccountAiFoundryProject, assignSearchSearchIndexDataReaderAIFoundryProject
  ]  
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// General / Deployment
// ──────────────────────────────────────────────────────────────────────
output TENANT_ID           string = tenant().tenantId
output SUBSCRIPTION_ID     string = subscription().subscriptionId
output RESOURCE_GROUP_NAME string = resourceGroup().name
output LOCATION            string = location
output ENVIRONMENT_NAME    string = environmentName
output DEPLOYMENT_NAME     string = deployment().name
output RESOURCE_TOKEN      string = resourceToken
output NETWORK_ISOLATION   bool   = networkIsolation

// ──────────────────────────────────────────────────────────────────────
// Resource IDs
// ──────────────────────────────────────────────────────────────────────
output KEY_VAULT_RESOURCE_ID           string = keyVault.outputs.resourceId
output STORAGE_ACCOUNT_RESOURCE_ID     string = storageAccount.outputs.resourceId
output COSMOS_DB_ACCOUNT_RESOURCE_ID   string = CosmosDBAccount.outputs.resourceId
output APP_CONFIG_RESOURCE_ID          string = appConfig.outputs.resourceId
output APP_INSIGHTS_RESOURCE_ID        string = appInsights.outputs.resourceId
output LOG_ANALYTICS_RESOURCE_ID       string = logAnalytics.outputs.resourceId
output CONTAINER_ENV_RESOURCE_ID       string = containerEnv.outputs.resourceId
output CONTAINER_REGISTRY_RESOURCE_ID  string = containerRegistry.outputs.resourceId
output SEARCH_SERVICE_RESOURCE_ID      string = searchService.outputs.resourceId
output AI_FOUNDRY_ACCOUNT_RESOURCE_ID  string = aiFoundryAccount.outputs.accountID
output AI_FOUNDRY_PROJECT_RESOURCE_ID  string = aiFoundryProject.outputs.projectId

// ──────────────────────────────────────────────────────────────────────
// Resource Names
// ──────────────────────────────────────────────────────────────────────
output AI_FOUNDRY_ACCOUNT_NAME         string = aiFoundryAccountName
output AI_FOUNDRY_PROJECT_NAME         string = aiFoundryProjectName
output AI_FOUNDRY_STORAGE_ACCOUNT_NAME string = aiFoundryStorageAccountName
output APP_CONFIG_NAME                 string = appConfigName
output APP_INSIGHTS_NAME               string = appInsightsName
output CONTAINER_ENV_NAME              string = containerEnvName
output CONTAINER_REGISTRY_NAME         string = containerRegistryName
output DATABASE_ACCOUNT_NAME           string = dbAccountName
output DATABASE_NAME                   string = dbDatabaseName
output SEARCH_SERVICE_NAME             string = searchServiceName
output STORAGE_ACCOUNT_NAME            string = storageAccountName

// ──────────────────────────────────────────────────────────────────────
// Feature flagging
// ──────────────────────────────────────────────────────────────────────
output DEPLOY_APP_CONFIG          bool = deployAppConfig
output DEPLOY_KEY_VAULT           bool = deployKeyVault
output DEPLOY_LOG_ANALYTICS       bool = deployLogAnalytics
output DEPLOY_APP_INSIGHTS        bool = deployAppInsights
output DEPLOY_SEARCH_SERVICE      bool = deploySearchService
output DEPLOY_STORAGE_ACCOUNT     bool = deployStorageAccount
output DEPLOY_COSMOS_DB           bool = deployCosmosDb
output DEPLOY_CONTAINER_APPS      bool = deployContainerApps
output DEPLOY_CONTAINER_REGISTRY  bool = deployContainerRegistry
output DEPLOY_CONTAINER_ENV       bool = deployContainerEnv

// ──────────────────────────────────────────────────────────────────────
// Endpoints / URIs
// ──────────────────────────────────────────────────────────────────────
output KEY_VAULT_URI                     string = keyVault.outputs.uri
output CONTAINER_REGISTRY_LOGIN_SERVER   string = containerRegistry.outputs.loginServer
output STORAGE_BLOB_ENDPOINT             string = storageAccount.outputs.primaryBlobEndpoint
output SEARCH_SERVICE_QUERY_ENDPOINT     string = searchService.outputs.endpoint
output AI_FOUNDRY_ACCOUNT_ENDPOINT       string = aiFoundryAccount.outputs.accountTarget
output AI_FOUNDRY_PROJECT_ENDPOINT       string = aiFoundryProject.outputs.endpoint
output AI_FOUNDRY_PROJECT_WORKSPACE_ID   string = aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
output COSMOS_DB_ENDPOINT                string = CosmosDBAccount.outputs.endpoint
output APP_CONFIG_ENDPOINT               string = appConfig.outputs.endpoint

// ──────────────────────────────────────────────────────────────────────
// Connections
// ──────────────────────────────────────────────────────────────────────
output SEARCH_CONNECTION_ID string = deploySearchService ? aiFoundryConnectionSearch.outputs.seachConnectionId : ''
output BING_CONNECTION_ID   string = deployGroundingWithBing ? aiFoundryBingConnection.outputs.bingConnectionId : ''


// ──────────────────────────────────────────────────────────────────────
// Managed Identity Principals
// ──────────────────────────────────────────────────────────────────────
output CONTAINER_ENV_PRINCIPAL_ID       string = containerEnv.outputs.systemAssignedMIPrincipalId!
output SEARCH_SERVICE_PRINCIPAL_ID      string = searchService.outputs.systemAssignedMIPrincipalId!
output AI_FOUNDRY_ACCOUNT_PRINCIPAL_ID  string = aiFoundryAccount.outputs.accountPrincipalId
output AI_FOUNDRY_PROJECT_PRINCIPAL_ID  string = aiFoundryProject.outputs.projectPrincipalId

// ──────────────────────────────────────────────────────────────────────
// Module-Specific Connection Objects
// ──────────────────────────────────────────────────────────────────────
output AI_FOUNDRY_STORAGE_CONNECTION   string = aiFoundryProject.outputs.azureStorageConnection
output AI_FOUNDRY_COSMOS_DB_CONNECTION string = aiFoundryProject.outputs.cosmosDBConnection
output AI_FOUNDRY_SEARCH_CONNECTION    string = aiFoundryProject.outputs.aiSearchConnection

// ──────────────────────────────────────────────────────────────────────
// Container Apps List
// ──────────────────────────────────────────────────────────────────────
output CONTAINER_APPS array = [
  for (app, i) in containerAppsList: {
    name:          empty(app.name) ? '${abbrs.containerApps}-${resourceToken}-${app.service_name}' : app.name
    serviceName:   app.service_name
    canonical_name:  app.canonical_name
    principalId:   containerApps[i].outputs.systemAssignedMIPrincipalId!
    fqdn:          containerApps[i].outputs.fqdn
  }
]

// ──────────────────────────────────────────────────────────────────────
// Model Deployment List
// ──────────────────────────────────────────────────────────────────────
output MODEL_DEPLOYMENTS array = modelDeploymentList
