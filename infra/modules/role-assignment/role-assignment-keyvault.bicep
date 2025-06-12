@description('Name of the Key Vault')
param vaultName       string

@description('Object ID of the principal to assign')
param principalId     string

@description('Role definition GUID or name')
param roleDefinition  string

// Reference existing Key Vault
resource vault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: vaultName
}

// Lookup the roleDefinition exactly as given (name or GUID)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name:  guid(vault.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
