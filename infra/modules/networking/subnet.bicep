param name string
param addressPrefix string
param delegations array = []
param serviceEndpoints array = []
param networkSecurityGroupId string = ''
param routeTableId string = ''
param natGatewayId string = ''

resource subnetsM 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
      name: name
      properties: {
        addressPrefix: addressPrefix
        delegations: delegations
        serviceEndpoints: serviceEndpoints
        networkSecurityGroup: empty(networkSecurityGroupId) ? null : {
          id: networkSecurityGroupId
        }
        routeTable: empty(routeTableId) ? null : {
          id: routeTableId
        }
        natGateway: empty(natGatewayId) ? null : {
          id: natGatewayId
        }
    }
  }

output id string = subnetsM.id
