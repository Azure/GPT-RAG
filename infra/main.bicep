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

// NOTE: Set parameter values using environment variables defined in main.parameters.json

// ----------------------------------------------------------------------
// General Parameters
// ----------------------------------------------------------------------
@description('Name of the Azure Developer CLI environment')
param environmentName    string                            

@description('Name of the Azure Resource Group to deploy into')
param location           string = resourceGroup().location 

@description('Principal ID for role assignments. This is typically the Object ID of the user or service principal running the deployment.')
param principalId        string                             

@description('Tags to apply to all resources in the deployment')
param deploymentTags     object = {}                       

@description('Enable network isolation for the deployment. This will restrict public access to resources and require private endpoints where applicable.')
param networkIsolation   bool   = false 


// ----------------------------------------------------------------------
// Feature-flagging Params (as booleans with a default of true)
// ----------------------------------------------------------------------

param deployAiFoundry                  bool = true
param deployAiFoundryStorageAccount    bool = true
param deployAiFoundryKeyVault          bool = true
param deployAiFoundrySearchService     bool = true
param deployAiFoundryCosmosDb          bool = true
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
param aiFoundryKeyVaultName        string = '${abbrs.keyVaultVaults}-foundry-${resourceToken}'
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
// Container params
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
// AI Foundry CMK params
// ----------------------------------------------------------------------
@description('Use Customer Managed Keys for Storage Account and Key Vault')
param useCMK      bool   = false                 

@description('Name of the Azure Key Vault key')
param keyName     string = 'managedKey'

@description('Version of the Azure Key Vault key')
param keyVersion string = '1'

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------
// General Variables
// ----------------------------------------------------------------------

var _azdTags = { 'azd-env-name': environmentName }
var _tags = union(_azdTags, deploymentTags)

// ----------------------------------------------------------------------
// Container vars
// ----------------------------------------------------------------------

var _containerDummyImageName = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ----------------------------------------------------------------------
// AI Foundry Project vars
// ----------------------------------------------------------------------

var _projectCapHost = 'caphostproj'
var _accountCapHost = 'caphostacc'

// ----------------------------------------------------------------------
// Role Assignment vars
// ----------------------------------------------------------------------

var _role_Ids = {
  'Storage Blob Data Reader':           '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  'Storage Blob Data Contributor':      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  'Storage Blob Data Owner':            'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  'App Configuration Data Reader':      '516239f1-63e1-4d78-a4de-a74fb236a071'
  'App Configuration Data Owner':       '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'
  AcrPull:                              '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  AcrPush:                              '8311e382-0749-4cb8-b61a-304f252e45ec'
  'Key Vault Contributor':              'f25e0fa2-a7c8-4377-a976-54943a77a395'
  'Key Vault Secrets User':             '4633458b-17de-408a-b874-0445c86b69e6'
  'Key Vault Crypto User':              '12338af0-0e69-4776-bea7-57ae8d297424'
  'Cognitive Services User':            'a97b65f3-24c7-4388-baec-2e87135dc908'
  'Cognitive Services OpenAI User':     '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  'Cosmos DB Built-in Data Reader':     '00000000-0000-0000-0000-000000000001'
  'Cosmos DB Built-in Data Contributor':'00000000-0000-0000-0000-000000000002'  
  'Search Index Data Reader':           '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  'Search Index Data Contributor':      '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  'Search Service Contributor':         '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  'Cosmos DB Operator':                 '230815da-be43-4aae-9cb4-875f7bd000aa'
}

//////////////////////////////////////////////////////////////////////////
// RESOURCES 
//////////////////////////////////////////////////////////////////////////

// AI Foundry and BYO Resources for Standard Setup
//////////////////////////////////////////////////////////////////////////

// Based on AI Foundry Documentation Samples
// https://github.com/azure-ai-foundry/foundry-samples

module aiFoundryAccount 'modules/ai-foundry/ai-foundry-account.bicep' = if (deployAiFoundry) {
  name: aiFoundryAccountName
  params: {
    accountName: aiFoundryAccountName
    location: location
    modelDeployments: modelDeploymentList
  }
}

