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

@description('This is the built-in Key Vault Secrets Officer role. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer')
resource keyVaultSecretsOfficerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
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
    enableRbacAuthorization: true    
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  scope: newKeyVault
  name: guid(newKeyVault.id, principalId, keyVaultSecretsOfficerRoleDefinition.id)
  properties: {
    principalId: principalId
    roleDefinitionId: keyVaultSecretsOfficerRoleDefinition.id
  }
}

output id string = keyVaultReuse ? existingKeyVault.id: newKeyVault.id
output name string = keyVaultReuse ? existingKeyVault.name: newKeyVault.name
output endpoint string = keyVaultReuse ? existingKeyVault.properties.vaultUri: newKeyVault.properties.vaultUri
