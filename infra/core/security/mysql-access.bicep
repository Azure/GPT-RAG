param mysqlServerName string
param principalId string

resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2021-12-01-preview' existing = {
  name: mysqlServerName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, mysqlServer.id, principalId)
  scope: mysqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c'
    ) // Contributor role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
