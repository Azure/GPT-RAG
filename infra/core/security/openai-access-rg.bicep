param principalId string

// Cognitive Services OpenAI User role assignment at resource group level
// This grants access to all Cognitive Services/AI resources in the resource group
resource openaiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, principalId, 'cognitive-services-openai-user')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    ) // Cognitive Services OpenAI User
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
