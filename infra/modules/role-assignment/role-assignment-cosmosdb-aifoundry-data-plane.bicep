@description('Name of the CosmosDB resource')
param cosmosAccountName string

@description('Principal Id')
param principalId string

param projectWorkspaceId string

param roleDefinitionGuid string

var userThreadName = '${projectWorkspaceId}-thread-message-store'
var systemThreadName = '${projectWorkspaceId}-system-thread-message-store'
var entityStoreName = '${projectWorkspaceId}-agent-entity-store'


resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: cosmosAccountName
  scope: resourceGroup()
}

// Reference existing database
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-12-01-preview' existing = {
  parent: cosmosAccount
  name: 'enterprise_memory'
}

resource containerUserMessageStore  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' existing = {
  parent: database
  name: userThreadName
}

resource containerSystemMessageStore 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' existing = {
  parent: database
  name: systemThreadName
}

resource containerEntityStore 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' existing = {
  parent: database
  name: entityStoreName
}

var roleDefinitionId = resourceId(
  'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions',
  cosmosAccountName,
  roleDefinitionGuid
)

var scopeSystemContainer = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosAccountName}/dbs/enterprise_memory/colls/${systemThreadName}'
var scopeUserContainer = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosAccountName}/dbs/enterprise_memory/colls/${userThreadName}'
var scopeEntityContainer = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosAccountName}/dbs/enterprise_memory/colls/${entityStoreName}'

resource containerRoleAssignmentUserContainer 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  parent: cosmosAccount
  name: guid(projectWorkspaceId, containerUserMessageStore.id, roleDefinitionId, principalId)
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    scope: scopeUserContainer
  }
}

resource containerRoleAssignmentSystemContainer 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  parent: cosmosAccount
  name: guid(projectWorkspaceId, containerSystemMessageStore.id, roleDefinitionId, principalId)
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    scope: scopeSystemContainer
  }
}

  resource containerRoleAssignmentEntityContainer 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
    parent: cosmosAccount
    name: guid(projectWorkspaceId, containerEntityStore.id, roleDefinitionId, principalId)
    properties: {
      principalId: principalId
      roleDefinitionId: roleDefinitionId
      scope: scopeEntityContainer
    }
  }
