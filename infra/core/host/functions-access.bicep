param principalId string
param functionAppName string

resource functionApp 'Microsoft.Web/sites@2021-02-01' existing = {
  name: functionAppName
}

// Create a role assignment for the web app managed identity to access the function app
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(functionApp.id, principalId, 'Contributor')
  scope: functionApp
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
