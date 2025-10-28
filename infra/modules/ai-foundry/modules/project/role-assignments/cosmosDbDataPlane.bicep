@description('Required. The name of the Cosmos DB account.')
param cosmosDbName string

@description('Required. The principal ID of the project identity.')
param projectIdentityPrincipalId string

@description('Required. The project workspace ID.')
param projectWorkspaceId string

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2025-04-15' existing = {
  name: cosmosDbName
  scope: resourceGroup()
}

// NOTE: these are containers that are automatically created by the capability host for the project workspace
var cosmosContainerNameSuffixes = [
  'thread-message-store'
  'system-thread-message-store'
  'agent-entity-store'
]

var cosmosDefaultSqlRoleDefinitionId = resourceId(
  'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions',
  cosmosDbName,
  '00000000-0000-0000-0000-000000000002'
)

@batchSize(1)
resource cosmosDataRoleAssigment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-04-15' = [
  for (containerSuffix, i) in cosmosContainerNameSuffixes: {
    parent: cosmosDb
    name: guid(cosmosDefaultSqlRoleDefinitionId, cosmosDbName, containerSuffix)
    properties: {
      principalId: projectIdentityPrincipalId
      roleDefinitionId: cosmosDefaultSqlRoleDefinitionId
      scope: '${cosmosDb.id}/dbs/enterprise_memory/colls/${projectWorkspaceId}-${containerSuffix}'
    }
  }
]
