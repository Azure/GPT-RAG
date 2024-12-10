param principalId string
param resourceName string

resource resource 'Microsoft.Search/searchServices@2021-04-01-preview' existing = {
  name: resourceName
}

resource roleAssignmentSIDC 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, resource.id, principalId, 'SIDC')
  scope: resource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Search Index Data Contributor
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
