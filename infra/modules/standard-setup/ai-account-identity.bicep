
param accountName string
param location string
param modelDeployments array
param networkIsolation bool = false
param agentSubnetId string
param deployAiFoundrySubnet bool = true

param useUAI bool = false
param userAssignedIdentityResourceId string
param userAssignedIdentityPrincipalId string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: (useUAI) ? 'UserAssigned' : 'SystemAssigned'
    userAssignedIdentities: useUAI ? { '${userAssignedIdentityResourceId}': {} } : null
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkIsolation ? 'Deny' : 'Allow'
      virtualNetworkRules: networkIsolation && deployAiFoundrySubnet ? [
        {
          id: agentSubnetId
          ignoreMissingVnetServiceEndpoint: true
        }
      ] : null
      ipRules: []
    }
    publicNetworkAccess: 'Enabled' //this is because the firewall allows the subnets //networkIsolation ? 'Disabled' : 'Enabled'
    #disable-next-line BCP036
    networkInjections:((networkIsolation && deployAiFoundrySubnet) ? [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetId
        useMicrosoftManagedNetwork: false
      }
      ] : null )      

    // API-key based auth is not supported for the Agent service
    disableLocalAuth: false
  }
}

// Model Deployments Resource

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [
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
output accountPrincipalId string = (useUAI) ? userAssignedIdentityPrincipalId : account.identity.principalId
