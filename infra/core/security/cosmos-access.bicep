param principalId string
param accountName string
param resourceGroupName string

resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: toLower(accountName)
}

var roleDefinitionId = '/${subscription().id}/resourceGroups/${resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${account.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  name: guid(resourceGroup().id, account.id, principalId)  
  parent: account
  properties:{
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    scope:  account.id
  }
}
