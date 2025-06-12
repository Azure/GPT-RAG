
param accountName string
param location string
param modelDeployments array

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'

    // API-key based auth is not supported for the Agent service
    disableLocalAuth: false
  }
}

// Model Deployments Resource

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = [
  for deployment in modelDeployments: {
    parent: account
    name: deployment.name
    sku: {
      name: deployment.type
      capacity: deployment.capacity
    }
    properties: {
      model: {
        name: deployment.model
        format: deployment.modelFormat
        version: deployment.version
      }
    }
  }
]

output accountName string = account.name
output accountID string = account.id
output accountTarget string = account.properties.endpoint
output accountPrincipalId string = account.identity.principalId
