@description('Name of the Cosmos DB account')
param cosmosDbAccountName string

@description('Object ID of the principal to assign')
param principalId         string

@description('Role definition GUID or name')
param roleDefinition      string

// Reference existing Cosmos DB account
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' existing = {
  name: cosmosDbAccountName
}

// Lookup the roleDefinition exactly as given (name or GUID)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cosmos
  name:  guid(cosmos.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
