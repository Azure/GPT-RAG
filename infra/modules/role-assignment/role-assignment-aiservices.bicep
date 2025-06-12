@description('Name of the Cognitive Services (or OpenAI) account')
param cognitiveAccountName string

@description('Object ID of the principal to assign')
param principalId         string

@description('Role definition GUID or name')
param roleDefinition      string

// Reference the existing Cognitive Services account
resource cs 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: cognitiveAccountName
}

// Look up the roleDefinition exactly as given (no GUID generation hack)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cs
  name:  guid(cs.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
