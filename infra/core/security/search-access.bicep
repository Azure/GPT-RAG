param searchServiceName string
param principalId string

resource searchService 'Microsoft.Search/searchServices@2021-04-01-preview' existing = {
  name: searchServiceName
}

// Search Service Contributor role
resource searchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, searchService.id, principalId, 'search-service-contributor')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0') // Search Service Contributor role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Contributor role
resource searchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, searchService.id, principalId, 'search-index-data-contributor')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Search Index Data Contributor role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Reader role
resource searchIndexDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, searchService.id, principalId, 'search-index-data-reader')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f') // Search Index Data Reader role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
} 