module aiFoundryAccountCMK 'modules/ai-foundry/ai-foundry-account-cmk.bicep' = if (deployAiFoundry && useCMK) {
  name: aiFoundryAccountName
  params: {
    accountName: aiFoundryAccountName
    location: location
    keyVaultName: useCMK ? ( deployAiFoundryKeyVault ? aiFoundryKeyVault.outputs.name : aiFoundryKeyVaultName ) : ''
    keyName: keyName
    keyVersion: keyVersion
  }
}


module aiFoundryProject 'modules/ai-foundry/ai-foundry-project.bicep' = if (deployAiFoundry) {
  name: aiFoundryProjectName
  params: {
    projectName: aiFoundryProjectName
    projectDescription: aiFoundryProjectDescription
    displayName: aiFoundryProjectDisplayName
    location: location

    aiSearchName: aiFoundrySearchService.outputs.name
    aiSearchServiceResourceGroupName: aiFoundrySearchService.outputs.resourceGroupName
    aiSearchServiceSubscriptionId: subscription().subscriptionId
    
    cosmosDBName: aiFoundryCosmosDBAccount.outputs.name
    cosmosDBResourceGroupName: resourceGroup().name
    cosmosDBSubscriptionId: subscription().subscriptionId

    azureStorageName: aiFoundryStorageAccount.outputs.name
    azureStorageResourceGroupName: aiFoundryStorageAccount.outputs.resourceGroupName
    azureStorageSubscriptionId: subscription().subscriptionId

    accountName: aiFoundryAccount.outputs.accountName
  }
}

module aiFoundryFormatProjectWorkspaceId 'modules/ai-foundry/ai-foundry-format-project-workspace-id.bicep' = if (deployAiFoundry) {
  name: '${aiFoundryProjectName}-format-project-workspace-id'
  params: {
    projectWorkspaceId: aiFoundryProject.outputs.projectWorkspaceId
  }
}

module aiFoundryBingConnection 'modules/ai-foundry/ai-foundry-bing-search-tool.bicep' = if (deployGroundingWithBing) {
  name:  '${bingSearchName}-connection' 
  params: {
    account_name: aiFoundryAccount.outputs.accountName
    bingSearchName: bingSearchName   
  }
}

module aiFoundryCosmosDBAccount 'br/public:avm/res/document-db/database-account:0.12.0' = if (deployAiFoundryCosmosDb) {
  name: 'aiFoundryCosmosDBAccount'
  params: {
    // account basics
    name:                   aiFoundryCosmosDbName
    location:               location
    managedIdentities:      { systemAssigned: true }
    locations:              [ { locationName: location, failoverPriority: 0, isZoneRedundant: false } ]
    defaultConsistencyLevel: 'Session'
    capabilitiesToAdd:      [ 'EnableServerless' ]
    networkRestrictions:    { publicNetworkAccess: 'Enabled' }
    tags:                   _tags

  }
}

module aiFoundryCosmosContainers 'modules/ai-foundry/ai-foundry-cosmos-containers.bicep' = if (deployAiFoundryCosmosDb) {
  name: 'aiFoundryCosmosContainers'
  params: {
    cosmosDbAccountNAme: aiFoundryCosmosDBAccount.outputs.name
    workspaceGuid: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
  }
}

module aiFoundryKeyVault 'br/public:avm/res/key-vault/vault:0.12.1' = if (deployAiFoundryKeyVault && useCMK) {
  name: 'aiFoundryKeyVault'
  params: {
    name:                  aiFoundryKeyVaultName
    location:              location
    publicNetworkAccess:   'Enabled'
    sku:                   'standard'
    enableRbacAuthorization: true
    tags:                  _tags    
  }
}

module aiFoundrySearchService 'br/public:avm/res/search/search-service:0.10.0' =  if (deployAiFoundrySearchService) {
  name: 'aiFoundrySearchService'
  params: {
    name: aiFoundrySearchServiceName
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
  }
}

// AI Foundry Storage Account
module aiFoundryStorageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = if (deployAiFoundryStorageAccount) {
  name: 'aiFoundryStotageAccount'
  params: {
    name:                     aiFoundryStorageAccountName
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
  }
}

