param name string
param location string = resourceGroup().location

param aiSearchReuse bool
param existingAiSearchResourceGroupName string

param deployAiSearch bool = true

param tags object = {}
param publicNetworkAccess string
param sku object = {
  name: 'standard'
}
param secretName string = 'azureSearchKey'
param keyVaultName string

param authOptions object = {}
param semanticSearch string = 'free'


resource existingSearch 'Microsoft.Search/searchServices@2025-02-01-preview' existing  = if (aiSearchReuse && deployAiSearch) {
  scope: resourceGroup(existingAiSearchResourceGroupName)
  name: name
}

/** Resources **/
@description('User Assigned Identity for search')
resource uaiFunc 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  location: location
  name: 'uai-${name}'
  tags: tags
}

resource newSearch 'Microsoft.Search/searchServices@2025-02-01-preview' = if (!aiSearchReuse && deployAiSearch) {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uaiFunc.id}': {}
    }
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

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' =  {
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
    value: aiSearchReuse ? existingSearch.listAdminKeys().primaryKey : newSearch.listAdminKeys().primaryKey    
  }
}
 
output id string = !deployAiSearch ? '' : aiSearchReuse ? existingSearch.id : newSearch.id
output name string = !deployAiSearch ? '' : aiSearchReuse ? existingSearch.name : newSearch.name
output principalId string = !deployAiSearch ? '' : uaiFunc.properties.principalId
output endpoint string = !deployAiSearch ? '' : 'https://${aiSearchReuse ? existingSearch.name: newSearch.name}.search.windows.net/'
