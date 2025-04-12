param name string
param location string = resourceGroup().location

var aiServiceName = '${name}-aiservice'


resource deepseekR1AIService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
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

output r1Endpoint string = 'https://${deepseekR1AIService.name}.cognitiveservices.azure.com/models'
output r1Key string = deepseekR1AIService.listKeys().key1
