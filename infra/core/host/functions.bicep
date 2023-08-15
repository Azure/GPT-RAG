param appName string
param keyVaultName string = ''
param appServicePlanId string
param appSettings array
param appInsightsInstrumentationKey string
param tags object = {}
param allowedOrigins array = []

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
// var hostingPlanName = appName
var storageAccountName = '${appName}storage'
var functionWorkerRuntime = runtime

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    // serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'python|3.10'
      appSettings: concat(appSettings,[
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
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
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'AZURE_KEY_VAULT_ENDPOINT'
          value: !empty(keyVaultName) ? keyVault.properties.vaultUri : ''
        }        
      ])
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }      
    }
    httpsOnly: true
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
 name: keyVaultName
}

// param waitSeconds int =  240
// module delayDeployment 'br/public:deployment-scripts/wait:1.1.1' = {
//   name: 'delayDeployment'
//   params: {
//     waitSeconds: waitSeconds
//     location: location
//   }
// }

// output hostKey string = functionAppHost.listKeys().functionKeys.default

output identityPrincipalId string = functionApp.identity.principalId
output name string = functionApp.name
output uri string = 'https://${functionApp.properties.defaultHostName}'
output location string = functionApp.location
// output hostKey string = listKeys('${functionApp.id}/host/default', functionApp.apiVersion).functionKeys.default
