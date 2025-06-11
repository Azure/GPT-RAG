@description('Cosmos DB account name')
param cosmosDbAccountNAme string

@description('Formatted workspace GUID (xxxx-xxxx-xxxx-xxx)')
param workspaceGuid string

// Reference the account you just created
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: cosmosDbAccountNAme
}

// Create the SQL database
resource sqlDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-12-01-preview' = {
  parent: cosmosAccount
  name: 'enterprise_memory'
  properties: {
    resource: {
      id: 'enterprise_memory'
    }
    options: {
      throughput: 400
    }
  }
}

// Create each container
resource threadStore 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' = {
  parent: sqlDb
  name: '${workspaceGuid}-thread-message-store'
  properties: {
    resource: {
      id: '${workspaceGuid}-thread-message-store'
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
      defaultTtl: -1
    }
  }
}

resource systemThreadStore 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' = {
  parent: sqlDb
  name: '${workspaceGuid}-system-thread-message-store'
  properties: {
    resource: {
      id: '${workspaceGuid}-system-thread-message-store'
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
      defaultTtl: -1
    }
  }
}

resource entityStore 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-12-01-preview' = {
  parent: sqlDb
  name: '${workspaceGuid}-agent-entity-store'
  properties: {
    resource: {
      id: '${workspaceGuid}-agent-entity-store'
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
      defaultTtl: -1
    }
  }
}

output cosmosDbAccountName string = cosmosAccount.name
