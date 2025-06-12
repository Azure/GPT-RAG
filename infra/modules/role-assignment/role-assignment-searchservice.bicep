@description('Name of the Search Service')
param searchServiceName string

@description('Object ID of the principal to assign')
param principalId       string

@description('Role definition GUID or name')
param roleDefinition    string

// Reference existing Search Service
resource search 'Microsoft.Search/searchServices@2020-08-01' existing = {
  name: searchServiceName
}

// Lookup the roleDefinition exactly as given (name or GUID)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: search
  name:  guid(search.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
