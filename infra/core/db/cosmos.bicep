@description('Cosmos DB account name, max length 44 characters, lowercase')
param accountName string

@description('Enable/disable public network access for the Cosmos DB account.')
param publicNetworkAccess string = 'Disabled' 

@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

param cosmosDbReuse bool
param existingCosmosDbResourceGroupName string
param existingCosmosDbAccountName string

param deployCosmosDb bool = true


param conversationContainerName string
param modelsContainerName string  

param tags object = {}

@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Max stale requests. Required for BoundedStaleness. Valid ranges, Single Region: 10 to 2147483647. Multi Region: 100000 to 2147483647.')
@minValue(10)
@maxValue(2147483647)
param maxStalenessPrefix int = 100000

@description('Max lag time (minutes). Required for BoundedStaleness. Valid ranges, Single Region: 5 to 84600. Multi Region: 300 to 86400.')
@minValue(5)
@maxValue(86400)
param maxIntervalInSeconds int = 300

@description('Enable system managed failover for regions')
param systemManagedFailover bool = true

@description('The name for the database')
param databaseName string

@description('Maximum autoscale throughput for the container')
@minValue(1000)
@maxValue(1000000)
param autoscaleMaxThroughput int = 1000

@description('Time to Live for data in analytical store. (-1 no expiry)')
@minValue(-1)
@maxValue(2147483647)
param analyticalStoreTTL int = -1

param secretName string = 'azureDBkey'

param keyVaultName string

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}
var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]

resource existingAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing  = if (cosmosDbReuse && deployCosmosDb) {
  scope: resourceGroup(existingCosmosDbResourceGroupName)
  name: existingCosmosDbAccountName
}

resource newAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = if (!cosmosDbReuse && deployCosmosDb) {
  name: toLower(accountName)
  kind: 'GlobalDocumentDB'
  location: location
  tags: tags
  properties: {
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: systemManagedFailover
    publicNetworkAccess: publicNetworkAccess
    enableAnalyticalStorage: true
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = if (!cosmosDbReuse && deployCosmosDb) {
  parent: newAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource conversationsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = if (!cosmosDbReuse && deployCosmosDb) {
  parent: database
  name: conversationContainerName
  properties: {
    resource: {
      id: conversationContainerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      analyticalStorageTtl: analyticalStoreTTL
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
      defaultTtl: 86400
    }
    options: {
      autoscaleSettings: {
        maxThroughput: autoscaleMaxThroughput
      }
    }
  }
}

resource modelsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = if (!cosmosDbReuse && deployCosmosDb) {
  parent: database
  name: modelsContainerName
  properties: {
    resource: {
      id: modelsContainerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      analyticalStorageTtl: analyticalStoreTTL
      indexingPolicy: {
        indexingMode: 'none'
        automatic: false
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: autoscaleMaxThroughput
      }
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' =  {
  name: secretName
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
    value: !deployCosmosDb ? '' : cosmosDbReuse ? existingAccount.listKeys().primaryMasterKey : newAccount.listKeys().primaryMasterKey
  }
}


output id string =  !deployCosmosDb ? '' : cosmosDbReuse ? existingAccount.id : newAccount.id
output name string =  !deployCosmosDb ? '' : cosmosDbReuse ? existingAccount.name : newAccount.name