// AI Foundry Project Capability Host
module aiFoundryAddProjectCapabilityHost 'modules/ai-foundry/ai-foundry-add-capability-host.bicep' = {
  name: 'aiFoundryAddProjectCapabilityHost'
  params: {
    accountName: aiFoundryAccount.outputs.accountName
    projectName: aiFoundryProject.outputs.projectName
    cosmosDBConnection: aiFoundryProject.outputs.cosmosDBConnection
    azureStorageConnection: aiFoundryProject.outputs.azureStorageConnection
    aiSearchConnection: aiFoundryProject.outputs.aiSearchConnection

    projectCapHost: _projectCapHost
    accountCapHost: _accountCapHost
  }
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

// App Configuration Settings Service - App Configuration Data Reader -> Executor
module assignAppConfigAppConfigurationDataReaderExecutor 'modules/role-assignment/role-assignment-appconfig.bicep' = if (deployAppConfig) {
    name: 'assignAppConfigAppConfigurationDataReaderExecutor'
    params: {
      principalId: principalId 
      roleDefinition: _role_Ids['App Configuration Data Owner']  
      appConfigName: appConfig.outputs.name
    }  
}

// Azure Container Registry Service - AcrPush -> Executor
module assignCrAcrPushExecutor 'modules/role-assignment/role-assignment-containerregistry.bicep' = if (deployContainerRegistry) {
  name: 'assignCrAcrPushExecutor'
  params: {
    registryName:   containerRegistry.outputs.name
    principalId: principalId
    roleDefinition: _role_Ids.AcrPush      
  }
}

// Key Vault Service - Key Vault Contributor -> Executor
module assignKeyVaultKeyVaultContributorExecutor 'modules/role-assignment/role-assignment-keyvault.bicep' = if (deployKeyVault) {
    name: 'assignKeyVaultKeyVaultContributorExecutor'
    params: {
      vaultName: keyVault.outputs.name
      principalId: principalId
      roleDefinition: _role_Ids['Key Vault Contributor']         
    }
}

// Search Service - Search Service Contributor -> Executor
module assignSearchSearchServiceContributorExecutor 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deploySearchService) {
    name: 'assignSearchSearchServiceContributorExecutor'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: principalId
      roleDefinition: _role_Ids['Search Service Contributor']   
    }
}

// Search Service - Search Index Data Contributor -> Executor
module assignSearchSearchIndexDataContributorExecutor 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deploySearchService) {
    name: 'assignSearchSearchIndexDataContributorExecutor'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: principalId
      roleDefinition: _role_Ids['Search Index Data Contributor']  
    }
}

// Storage Account - Storage Blob Data Contributor -> Executor
module assignStorageStorageBlobDataContributorExecutor 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataContributorExecutor'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: principalId
      roleDefinition: _role_Ids['Storage Blob Data Contributor']  
  }
}

// AI Foundry Search Service - Search Index Data Contributor -> AiFoundry Project
module assignAiFoundrySearchSearchIndexDataContributorAiFoundryProject 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deployAiFoundrySearchService) {
    name: 'assignAiFoundrySearchSearchIndexDataContributorAiFoundryProject'
    params: {
      searchServiceName: aiFoundrySearchService.outputs.name
      principalId: aiFoundryProject.outputs.projectPrincipalId
      roleDefinition: _role_Ids['Search Index Data Contributor']         
    }
}

// AI Foundry Search Service - Search Service Contributor -> AiFoundry Project
module assignAiFoundrySearchSearchServiceContributorAiFoundryProject 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deployAiFoundrySearchService) {
    name: 'assignAiFoundrySearchSearchServiceContributorAiFoundryProject'
    params: {
      searchServiceName: aiFoundrySearchService.outputs.name
      principalId: aiFoundryProject.outputs.projectPrincipalId
      roleDefinition: _role_Ids['Search Service Contributor']        
    }
}

// AI Foundry Blob Storage Service - Storage Blob Storage Contributor -> AiFoundry Project
module assignAiFoundryStorageStorageBlobDataContributorAiFoundryProject 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployAiFoundryStorageAccount) {
  name: 'assignAiFoundryStorageStorageBlobDataContributorAiFoundryProject'
  params: {
    storageAccountName: aiFoundryStorageAccount.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _role_Ids['Storage Blob Data Contributor']      
  }
}

