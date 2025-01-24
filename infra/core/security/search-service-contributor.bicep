param principalId string
param resourceName string

resource resource 'Microsoft.Search/searchServices@2021-04-01-preview' existing = {
  name: resourceName
}

resource roleAssignmentSSC 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, resource.id, principalId, 'SSC')
  scope: resource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0') // Search Service Contributor
    principalId: principalId
  }
}
