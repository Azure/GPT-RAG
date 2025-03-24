param name string
param location string = 'westus'
param tags object = {}

var aiServiceName = '${name}-aiservice'

resource visionIngestionAIService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServiceName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aiServiceName
    publicNetworkAccess: 'Enabled'
  }
}

output aiServiceEndpoint string = 'https://${aiServiceName}.cognitiveservices.azure.com/'
output aiServiceKey string = visionIngestionAIService.listKeys().key1
