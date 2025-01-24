param principalId string
param resourceName string

resource resource 'Microsoft.Web/sites@2021-02-01' existing = {
  name: resourceName
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role

// Create a role assignment for the web app managed identity to access the function app
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resource.id, principalId, 'Contributor')
  scope: resource
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
