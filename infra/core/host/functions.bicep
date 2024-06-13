param appName string
param keyVaultName string = ''
param storageAccountName string
param appServicePlanId string
param appSettings array
param appInsightsConnectionString string
param appInsightsInstrumentationKey string
param tags object = {}
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param clientAffinityEnabled bool = false
param kind string = 'functionapp,linux'
param functionAppScaleLimit int = -1
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param runtimeName string
param runtimeVersion string
param use32BitWorkerProcess bool = false
param healthCheckPath string = ''
var runtimeNameAndVersion = '${runtimeName}|${runtimeVersion}'
param networkIsolation bool
param vnetName string
param subnetId string

param functionAppReuse bool
param existingFunctionAppResourceGroupName string

param functionAppStorageReuse bool
param existingFunctionAppStorageName string
param existingFunctionAppStorageResourceGroupName string

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'python'
])
param runtime string = 'python'

var functionAppName = appName
var functionWorkerRuntime = runtime

resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing  = if (functionAppStorageReuse) {
  scope: resourceGroup(existingFunctionAppStorageResourceGroupName)
  name: existingFunctionAppStorageName
}

resource newStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = if (!functionAppStorageReuse) {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    allowBlobPublicAccess: false // Disable anonymous access 
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

var _storage_keys = functionAppStorageReuse ? existingStorageAccount.listKeys().keys[0].value : newStorageAccount.listKeys().keys[0].value
var _storageAccountName= functionAppStorageReuse ? existingStorageAccount.name : newStorageAccount.name


resource existingFunctionApp 'Microsoft.Web/sites@2022-09-01' existing  = if (functionAppReuse) {
  scope: resourceGroup(existingFunctionAppResourceGroupName)
  name: functionAppName
}

resource newFunctionApp 'Microsoft.Web/sites@2022-09-01' = if (!functionAppReuse) {
  name: functionAppName
  location: location
  kind: kind
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    clientAffinityEnabled: clientAffinityEnabled
    virtualNetworkSubnetId: networkIsolation?subnetId:null
    httpsOnly: true
    siteConfig: {
      vnetName: networkIsolation?vnetName:null
      linuxFxVersion: runtimeNameAndVersion
      alwaysOn: alwaysOn
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers
      minimumElasticInstanceCount: minimumElasticInstanceCount
      use32BitWorkerProcess: use32BitWorkerProcess      
      functionAppScaleLimit: functionAppScaleLimit
      healthCheckPath: healthCheckPath
      appSettings: concat(appSettings,[
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${_storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${_storage_keys}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${_storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${_storage_keys}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'AZURE_KEY_VAULT_ENDPOINT'
          value: keyVault.properties.vaultUri
        }
      ])
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }      
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
 name: keyVaultName
}

output identityPrincipalId string = functionAppReuse ? existingFunctionApp.identity.principalId : newFunctionApp.identity.principalId
output name string = functionAppReuse ? existingFunctionApp.name : newFunctionApp.name
output uri string = 'https://${functionAppReuse ? existingFunctionApp.properties.defaultHostName : newFunctionApp.properties.defaultHostName}'
output location string = functionAppReuse ? existingFunctionApp.location : newFunctionApp.location
output id string = functionAppReuse ? existingFunctionApp.id : newFunctionApp.id
