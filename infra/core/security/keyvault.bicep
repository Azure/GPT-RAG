param name string
param location string = resourceGroup().location
param tags object = {}
param publicNetworkAccess string

param keyVaultReuse bool
param existingKeyVaultResourceGroupName string

// @secure()
// param vmUserPasswordKey string
// @secure()
// param vmUserPassword string

param principalId string = ''

resource existingKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (keyVaultReuse) {
  scope: resourceGroup(existingKeyVaultResourceGroupName)
  name: name  
}

resource newKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = if (!keyVaultReuse) {
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

output id string = keyVaultReuse ? existingKeyVault.id: newKeyVault.id
output name string = keyVaultReuse ? existingKeyVault.name: newKeyVault.name
output endpoint string = keyVaultReuse ? existingKeyVault.properties.vaultUri: newKeyVault.properties.vaultUri
