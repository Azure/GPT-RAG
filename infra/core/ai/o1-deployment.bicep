param name string
param deployments array = []
param location string = 'eastus2'
param publicNetworkAccess string = 'Enabled'
param kind string = 'OpenAI'
param sku object = {
  name: 'S0'
}
param tags object = {}

resource o1Account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: name
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}

/*
@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: o1Account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]
*/

output o1Endpoint string = o1Account.properties.endpoint
output o1Key string = o1Account.listKeys().key1
