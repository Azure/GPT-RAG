param principalId string

// Azure AI User role assignment at resource group level
resource aiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, principalId, 'ai-user')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '53ca6127-db72-4b80-b1b0-d745d6d5456d'
    ) // Azure AI User
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Azure AI Account Owner role assignment at resource group level
resource aiAccountOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, principalId, 'ai-account-owner')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'e47c6f54-e4a2-4754-9501-8e0985b135e1'
    ) // Azure AI Account Owner
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiProjectManagerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, principalId, 'ai-project-manager')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'eadc314b-1a2d-4efa-be10-5d325db5065e'
    ) // Azure AI Project Manager
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
