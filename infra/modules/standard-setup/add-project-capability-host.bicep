param cosmosDBConnection string
param azureStorageConnection string
param aiSearchConnection string
param projectName string
param accountName string
param projectCapHost string
param accountCapHost string

var threadConnections = ['${cosmosDBConnection}']
var storageConnections = ['${azureStorageConnection}']
var vectorStoreConnections = ['${aiSearchConnection}']

param timestamp string = utcNow()

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
   name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' existing = {
  name: projectName
  parent: account
}

module accountCapabilityHost 'add-account-capability-host.bicep' = {
  name: 'addAccountCapabilityHost'
  params: {
    accountName: accountName
    accountCapHost: accountCapHost
  }
}

//get existing capability host
resource existingAccountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-06-01' existing = {
   name: accountCapHost
   parent: account
   dependsOn: [
     accountCapabilityHost
   ]
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-06-01' = {
  name: projectCapHost
  parent: project
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: vectorStoreConnections
    storageConnections: storageConnections
    threadStorageConnections: threadConnections
  }
  dependsOn: [
    accountCapabilityHost
  ]
}
