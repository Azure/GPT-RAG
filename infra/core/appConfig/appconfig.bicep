/** Inputs **/
@description('App Configuration name')
param name string

@description('Location for all resources')
param location string

@description('Resource suffix for all resources')
param resourceToken string

@description('Tags for all resources')
param tags object

@description('Keys to add to App Configuration')
param appSettings array

@description('Secret Keys to add to App Configuration')
param secureAppSettings array

var abbrs = loadJsonContent('../../abbreviations.json')
var roles = loadJsonContent('../../roles.json')

/** Resources **/
@description('User Assigned Identity for App Configuration')
resource uaiAppConfig 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  location: location
  name: '${abbrs.security.managedIdentity}${abbrs.configuration.appConfiguration}${resourceToken}'
  tags: tags
}

@description('App Configuration')
resource main 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uaiAppConfig.id}': {}
    }
  }
  location: location
  name: name
  properties: {
    disableLocalAuth: false
    enablePurgeProtection: true
    encryption: {}
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
  }
  sku: {
    name: 'standard'
  }
  tags: tags
}

resource keyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [for (config, i) in appSettings: {
  parent: main
  name: config.name
  properties: {
    contentType: ''
    tags: {}
    value: config.value
  }
}
]

resource secureKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [for (config, i) in secureAppSettings: {
  parent: main
  name: config.name
  properties: {
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    tags: {}
    value: config.value
  }
}
]

@description('App Configuration resource Id')
output id string = main.id
@description('App Configuration resource Name')
output name string = main.name
@description('App Configuration resource EndPoint')
output endpoint string = main.properties.endpoint

output clientId string = uaiAppConfig.properties.clientId
output principalId string = uaiAppConfig.properties.principalId
