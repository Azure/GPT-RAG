param name string
param addressPrefix string
param delegations array = []
param serviceEndpoints array = []
param networkSecurityGroupId string = ''

resource subnetsM 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
      name: name
      properties: {
        addressPrefix: addressPrefix
        delegations: delegations
        serviceEndpoints: serviceEndpoints
        networkSecurityGroup: empty(networkSecurityGroupId) ? null : {
          id: networkSecurityGroupId
        }
    }
  }

output id string = subnetsM.id