// AI Foundry Cosmos DB Account - Cosmos DB Operator -> AiFoundry Project 
module assignAiFoundryCosmosDBCosmosDbOperatorAiFoundryProject 'modules/role-assignment/role-assignment-cosmosdb-control-plane.bicep' = if (deployAiFoundryCosmosDb) {
  name: 'assignAiFoundryCosmosDBCosmosDbOperatorAiFoundryProject' 
  params: {
    cosmosDbAccountName: aiFoundryCosmosDBAccount.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _role_Ids['Cosmos DB Operator']      
  }
}

// AI Foundry Cosmos DB Account - Cosmos DB Built-in Data Contributor -> AiFoundry Project 
module assignAiFoundryCosmosDBCosmosDbBuiltInDataContributorAIFoundryProject 'modules/role-assignment/role-assignment-cosmosdb-aiproject-data-plane.bicep' = if (deployAiFoundryCosmosDb) {
  name: 'assignAiFoundryCosmosCosmosDbBuiltInDataContributorAIFoundryPrj'
  scope: resourceGroup(subscription().subscriptionId, resourceGroup().name)
  params: {
    cosmosAccountName: aiFoundryCosmosContainers.outputs.cosmosDbAccountName
    projectWorkspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
    projectPrincipalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinitionGuid: _role_Ids['Cosmos DB Built-in Data Contributor']
  }
}

// AI Foundry Storage Account - Storage Blob Data Owner -> AiFoundry Project 
module assignAiFoundryStorageStorageBlobDataOwnerAiFoundryProject 'modules/role-assignment/role-assignment-storageaccount-aiproject.bicep' = if (deployAiFoundryStorageAccount) {
  name: 'assignAiFoundryStorageStorageBlobDataOwnerAiFoundryProject'
  params: {
    storageAccountName: aiFoundryStorageAccount.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    workspaceId: aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
    roleDefinition: _role_Ids['Storage Blob Data Owner']  
  }
}

// Key Vault Service - Key Vault Crypto User -> AiFoundry Project 
module assignAiFoundryKeyVaultKeyVaultCryptoUserAiFoundryProject 'modules/role-assignment/role-assignment-keyvault.bicep' = if (deployAiFoundryKeyVault && useCMK) {
  name: 'assignAiFoundryKeyVaultKeyVaultCryptoUserAiFoundryProject'
  params: {
    vaultName: keyVault.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _role_Ids['Key Vault Crypto User']  
  }
}

// Key Vault Service - Key Vault Secrets User -> AiFoundry Project 
module assignAiFoundryKeyVaultKeyVaultSecretsAiFoundryProject 'modules/role-assignment/role-assignment-keyvault.bicep' = if (deployAiFoundryKeyVault && useCMK) {
  name: 'assignAiFoundryKeyVaultKeyVaultSecretsAiFoundryProject'
  params: {
    vaultName: keyVault.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _role_Ids['Key Vault Secrets User']  
  }
}

// App Configuration Settings Service - App Configuration Data Reader -> ContainerApp
module assignAppConfigAppConfigurationDataReaderContainerApps 'modules/role-assignment/role-assignment-appconfig.bicep' = [
  for (app, i) in containerAppsList: if (deployAppConfig && contains(app.roles, 'App Configuration Data Reader')) {
    name: 'assignAppConfigAppConfigurationDataReader-${app.service_name}'
    params: {
      appConfigName:  appConfig.outputs.name
      principalId:    containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _role_Ids['App Configuration Data Reader']  
    }
  }
]

// Cognitive Services Account - Cognitive Services User -> ContainerApp
module assignAIFoundryCognitiveServicesUserContainerApps 'modules/role-assignment/role-assignment-aiservices.bicep' = [
  for (app, i) in containerAppsList: if (deployAiFoundry && contains(app.roles, 'Cognitive Services User')) {    
    name: 'assignAIFoundryCognitiveServicesUser-${app.service_name}'
    params: {
      cognitiveAccountName: aiFoundryAccount.outputs.accountName
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _role_Ids['Cognitive Services User']   
    }
  }
]

