param name string
param location string = resourceGroup().location
param tags object = {}
param aiServicesReuse bool
param existingAiServicesResourceGroupName string

param aiServicesDeploy bool = true

param secretsNames object = {}
param keyVaultName string

param customSubDomainName string = name
param deployments array = []
param kind string = 'OpenAI'
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}

resource existingAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing  = if (aiServicesReuse && aiServicesDeploy) {
  scope: resourceGroup(existingAiServicesResourceGroupName)
  name: name
}

resource newAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = if (!aiServicesReuse && aiServicesDeploy) {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: if (!aiServicesReuse && aiServicesDeploy) {
  parent: newAccount
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 40
  }
}]

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' =  [for secretName in items(secretsNames): {
  name: secretName.value
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exp: 0
      nbf: 0
    }
    contentType: 'string'
    value:  aiServicesReuse ? existingAccount.listKeys().key1 : newAccount.listKeys().key1
  }
}]

output name string = !aiServicesDeploy ? '' : aiServicesReuse? existingAccount.name : newAccount.name
output id string = !aiServicesDeploy ? '' : aiServicesReuse? existingAccount.id : newAccount.id
output endpoint string = !aiServicesDeploy ? '' : aiServicesReuse? existingAccount.properties.endpoint : newAccount.properties.endpoint
