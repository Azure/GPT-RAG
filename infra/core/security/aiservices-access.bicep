param aiAccountName string
param principalId string

resource aiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, aiAccount.id, principalId)
  scope: aiAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b59867f4-fa02-4bcb-b4b4-1d78b1766d66') // Cognitive Services User
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
