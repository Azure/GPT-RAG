param principalId string
param roleDefinitionId string = ''
param resourceName string

resource resource 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: resourceName
}

@description('This is the built-in Key Vault Secrets Officer User. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user')
resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  scope: resource
  name: guid(resource.id, principalId, !empty(roleDefinitionId) ? roleDefinitionId : keyVaultSecretsUserRoleDefinition.id)
  properties: {
    principalId: principalId
    roleDefinitionId: !empty(roleDefinitionId) ? roleDefinitionId : keyVaultSecretsUserRoleDefinition.id
  }
}
