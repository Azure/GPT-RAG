param name string
param location string = 'eastus2'
param publicNetworkAccess string = 'Enabled'
param kind string = 'OpenAI'
param capacity int = 50
param modelName string = 'o1'
param deploymentName string = 'o1'
param modelVersion string = '2024-12-17'
param sku object = {
  name: 'S0'
}
param tags object = {
  environment: 'production'
  service: 'openai'
}

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

resource o1Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: o1Account
  name: deploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: capacity
  }
  properties: {
    model: {
      format: kind
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: capacity
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}


resource gpt41Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  dependsOn: [
    o1Deployment
  ]
  parent: o1Account
  name: 'gpt-4.1'
  sku: {
    name: 'GlobalStandard'
    capacity: 490
  }
  properties: {
    model: {
      format: kind
      name: 'gpt-4.1'
      version: '2025-04-14'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 490
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

output o1Endpoint string = o1Account.properties.endpoint
output o1Key string = o1Account.listKeys().key1
