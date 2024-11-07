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
param location string = resourceGroup().location
param tags object = {}
param keyVaultName string = ''

// Reference Properties
param applicationInsightsName string = ''
param appServicePlanId string
param storageAccountName string

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
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
  name: keyVaultName
 }

resource functions 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: kind

  identity: {
    type: identityType
    // userAssignedIdentities: { 
    //   '${identityId}': {}
    // }
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
      // deployment: {
      //   storage: {
      //     type: 'blobContainer'
      //     value: '${stg.properties.primaryEndpoints.blob}deploymentpackage'
      //     authentication: {
      //       type: 'SystemAssignedIdentity'
      //       userAssignedIdentityResourceId: '' 
      //       // type: identityType == 'SystemAssigned' ? 'SystemAssignedIdentity' : 'UserAssignedIdentity'            
      //       // userAssignedIdentityResourceId: identityType == 'UserAssigned' ? identityId : '' 
      //     }
      //   }      
      //   cors: {
      //     allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      //   }      
      // }
      
      appSettings: union(appSettings,
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
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsights.properties.ConnectionString
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
        ])

      cors: {
          allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
        }          

    } 


   

  }

}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

output id string = functions.id
output name string = functions.name
output uri string = 'https://${functions.properties.defaultHostName}'
output identityPrincipalId string = identityType == 'SystemAssigned' ? functions.identity.principalId : ''
output location string = functions.location
