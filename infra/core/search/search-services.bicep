param name string
param location string = resourceGroup().location
param tags object = {}
param publicNetworkAccess string
param sku object = {
  name: 'standard'
}
param secretName string = 'azureSearchKey'
param keyVaultName string

param authOptions object = {}
@allowed(['free', 'standard'])
param semanticSearch string = 'standard'

// Azure AI Developer role definition ID
var azureAIDeveloperRoleId = '64702f94-c441-49e6-a78b-ef80e0188fee'

resource search 'Microsoft.Search/searchServices@2021-04-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: authOptions
    disableLocalAuth: false
    disabledDataExfiltrationOptions: []
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    hostingMode: 'default'
    networkRuleSet: {
      bypass: 'None'
      ipRules: []
    }
    partitionCount: 1
    publicNetworkAccess: publicNetworkAccess
    replicaCount: 1
    semanticSearch: semanticSearch
  }
  sku: sku
}

// Role assignment to grant Azure AI Developer role to the search service
resource searchAzureAIDeveloperRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, search.id, azureAIDeveloperRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureAIDeveloperRoleId)
    principalId: search.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' =  {
  name: secretName
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
    value: search.listAdminKeys().primaryKey
  }
}

output id string = search.id
output principalId string = search.identity.principalId
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
