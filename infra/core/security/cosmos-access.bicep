param principalId string
param accountName string

// resource sqlRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(resourceGroup().id, account.id, principalId)  
//   scope: account
//   properties:{
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5bd9cd88-fe45-4216-938b-f97437e15450')
//     principalId: principalId
//     principalType: 'ServicePrincipal'
//   }
// }

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  name: guid(resourceGroup().id, account.id, principalId)  
  parent: account
  properties:{
    roleDefinitionId: '/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${account.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: principalId
    scope:  account.id
  }
}

resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: toLower(accountName)
}
