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
resource accounts_r1ai0_vm2b2htvuuclm_aiservice_name_DeepSeek_V3_0324 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: deepseekR1AIService
  name: 'DeepSeek-V3-0324'
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'DeepSeek'
      name: 'DeepSeek-V3-0324'
      version: '1'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 1
    raiPolicyName: 'Microsoft.Default'
  }
}

output r1Endpoint string = 'https://${deepseekR1AIService.name}.cognitiveservices.azure.com/models'
output r1Key string = deepseekR1AIService.listKeys().key1
