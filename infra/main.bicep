// Deployment Template using Azure Verified Modules (AVM)
// Reference: https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/
targetScope = 'resourceGroup'

//////////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////////

// NOTE: Set parameter values using environment variables defined in main.parameters.json

// ----------------------------------------------------------------------
// General Parameters
// ----------------------------------------------------------------------

param environmentName                     string = ''  // AZD environment
param location                            string = ''  // Primary deployment location.
param principalId                         string = ''  // Principal ID for role assignments.
param deploymentTags                      object = {}  // Tags applied to all resources.
param configureRbac                       string = ''  // Assign RBAC roles to resources.
param networkIsolation                    string = '' 

// ----------------------------------------------------------------------
// Modularity params
// ----------------------------------------------------------------------

param installAiFoundry                  string = '' 
param installApim                       string = ''  
param installAoai                       string = ''   
param installAppConfig                  string = ''
param installKeyVault                   string = ''
param installLogAnalytics               string = ''
param installAppInsights                string = ''
param installSearchService              string = ''
param installStorageAccount             string = ''
param installCosmosDb                   string = ''
param installContainerApps              string = ''
param installContainerRegistry          string = ''
param installAiServices                 string = ''
param installContainerEnv               string = ''

// ----------------------------------------------------------------------
// Resource Naming params
// ----------------------------------------------------------------------

param aiFoundryStorageAccountName        string = ''
param aiHubName                          string = ''
param aiProjectName                      string = ''
param aiServicesName                     string = ''
param aoaiServiceName                    string = ''
param apimResourceName                   string = ''
param appConfigName                      string = ''
param appInsightsName                    string = ''
param containerEnvName                   string = ''
param containerRegistryName              string = ''
param dbAccountName                      string = ''
param dbDatabaseName                     string = ''
param keyVaultName                       string = ''
param logAnalyticsWorkspaceName          string = ''
param searchServiceName                  string = ''
param storageAccountName                 string = ''

// ----------------------------------------------------------------------
// API Management params
// ----------------------------------------------------------------------

param apimPublisherEmail                  string = ''
param apimPublisherName                   string = ''
param apimSku                             string = ''
param apimAoaiApiName                     string = ''
param apimAoaiApiDisplayName              string = ''
param apimAoaiApiPath                     string = ''
param apimAoaiSubscriptionName            string = ''
param apimAoaiSubscriptionDisplayName     string = ''

// ----------------------------------------------------------------------
// Azure Open AI Service params
// ----------------------------------------------------------------------

param aoaiDeploymentList                  array = []
param aoaiApiVersion                      string = ''

// ----------------------------------------------------------------------
// Container params
// ----------------------------------------------------------------------

param containerAppsList                   array = []

// ----------------------------------------------------------------------
// Database params
// ----------------------------------------------------------------------

param databaseContainersList             array = []

// ----------------------------------------------------------------------
// Doc Intelligence params
// ----------------------------------------------------------------------

param docIntelligenceApiVersion           string = ''

// ----------------------------------------------------------------------
// Azure Search params
// ----------------------------------------------------------------------

param searchApiVersion                    string = ''

// ----------------------------------------------------------------------
// Storage Account params
// ----------------------------------------------------------------------

param storageAccountContainersList        array = []

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------
// General Variables
// ----------------------------------------------------------------------

var _resourceToken           = toLower(uniqueString(subscription().id, environmentName, location))
var _tags                    = union({ env: _environmentName }, deploymentTags)
var _azureCloud              = environment().name
var _environmentName         = empty(environmentName) ? 'dev' : environmentName
var _location                = empty(location) ? resourceGroup().location : location
var _principalId             = empty(principalId) ? '' : principalId
var _configureRbac           = (empty(configureRbac) || toLower(configureRbac) == 'true')
var _networkIsolation        = empty(networkIsolation) ? false : (toLower(networkIsolation) == 'true')

// ----------------------------------------------------------------------
// Resource Naming 
// ----------------------------------------------------------------------

