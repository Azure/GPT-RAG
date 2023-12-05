param name string
param location string = resourceGroup().location
param tags object = {}
param publicNetworkAccess string

@secure()
param vmUserPasswordKey string
@secure()
param vmUserPassword string

param principalId string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enableSoftDelete: true
    publicNetworkAccess: publicNetworkAccess
    enablePurgeProtection: true
    accessPolicies: !empty(principalId) ? [
      {
        objectId: principalId
        permissions: { secrets: [ 'get', 'list', 'set'] }
        tenantId: subscription().tenantId
      }
    ] : []
  }
}

resource vmUserPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (publicNetworkAccess == 'Enabled') {
  parent: keyVault
  name: vmUserPasswordKey
  properties: {
    value: vmUserPassword
  }
}

resource KeyVaultAccessRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (publicNetworkAccess == 'Enabled') {
  name: guid(subscription().id, resourceGroup().id, principalId, keyVault.id, 'Secret Reader')
  scope: keyVault
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'User'
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
output id string = keyVault.id