// Cognitive Services Account - Cognitive Services OpenAI User -> ContainerApp
module assignAIFoundryCognitiveServicesOpenAIUserContainerApps 'modules/role-assignment/role-assignment-aiservices.bicep' = [
  for (app, i) in containerAppsList: if (deployAiFoundry && contains(app.roles, 'Cognitive Services OpenAI User')) {    
    name: 'assignAIFoundryCognitiveServicesOpenAIUser-${app.service_name}'
    params: {
      cognitiveAccountName: aiFoundryAccount.outputs.accountName 
      principalId: containerApps[i].outputs.systemAssignedMIPrincipalId!
      roleDefinition: _role_Ids['Cognitive Services OpenAI User']  
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
      roleDefinition: _role_Ids.AcrPull
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
      roleDefinitionGuid: _role_Ids['Cosmos DB Built-in Data Contributor']
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
      roleDefinition: _role_Ids['Key Vault Secrets User']  
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
      roleDefinition: _role_Ids['Search Index Data Reader']        
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
      roleDefinition: _role_Ids['Search Index Data Contributor']        
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
      roleDefinition: _role_Ids['Storage Blob Data Contributor']        
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
      roleDefinition: _role_Ids['Storage Blob Data Reader']        
    }
  }
]

// Search Service - Search Index Data Contributor -> Executor
module assignSearchSearchIndexDataReaderAIFoundryProject 'modules/role-assignment/role-assignment-searchservice.bicep' = if (deploySearchService) {
    name: 'assignSearchSearchIndexDataReaderAIFoundryProject'
    params: {
      searchServiceName: searchService.outputs.name
      principalId: aiFoundryProject.outputs.projectPrincipalId
      roleDefinition: _role_Ids['Search Index Data Reader']  
    }
}

// Storage Account - Storage Blob Data Reader -> AiFoundry Project
module assignStorageStorageBlobDataReaderAIFoundryProject 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataReaderAIFoundryProject'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: aiFoundryProject.outputs.projectPrincipalId
    roleDefinition: _role_Ids['Storage Blob Data Reader']      
  }
}

// Storage Account - Storage Blob Data Reader -> Search Service
module assignStorageStorageBlobDataReaderSearch 'modules/role-assignment/role-assignment-storageaccount.bicep' = if (deployStorageAccount) {
  name: 'assignStorageStorageBlobDataReaderSearch'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: searchService.outputs.systemAssignedMIPrincipalId!
    roleDefinition: _role_Ids['Storage Blob Data Reader']      
  }
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ──────────────────────────────────────────────────────────────────────
// General / Deployment
// ──────────────────────────────────────────────────────────────────────
output tenantId            string = tenant().tenantId
output subscriptionId      string = subscription().subscriptionId
output resourceGroupName   string = resourceGroup().name
output location            string = location
output environmentName     string = environmentName
output deploymentName      string = deployment().name
output resourceToken       string = resourceToken
output networkIsolation    bool   = networkIsolation

// ──────────────────────────────────────────────────────────────────────
// Resource IDs
// ──────────────────────────────────────────────────────────────────────
output keyVaultResourceId           string = keyVault.outputs.resourceId
output storageAccountResourceId     string = storageAccount.outputs.resourceId
output cosmosDbAccountResourceId    string = CosmosDBAccount.outputs.resourceId
output appConfigResourceId          string = appConfig.outputs.resourceId
output appInsightsResourceId        string = appInsights.outputs.resourceId
output logAnalyticsResourceId       string = logAnalytics.outputs.resourceId
output containerEnvResourceId       string = containerEnv.outputs.resourceId
output containerRegistryResourceId  string = containerRegistry.outputs.resourceId
output searchServiceResourceId      string = searchService.outputs.resourceId
output aiFoundryAccountResourceId   string = aiFoundryAccount.outputs.resourceId
output aiFoundryProjectResourceId   string = aiFoundryProject.outputs.resourceId

