param networkIsolation bool
param vnetName string
param subnetId string
param runtimeName string
param runtimeVersion string
var runtimeNameAndVersion = '${runtimeName}|${runtimeVersion}'
param alwaysOn bool = true
param appCommandLine string = ''
param numberOfWorkers int = -1
param minimumElasticInstanceCount int = -1
param use32BitWorkerProcess bool = false
param functionAppScaleLimit int = -1
param healthCheckPath string = ''
param allowedOrigins array = []

param name string
param functionAppReuse bool
param functionAppResourceGroupName string
param location string = resourceGroup().location
param tags object = {}
param keyVaultResourceGroupName string
param keyVaultName string = ''

// Reference Properties
param applicationInsightsName string = ''
param applicationInsightsResourceGroupName string

param appServicePlanId string

param storageAccountName string
param storageResourceGroupName string

param clientAffinityEnabled bool = false
@allowed(['SystemAssigned', 'UserAssigned'])
param identityType string
// @description('User assigned identity name')
// param identityId string

// Runtime Properties
param kind string = 'functionapp,linux'

// Microsoft.Web/sites/config
param appSettings array = []

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  scope: resourceGroup(storageResourceGroupName)  
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
  scope: resourceGroup(keyVaultResourceGroupName)
  name: keyVaultName
 }

 resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  scope: resourceGroup(applicationInsightsResourceGroupName)
  name: applicationInsightsName
}

 resource existingFunction 'Microsoft.Web/sites@2022-09-01' existing = if (functionAppReuse) {
  scope: resourceGroup(functionAppResourceGroupName)
  name: name
}

resource newFunction 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: kind

  identity: {
    type: identityType
  }

  properties: {
    serverFarmId: appServicePlanId
    clientAffinityEnabled: clientAffinityEnabled
    virtualNetworkSubnetId: networkIsolation ? subnetId : null
    httpsOnly: true
    siteConfig: {
      vnetName: networkIsolation ? vnetName : null
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
      appSettings: union(
        appSettings,
        empty(applicationInsightsName) ? [] : [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsights.properties.ConnectionString
          }
        ],
        [
          {
            name: 'AzureWebJobsStorage__accountName'
            value: stg.name
          }
          {
            name: 'AzureWebJobsStorage__credential'
            value: 'managedidentity'
          }
          {
            name: 'AZURE_KEY_VAULT_ENDPOINT'
            value: keyVault.properties.vaultUri
          }
          {
            name: 'FUNCTIONS_WORKER_RUNTIME'
            value: 'python'
          }
          {
            name: 'FUNCTIONS_EXTENSION_VERSION'
            value: '~4'
          }          
        ]
      )
      cors: {
          allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
        }          

    } 
  }
}

output id string = functionAppReuse ? existingFunction.id : newFunction.id
output name string = functionAppReuse ? existingFunction.name : newFunction.name
output uri string = functionAppReuse ? 'https://${existingFunction.properties.defaultHostName}' : 'https://${newFunction.properties.defaultHostName}'
output identityPrincipalId string = identityType == 'SystemAssigned' ? functionAppReuse ? existingFunction.identity.principalId : newFunction.identity.principalId : ''
output location string = functionAppReuse ? existingFunction.location : newFunction.location