var _aiFoundryStorageAccountName  = empty(aiFoundryStorageAccountName)  ? '${_abbrs.storageStorageAccounts}aihub0${_resourceToken}'       : aiFoundryStorageAccountName
var _aiHubName                    = empty(aiHubName)                    ? '${_abbrs.aiHub}-${_resourceToken}'                             : aiHubName
var _aiProjectName                = empty(aiProjectName)                ? '${_abbrs.aiProject}-${_resourceToken}'                         : aiProjectName
var _aiServicesName               = empty(aiServicesName)               ? '${_abbrs.cognitiveServicesAccounts}-${_resourceToken}'         : aiServicesName
var _aoaiServiceName              = empty(aoaiServiceName)              ? '${_abbrs.openaiServices}-${_resourceToken}'                    : aoaiServiceName
var _apimResourceName             = empty(apimResourceName)             ? '${_abbrs.apiManagementService}-${_resourceToken}'              : apimResourceName
var _appConfigName                = empty(appConfigName)                ? '${_abbrs.appConfigurationStores}-${_resourceToken}'            : appConfigName
var _appInsightsName              = empty(appInsightsName)              ? '${_abbrs.insightsComponents}-${_resourceToken}'                : appInsightsName
var _containerEnvName             = empty(containerEnvName)             ? '${_abbrs.containerEnvs}${_resourceToken}'                      : containerEnvName
var _containerRegistryName        = empty(containerRegistryName)        ? '${_abbrs.containerRegistries}${_resourceToken}'                : containerRegistryName
var _dbAccountName                = empty(dbAccountName)                ? '${_abbrs.cosmosDbAccount}-${_resourceToken}'                   : dbAccountName
var _dbDatabaseName               = empty(dbDatabaseName)               ? '${_abbrs.cosmosDbDatabase}-${_resourceToken}'                  : dbDatabaseName
var _keyVaultName                 = empty(keyVaultName)                 ? '${_abbrs.keyVaultVaults}-${_resourceToken}'                    : keyVaultName
var _logAnalyticsWorkspaceName    = empty(logAnalyticsWorkspaceName)    ? '${_abbrs.operationalInsightsWorkspaces}-${_resourceToken}'     : logAnalyticsWorkspaceName
var _searchServiceName            = empty(searchServiceName)            ? '${_abbrs.searchSearchServices}-${_resourceToken}'              : searchServiceName
var _storageAccountName           = empty(storageAccountName)           ? '${_abbrs.storageStorageAccounts}${_resourceToken}'             : storageAccountName

// ----------------------------------------------------------------------
// Modularity vars
// ----------------------------------------------------------------------

var _installAiFoundry            = empty(installAiFoundry)         ? true : (toLower(installAiFoundry)         == 'true')
var _installApim                 = empty(installApim)              ? true : (toLower(installApim)              == 'true')
var _installAoai                 = empty(installAoai)              ? true : (toLower(installAoai)              == 'true')
var _installAppConfig            = empty(installAppConfig)         ? true : (toLower(installAppConfig)         == 'true')
var _installKeyVault             = empty(installKeyVault)          ? true : (toLower(installKeyVault)          == 'true')
var _installLogAnalytics         = empty(installLogAnalytics)      ? true : (toLower(installLogAnalytics)      == 'true')
var _installAppInsights          = empty(installAppInsights)       ? true : (toLower(installAppInsights)       == 'true')
var _installSearchService        = empty(installSearchService)     ? true : (toLower(installSearchService)     == 'true')
var _installStorageAccount       = empty(installStorageAccount)    ? true : (toLower(installStorageAccount)    == 'true')
var _installCosmosDb             = empty(installCosmosDb)          ? true : (toLower(installCosmosDb)          == 'true')
var _installContainerApps        = empty(installContainerApps)     ? true : (toLower(installContainerApps)     == 'true')
var _installContainerRegistry    = empty(installContainerRegistry) ? true : (toLower(installContainerRegistry) == 'true')
var _installAiServices           = empty(installAiServices)        ? true : (toLower(installAiServices)        == 'true')
var _installContainerEnv         = empty(installContainerEnv)      ? true : (toLower(installContainerEnv)      == 'true')

// ----------------------------------------------------------------------
// AI Hub and Project vars
// ----------------------------------------------------------------------

