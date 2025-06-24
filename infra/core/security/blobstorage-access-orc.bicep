param storageAccountName string
param principalId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

// Storage Blob Data Contributor role
resource blobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, storageAccount.id, principalId, 'contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Delegator role  
resource blobDelegatorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, storageAccount.id, principalId, 'delegator')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db58b8e5-c6ad-4a2a-8342-4190687cbf4a') // Storage Blob Delegator role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
} 
