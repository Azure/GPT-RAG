@description('Name of the Storage Account')
param storageAccountName string

@description('Object ID of the principal to assign')
param principalId        string

@description('Role definition GUID or name')
param roleDefinition     string

// Reference existing Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

// Lookup the roleDefinition exactly as given (name or GUID)
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name:  roleDefinition
}

// Assign the role
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name:  guid(storage.id, principalId, roleDef.id)
  properties: {
    principalId:      principalId
    roleDefinitionId: roleDef.id
  }
}