var _aiFoundryProjectPrincipalId = (_installAiFoundry) ? aiProject.outputs.systemAssignedMIPrincipalId  : 'update-ai-project-principal-id'
var _aiFoundryHubPrincipalId     = (_installAiFoundry) ? aiHub.outputs.systemAssignedMIPrincipalId      : 'update-ai-hub-principal-id'

var _aiFoundryHubId              = (_installAiFoundry) ? aiHub.outputs.resourceId                       : 'update-ai-hub-resource-id'
var _aiFoundryProjectId          = (_installAiFoundry) ? aiProject.outputs.resourceId                   : 'update-ai-project-id'

var _aiFoundryProjectDiscoveryUrl     = 'https://${location}.api.azureml.ms/discovery'
var _aiFoundryProjectEndoint          = replace(replace(_aiFoundryProjectDiscoveryUrl, 'https://', ''), '/discovery', '')
var _aiFoundryProjectConnectionString = '${_aiFoundryProjectEndoint};${subscription().subscriptionId};${resourceGroup().name};${_aiProjectName}'

// ----------------------------------------------------------------------
// Azure Open AI Service vars
// ----------------------------------------------------------------------

var _aoaiApiVersion             = empty(aoaiApiVersion)        ? '2024-10-21'                                     : aoaiApiVersion
var _aoaiServiceId              = (_installAoai)               ? aoaiService.outputs.resourceId                   : 'update-aoai-service-id'
var _aoaiServiceEndpoint        = (_installAoai)               ? aoaiService.outputs.endpoint                     : 'https://update-aoai-endpoint.example.com/'
var _aoaiServicePrincipalId     = (_installAoai)               ? aoaiService.outputs.systemAssignedMIPrincipalId  : 'update-aoai-service-principal-id'

// ----------------------------------------------------------------------
// API Management vars
// ----------------------------------------------------------------------

