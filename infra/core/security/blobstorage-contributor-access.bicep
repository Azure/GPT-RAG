param principalId string
param resourceName string

resource resource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: resourceName
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor role

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, principalId, resourceName, roleDefinitionId)
  scope: resource
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
  }
}