// ──────────────────────────────────────────────────────────────────────
// Resource Names
// ──────────────────────────────────────────────────────────────────────
output aiFoundryAccountName         string = aiFoundryAccountName
output aiFoundryProjectName         string = aiFoundryProjectName
output aiFoundryStorageAccountName  string = aiFoundryStorageAccountName
output appConfigName                string = appConfigName
output appInsightsName              string = appInsightsName
output containerEnvName             string = containerEnvName
output containerRegistryName        string = containerRegistryName
output databaseAccountName          string = dbAccountName
output databaseName                 string = dbDatabaseName
output searchServiceName            string = searchServiceName
output storageAccountName           string = storageAccountName

// ──────────────────────────────────────────────────────────────────────
// Feature flagging
// ──────────────────────────────────────────────────────────────────────
output deployAiFoundry                  bool = deployAiFoundry
output deployAiFoundryStorageAccount    bool = deployAiFoundryStorageAccount
output deployAiFoundryKeyVault          bool = deployAiFoundryKeyVault
output deployAiFoundrySearchService     bool = deployAiFoundrySearchService
output deployAiFoundryCosmosDb          bool = deployAiFoundryCosmosDb
output deployAppConfig                  bool = deployAppConfig
output deployKeyVault                   bool = deployKeyVault
output deployLogAnalytics               bool = deployLogAnalytics
output deployAppInsights                bool = deployAppInsights
output deploySearchService              bool = deploySearchService
output deployStorageAccount             bool = deployStorageAccount
output deployCosmosDb                   bool = deployCosmosDb
output deployContainerApps              bool = deployContainerApps
output deployContainerRegistry          bool = deployContainerRegistry
output deployContainerEnv               bool = deployContainerEnv

// ──────────────────────────────────────────────────────────────────────
// Endpoints / URIs
// ──────────────────────────────────────────────────────────────────────
output keyVaultUri                  string = keyVault.outputs.uri
output appConfigEndpoint            string = appConfig.outputs.endpoint
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output storageBlobEndpoint          string = storageAccount.outputs.primaryBlobEndpoint
output searchServiceQueryEndpoint   string = searchService.outputs.endpoint
output aiFoundryAccountEndpoint     string = aiFoundryAccount.outputs.endpoint
output aiFoundryProjectEndpoint     string = aiFoundryProject.outputs.endpoint
output aiFoundryProjectWorkspaceId  string = aiFoundryFormatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
output cosmosDbEndpoint             string = CosmosDBAccount.outputs.endpoint

// ──────────────────────────────────────────────────────────────────────
// Managed Identity Principals
// ──────────────────────────────────────────────────────────────────────
output containerEnvPrincipalId        string = containerEnv.outputs.systemAssignedMIPrincipalId!
output searchServicePrincipalId       string = searchService.outputs.systemAssignedMIPrincipalId!
output aiFoundryAccountPrincipalId    string = aiFoundryAccount.outputs.accountPrincipalId
output aiFoundryProjectPrincipalId    string = aiFoundryProject.outputs.projectPrincipalId

// ──────────────────────────────────────────────────────────────────────
// Module-Specific Connection Objects
// ──────────────────────────────────────────────────────────────────────
output aiFoundryStorageConnection   string = aiFoundryProject.outputs.azureStorageConnection
output aiFoundryCosmosDbConnection  string = aiFoundryProject.outputs.cosmosDBConnection
output aiFoundrySearchConnection    string = aiFoundryProject.outputs.aiSearchConnection

// ──────────────────────────────────────────────────────────────────────
// Container Apps Summary
// ──────────────────────────────────────────────────────────────────────
output containerApps array = [
  for (app, i) in containerAppsList: {
    name:          empty(app.name) ? '${abbrs.containerApps}-${resourceToken}-${app.service_name}' : app.name
    serviceName:   app.service_name
    internal_name:  app.internal_name
    principalId:   containerApps[i].outputs.systemAssignedMIPrincipalId!
    fqdn:          containerApps[i].outputs.fqdn
  }
]


// ──────────────────────────────────────────────────────────────────────
// Model Deployment Summary
// ──────────────────────────────────────────────────────────────────────
output modelDeployments array = modelDeploymentList

