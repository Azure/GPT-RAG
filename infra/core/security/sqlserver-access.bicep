param sqlServerName string
param principalId string

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, sqlServer.id, principalId)
  scope: sqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
    ) // SQL DB Contributor
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
