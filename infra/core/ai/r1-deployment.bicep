param name string
param location string = resourceGroup().location
param gpt41Capacity int = 500
param o4MiniCapacity int = 150
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
    capacity: 3000
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
resource gpt41Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: deepseekR1AIService
  name: 'gpt-4.1'
  dependsOn: [
    accounts_r1ai0_vm2b2htvuuclm_aiservice_name_DeepSeek_V3_0324
  ]
  sku: {
    name: 'DataZoneStandard'
    capacity: gpt41Capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1'
      version: '2025-04-14'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: gpt41Capacity
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

resource o4MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: deepseekR1AIService
  name: 'o4-mini'
  dependsOn: [
    accounts_r1ai0_vm2b2htvuuclm_aiservice_name_DeepSeek_V3_0324
    gpt41Deployment
  ]
  sku: {
    name: 'DataZoneStandard'
    capacity: o4MiniCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'o4-mini'
      version: '2025-04-16'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: o4MiniCapacity
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}
output r1Endpoint string = 'https://${deepseekR1AIService.name}.cognitiveservices.azure.com/models'
output r1Key string = deepseekR1AIService.listKeys().key1
