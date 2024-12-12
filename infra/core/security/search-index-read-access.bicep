param principalId string
param resourceName string

resource resource 'Microsoft.Search/searchServices@2021-04-01-preview' existing = {
  name: resourceName
}

resource roleAssignmentSIDC 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, resource.id, principalId, 'SIDC')
  scope: resource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f') // Search Index Data Reader
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
