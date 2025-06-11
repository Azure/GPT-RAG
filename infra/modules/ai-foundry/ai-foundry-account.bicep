@description('Name of the AI Services account to create')
param accountName string

@description('Azure location where the AI Services account and deployments will be created')
param location string

@description('Array of model deployments. Each item should include properties: name, model, modelFormat, type, version, and capacity')
param modelDeployments array

// AI Foundry Account Resource

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
output resourceId string = account.id
output endpoint string = account.properties.endpoint
