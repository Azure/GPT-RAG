param principalId string
param resourceName string

resource resource 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = {
  name: resourceName
}

//var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fe86443c-f201-4fc4-9d2a-ac61149fbda0') // App Configuration Contributor
var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b') // App Configuration Data Owner

// Create a role assignment for the web app managed identity to access the function app
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resource.id, principalId, 'Data Owner')
  scope: resource
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