var _apimSku                     = empty(apimSku)                         ? 'Consumption'           : apimSku
var _apimPublisherEmail          = empty(apimPublisherEmail)              ? 'noreply@example.com'   : apimPublisherEmail
var _apimPublisherName           = empty(apimPublisherName)               ? 'MyCompany'             : apimPublisherName
var _aoaiSubscriptionName        = empty(apimAoaiSubscriptionName)        ? 'openai-subscription'   : apimAoaiSubscriptionName
var _aoaiSubscriptionDisplayName = empty(apimAoaiSubscriptionDisplayName) ? 'OpenAI Subscription'   : apimAoaiSubscriptionDisplayName
var _aoaiApiPolicyXmlTemplate    = '''
<policies>
  <inbound>
    <base />
    <authentication-managed-identity
    resource="https://cognitiveservices.azure.com"
    output-token-variable-name="token" />
    <set-header name="Authorization" exists-action="override">
    <value>@("Bearer " + context.Variables["token"])</value>
    </set-header>
    <set-backend-service backend-id="__BACKEND_ID__" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
var _aoaiApiPolicyXml            = replace(_aoaiApiPolicyXmlTemplate, '__BACKEND_ID__', _aoaiServiceName)
var _aoaiApiName                 = empty(apimAoaiApiName)        ? 'openai' : apimAoaiApiName
var _aoaiApiPath                 = empty(apimAoaiApiPath)        ? 'openai' : apimAoaiApiPath
var _aoaiApiDisplayName          = empty(apimAoaiApiDisplayName) ? 'OpenAI' : apimAoaiApiDisplayName
var _aoaiApiSpecUrlTemplate      = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/__API_VERSION__/inference.json'
var _aoaiApiSpecUrl              = replace(_aoaiApiSpecUrlTemplate, '__API_VERSION__', _aoaiApiVersion)
var _apimServicePrincipalId      = (_installApim) ? apimService.outputs.systemAssignedMIPrincipalId : 'update-apim-service-principal-id'

// ----------------------------------------------------------------------
// App Configuration vars
// ----------------------------------------------------------------------

var _appConfigEndpoint          = (_installAppConfig) ? appConfig.outputs.endpoint   : 'https://update-app-config-endpoint.microsft.com'
var _appConfigId                = (_installAppConfig) ? appConfig.outputs.resourceId : 'update-app-config-id'

// Abbreviation dictionary
var _abbrs = {
  resourcesResourceGroups: 'rg'
  insightsComponents: 'appins'
  keyVaultVaults: 'kv'
  storageStorageAccounts: 'st'
  operationalInsightsWorkspaces: 'log'
  searchSearchServices: 'search'
  appConfigurationStores: 'appconfig'
  containerApps: 'capp'
  containerRegistries: 'cr'
  containerEnvs: 'ace'
  cognitiveServicesAccounts: 'ai-services'
  docIntelligence: 'doc-intel'
  aiProject: 'ai-project'
  aiHub: 'ai-hub'
  apiManagementService: 'apim'
  openaiServices: 'oai'
  cosmosDbAccount: 'db-account'
  cosmosDbDatabase: 'database'
}

// ----------------------------------------------------------------------
// App Insights vars
// ----------------------------------------------------------------------

var _appInsightsId               = (_installAppInsights)       ? appInsights.outputs.resourceId       : 'update-app-insights-resource-id'
var _appInsigthsConnectionString = (_installAppInsights)       ? appInsights.outputs.connectionString : 'update-app-insights-connection-string'

// ----------------------------------------------------------------------
// AI Services vars
// ----------------------------------------------------------------------

var _aiServicesEndpoint = (_installAiServices) ? aiServices.outputs.endpoint   : 'https://update-ai-services-endpoint.example.com'
var _aiServicesId       = (_installAiServices) ? aiServices.outputs.resourceId : 'update-ai-services-id'

// ----------------------------------------------------------------------
// Container vars
// ----------------------------------------------------------------------

var _containerRegistryLoginServer = (_installContainerRegistry) ? containerRegistry.outputs.loginServer : 'update-container-registry-login-server.example.com'
var _containerDummyImageName      = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var _containerRegistryId          = (_installContainerRegistry) ? containerRegistry.outputs.resourceId  : 'update-container-registry-id'

// ----------------------------------------------------------------------
// Database vars
// ----------------------------------------------------------------------

var _databaseAccountId           = (_installCosmosDb)          ? databaseAccount.outputs.resourceId         : 'update-database-account-id'

// ----------------------------------------------------------------------
// Document Intelligence vars
// ----------------------------------------------------------------------
var _docIntelligenceApiVersion         = empty(docIntelligenceApiVersion) ? '2024-11-30' : docIntelligenceApiVersion

// ----------------------------------------------------------------------
// Key Vault vars
// ----------------------------------------------------------------------

var _keyVaultId                  = (_installKeyVault)          ? keyVault.outputs.resourceId                : 'update-key-vault-id'
var _keyVaultEndpoint            = (_installKeyVault)          ? keyVault.outputs.uri                       : 'https://update-key-vault-endpoint.example.com'

// ----------------------------------------------------------------------
// Log Analytics vars
// ----------------------------------------------------------------------

var _logAnalyticsId = (_installLogAnalytics) ? logAnalytics.outputs.resourceId : 'update-log-analytics-id'

// ----------------------------------------------------------------------
// AI Search vars
// ----------------------------------------------------------------------

var _searchServicePrincipalId = (_installSearchService) ? searchService.outputs.systemAssignedMIPrincipalId : 'update-search-service-principal-id'
var _searchServiceId          = (_installSearchService) ? searchService.outputs.resourceId                  : 'update-search-service-id'
var _searchServiceEndpoint    = (_installSearchService) ? searchService.outputs.endpoint                    : 'https://update-search-service-endpoint.example.com'


// ----------------------------------------------------------------------
// Azure Search params
// ----------------------------------------------------------------------

var _searchApiVersion                    = empty(searchApiVersion) ? '2024-07-01' : searchApiVersion

// ----------------------------------------------------------------------
// Storage Account vars
// ----------------------------------------------------------------------

var _storageAccountId            = (_installStorageAccount)    ? storageAccount.outputs.resourceId          : 'update-storage-account-id'
var _aiFoundryStorageAccountId   = (_installAiFoundry)         ? storageAccountAIFoundry.outputs.resourceId : 'update-ai-foundry-storage-account-id'

//////////////////////////////////////////////////////////////////////////
// RESOURCES 
//////////////////////////////////////////////////////////////////////////

// AI Services
//////////////////////////////////////////////////////////////////////////
module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = if (_installAiServices) {
  name: 'aiServicesModule'
  params: {
    // kind:     'CognitiveServices'
    kind:     'AIServices'
    name:     _aiServicesName
    location: _location
    managedIdentities: {
      systemAssigned: true
    }    
    publicNetworkAccess : 'Enabled'
    sku:      'S0'
    tags:     _tags
    customSubDomainName : _aiServicesName
  }
}


// AI Foundry
//////////////////////////////////////////////////////////////////////////

module aiHub 'br/public:avm/res/machine-learning-services/workspace:0.12.0' = if (_installAiFoundry) {
  name: 'aiHubModule'  
  params: {
    name : _aiHubName
    sku  : 'Basic'
    kind : 'Hub'
    location : _location
    publicNetworkAccess : 'Enabled'
    
    // link existing supporting resources
    associatedKeyVaultResourceId           : _keyVaultId
    associatedStorageAccountResourceId     : _storageAccountId
    associatedApplicationInsightsResourceId: _appInsightsId
    managedIdentities: {
      systemAssigned: true
    }
    tags : _tags
  }
}

// AI Foundry Project
module aiProject 'br/public:avm/res/machine-learning-services/workspace:0.9.1'  = if (_installAiFoundry) {
  name: 'aiProjectModule'
  params: {
    // core settings
    name           : _aiProjectName
    kind           : 'Project'         
    location       : _location
    sku            : 'Basic'          
    publicNetworkAccess : 'Enabled'

    // link to your existing Hub
    hubResourceId  : aiHub.outputs.resourceId
    discoveryUrl   : 'https://${aiHub.outputs.location}.api.azureml.ms/discovery'

    managedIdentities: {
      systemAssigned: true
    }

    // optional extras
    tags       : _tags
  }
}

// Application Insights
//////////////////////////////////////////////////////////////////////////

module appInsights 'br/public:avm/res/insights/component:0.6.0' = if (_installAppInsights) {
  name: 'appInsightsModule'
  params: {
    name:                _appInsightsName
    location:            _location    
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                _tags
  }
}

// App Configuration Store
//////////////////////////////////////////////////////////////////////////

module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = if (_installAppConfig) {
  name: 'appConfigModule'
  params: {
    name:     _appConfigName
    location: _location
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
    roleAssignments: _configureRbac ? [
      {
        principalId: _principalId
        roleDefinitionIdOrName: 'App Configuration Data Owner'
      }
    ] : []
  }
}


// AOAI Services
//////////////////////////////////////////////////////////////////////////

module aoaiService 'br/public:avm/res/cognitive-services/account:0.10.2' = if (_installAoai) {
  name: 'aoaiServiceModule'
  params: {
    kind:     'OpenAI'
    name:     _aoaiServiceName
    location: _location
    sku:      'S0'
    tags:     _tags
    customSubDomainName   : _aoaiServiceName
    publicNetworkAccess : 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }    
    deployments: [for deployment in aoaiDeploymentList: {
        name: deployment.name       
        model: {
          format:  'OpenAI'
          name:    deployment.model
          version: deployment.version
        }
        sku: {
          name:     deployment.type
          capacity: deployment.capacity
        }
      }
    ] 
  }
}

//APIM
//////////////////////////////////////////////////////////////////////////

module apimService 'br/public:avm/res/api-management/service:0.9.1' = if (_installApim) {
  name: 'apimServiceModule'
  params: {
    // Core APIM properties
    name:           _apimResourceName
    location:       _location
    publisherEmail: _apimPublisherEmail
    publisherName:  _apimPublisherName
    sku:            _apimSku

    // Enable system-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // 1) AOAI API
    apis: [
      {
        name:                        _aoaiApiName
        displayName:                 _aoaiApiDisplayName
        description:                 _aoaiApiName
        path:                        _aoaiApiPath
        protocols:                   [ 'https' ]
        apiType:                     'http'
        format:                      'openapi-link'
        serviceUrl:                  _aoaiServiceEndpoint
        value:                       _aoaiApiSpecUrl  
        subscriptionRequired:        true
        subscriptionKeyParameterNames: {
          header: 'api-key'
          query:  'api-key'
        }
        policies: [
          {
            format: 'rawxml'
            value:  _aoaiApiPolicyXml
          }
        ]        
      }
    ]

    // 2) backend pointing at OpenAI
    backends: [
      {
        name:        aoaiService.outputs.name
        url:         '${_aoaiServiceEndpoint}/openai'
        // url:         '${_aoaiServiceEndpoint}openai'        
        protocol:    'http'
        description: 'backend description'
        circuitBreaker: {
          rules: [
            {
              name: 'openAIBreakerRule'
              failureCondition: {
                count:             3
                errorReasons:     [ 'Server errors' ]
                statusCodeRanges: [ { min: 429, max: 429 } ]
                interval:         'PT5M'
              }
              tripDuration: 'PT1M'
            }
          ]
        }
      }
    ]

    // 3) Subscription scoped to all your APIs
    subscriptions: [
      {
        name:         _aoaiSubscriptionName
        displayName:  _aoaiSubscriptionDisplayName
        scope:        '/apis'
        state:        'active'
        allowTracing: true
      }
    ]

  }
}

// Container Resources
//////////////////////////////////////////////////////////////////////////

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = if (_installContainerEnv) {
  name: 'containerEnvModule'
  params: {
    name:     _containerEnvName
    location: _location
    tags:     _tags
    logAnalyticsWorkspaceResourceId: _logAnalyticsId
    appInsightsConnectionString: _appInsigthsConnectionString
    zoneRedundant: false
    managedIdentities: {
      systemAssigned: true
    }    
  }
}

// Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = if (_installContainerRegistry) {
  name: 'containerRegistryModule'
  params: {
    name:     _containerRegistryName
    publicNetworkAccess : 'Enabled'
    location: _location
    acrSku:   'Basic'
    tags:     _tags
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// Container Apps
module containerApp 'br/public:avm/res/app/container-app:0.16.0' = [for app in containerAppsList: if (_installContainerApps) {
  name: empty(app.name)
    ? '${_abbrs.containerApps}-${_resourceToken}-${app.service_name}'
    : app.name  
  params: {
    name: empty(app.name)
    ? '${_abbrs.containerApps}-${_resourceToken}-${app.service_name}'
    : app.name
    location:              _location
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
            value: _appConfigEndpoint
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

module databaseAccount 'br/public:avm/res/document-db/database-account:0.12.0' = if (_installCosmosDb) {
  name: 'databaseAccountModule'
  params: {
    name:                   _dbAccountName  
    location:               _location
    managedIdentities: {
      systemAssigned: true
    }    
    locations: [
      {
        locationName:    _location  
        failoverPriority: 0   
        isZoneRedundant:  false 
      }
    ]
    defaultConsistencyLevel:'Session'
    capabilitiesToAdd: [
      'EnableServerless'
    ]
    networkRestrictions: {
      publicNetworkAccess: 'Enabled'
    }
    tags: _tags
    sqlDatabases: [
      {
        name:       _dbDatabaseName
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

module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = if (_installKeyVault) {
  name: 'keyVaultModule'
  params: {
    name:                  _keyVaultName
    location:              _location
    publicNetworkAccess:   'Enabled'
    sku:                   'standard'
    enableRbacAuthorization: true
    tags:                  _tags    
  }
}

// Log Analytics Workspace
//////////////////////////////////////////////////////////////////////////

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = if (_installLogAnalytics) {
  name: 'logAnalyticsModule'
  params: {
    name:          _logAnalyticsWorkspaceName
    location:      _location
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
module searchService 'br/public:avm/res/search/search-service:0.10.0' =  if (_installSearchService) {
  name: 'searchServiceModule'
  params: {
    name: _searchServiceName
    location: _location
    publicNetworkAccess:   'Enabled'
    // Tags
    tags: _tags
    // SKU & capacity
    sku: 'standard'
    replicaCount: 1
    semanticSearch: 'disabled'
    managedIdentities : {
      systemAssigned: true
    }    

  }
}

// Storage Accounts
//////////////////////////////////////////////////////////////////////////

// Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = if (_installStorageAccount) {
  name: 'storageAccountSolutionModule'
  params: {
    name:                     _storageAccountName
    location:                 _location
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

// AI Foundry Storage Account
module storageAccountAIFoundry 'br/public:avm/res/storage/storage-account:0.19.0' = if (_installAiFoundry) {
  name: 'storageAccountAIFoundryModule'
  params: {
    name:                     _aiFoundryStorageAccountName
    location:                 _location
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

//////////////////////////////////////////////////////////////////////////
// ROLE ASSIGNMENTS
//////////////////////////////////////////////////////////////////////////

// Note: Role assignments are handled in the post-provisioning hook to prevent 
// circular dependencies and avoid the need for custom Bicep modules. 
// These modules are proposed in AVM but have not been officially released 
//  at the time of writing this template.

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// General Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_CLOUD               string = _azureCloud
output AZURE_TENANT_ID           string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID     string = subscription().subscriptionId
output AZURE_DEPLOYMENT_NAME     string = deployment().name
output AZURE_RESOURCE_GROUP      string = resourceGroup().name
output AZURE_PRINCIPAL_ID        string = _principalId 
output AZURE_APP_CONFIG_ENDPOINT string = _appConfigEndpoint
output AZURE_NETWORK_ISOLATION   string = toLower(string(_networkIsolation))
output AZURE_CONFIGURE_RBAC      string = toLower(string(_configureRbac))
output AZURE_LOCATION            string = _location
output AZURE_RESOURCE_TOKEN      string = _resourceToken

// Resource Names
//////////////////////////////////////////////////////////////////////////

output AZURE_AI_FOUNDRY_HUB_NAME             string = _aiHubName
output AZURE_AI_FOUNDRY_PROJECT_NAME         string = _aiProjectName
output AZURE_AI_FOUNDRY_STORAGE_ACCOUNT_NAME string = _aiFoundryStorageAccountName
output AZURE_AI_SERVICES_NAME                string = _aiServicesName
output AZURE_AOAI_SERVICE_NAME               string = _aoaiServiceName
output AZURE_APP_CONFIG_NAME                 string = _appConfigName
output AZURE_APP_INSIGHTS_NAME               string = _appInsightsName
output AZURE_APIM_SERVICE_NAME               string = _apimResourceName
output AZURE_CONTAINER_ENV_NAME              string = _containerEnvName
output AZURE_CONTAINER_REGISTRY_NAME         string = _containerRegistryName
output AZURE_DATABASE_ACCOUNT_NAME           string = _dbAccountName
output AZURE_DATABASE_NAME                   string = _dbDatabaseName
output AZURE_ENV_NAME                        string = _environmentName
output AZURE_SEARCH_SERVICE_NAME             string = _searchServiceName
output AZURE_STORAGE_ACCOUNT_NAME            string = _storageAccountName

// Modularity Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_INSTALL_AI_FOUNDRY            string = toLower(string(_installAiFoundry))
output AZURE_INSTALL_APIM                  string = toLower(string(_installApim))
output AZURE_INSTALL_AOAI                  string = toLower(string(_installAoai))
output AZURE_INSTALL_APP_CONFIG            string = toLower(string(_installAppConfig))
output AZURE_INSTALL_KEY_VAULT             string = toLower(string(_installKeyVault))
output AZURE_INSTALL_LOG_ANALYTICS         string = toLower(string(_installLogAnalytics))
output AZURE_INSTALL_APP_INSIGHTS          string = toLower(string(_installAppInsights))
output AZURE_INSTALL_SEARCH_SERVICE        string = toLower(string(_installSearchService))
output AZURE_INSTALL_STORAGE_ACCOUNT       string = toLower(string(_installStorageAccount))
output AZURE_INSTALL_COSMOS_DB             string = toLower(string(_installCosmosDb))
output AZURE_INSTALL_CONTAINER_APPS        string = toLower(string(_installContainerApps))
output AZURE_INSTALL_CONTAINER_REGISTRY    string = toLower(string(_installContainerRegistry))
output AZURE_INSTALL_AI_SERVICES           string = toLower(string(_installAiServices))
output AZURE_INSTALL_CONTAINER_ENV         string = toLower(string(_installContainerEnv))

// Resource and Principal IDs for Role Assignment
//////////////////////////////////////////////////////////////////////////

output AZURE_RESOURCE_IDS object = {
  STORAGE_ACCOUNT:             _storageAccountId
  AI_FOUNDRY_STORAGE_ACCOUNT:  _aiFoundryStorageAccountId
  SEARCH_SERVICE:              _searchServiceId
  AI_SERVICES:                 _aiServicesId
  AI_FOUNDRY_PROJECT:          _aiFoundryProjectId
  CONTAINER_REGISTRY:          _containerRegistryId
  KEY_VAULT:                   _keyVaultId
  AI_FOUNDRY_HUB:              _aiFoundryHubId
  APP_CONFIG:                  _appConfigId
  DATABASE_ACCOUNT:            _databaseAccountId
  AOAI_SERVICE:                _aoaiServiceId
  APPLICATION_INSIGHTS:        _appInsightsId
  LOG_ANALYTICS:               _logAnalyticsId
}

output AZURE_PRINCIPAL_IDS object = {
  EXECUTOR_PRINCIPAL:          _principalId
  SEARCH_SERVICE:              _searchServicePrincipalId
  APIM:                        _apimServicePrincipalId
  AI_FOUNDRY_HUB:              _aiFoundryHubPrincipalId
  AI_FOUNDRY_PROJECT:          _aiFoundryProjectPrincipalId
  AOAI_SERVICE:                _aoaiServicePrincipalId
}

// Container Apps Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_CONTAINER_APPS_LIST array = [
  for (app, i) in containerAppsList: {
    name: empty(app.name) 
      ? '${_abbrs.containerApps}-${_resourceToken}-${app.service_name}' 
      : app.name
    service_name: app.service_name
    internal_name: app.internal_name
    principalId: containerApp[i].outputs.systemAssignedMIPrincipalId
    fqdn: containerApp[i].outputs.fqdn
  }
]

// AOAI Service Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_AOAI_API_VERSION     string = _aoaiApiVersion
output AZURE_AOAI_DEPLOYMENT_LIST array = aoaiDeploymentList


// API Management Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_APIM_AOAI_API_DISPLAY_NAME           string = _aoaiApiDisplayName
output AZURE_APIM_AOAI_API_NAME                   string = _aoaiApiName
output AZURE_APIM_AOAI_API_PATH                   string = _aoaiApiPath
output AZURE_APIM_AOAI_SUBSCRIPTION_DISPLAY_NAME  string = _aoaiSubscriptionDisplayName
output AZURE_APIM_AOAI_SUBSCRIPTION_NAME          string = _aoaiSubscriptionName
output AZURE_APIM_PUBLISHER_EMAIL                 string = _apimPublisherEmail
output AZURE_APIM_PUBLISHER_NAME                  string = _apimPublisherName

// AI Services Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_AI_SERVICES_ENDPOINT            string = _aiServicesEndpoint

// AI Foundry Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_AI_FOUNDRY_PROJECT_CONNECTION_STRING  string = _aiFoundryProjectConnectionString

// Document Intelligence Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_DOC_INTELLIGENCE_API_VERSION string = _docIntelligenceApiVersion

// Azure Container Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_CONTAINER_REGISTRY_ENDPOINT     string = _containerRegistryLoginServer

// Database Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_DATABASE_CONTAINERS_LIST array = databaseContainersList

// Keyvault Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_KEYVAULT_ENDPOINT string = _keyVaultEndpoint

// Storage Account Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_STORAGE_ACCOUNT_CONTAINERS_LIST array = storageAccountContainersList

// Search Outputs
//////////////////////////////////////////////////////////////////////////

output AZURE_SEARCH_ENDPOINT string    = _searchServiceEndpoint
output AZURE_SEARCH_API_VERSION string = _searchApiVersion
