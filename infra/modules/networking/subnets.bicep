targetScope = 'resourceGroup'

param vnetName string
param location string
param resourceGroupName string
param tags object = {}
param subnets array = []
param addressPrefixes array
param useExistingVNet bool = false
param deploySubnets bool = true
param deployNsgs bool = true
param prefix string = 'nsg-'
param virtualNetworkResourceId string

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (!useExistingVNet && deploySubnets) {
  name: 'virtualNetworkDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    // VNet sized /16 to fit all subnets
    addressPrefixes: addressPrefixes
    name: vnetName
    location: location
    tags: tags
    subnets: subnets
  }
}

module nsgsM 'network-security-group.bicep' = [
  for subnet in subnets : if (deploySubnets && deployNsgs) {
    name: '${prefix}${vnetName}-${subnet.name}'
    scope: resourceGroup(resourceGroupName)
    params : {
      name: '${prefix}${vnetName}-${subnet.name}'
      location: location
    }
  }
]

var invalidNsgSubnets = ['AzureBastionSubnet', 'AzureFirewallSubnet','AppGatewaySubnet']

module subnetsM 'subnet.bicep' = [
  for i in range(0,  length(subnets)) : if (useExistingVNet && deploySubnets) {
      name: '${subnets[i].name}'
      scope: resourceGroup(resourceGroupName)
      params: {
        name: '${vnetName}/${subnets[i].name}'
        addressPrefix: subnets[i].addressPrefix
        delegations: empty(subnets[i].delegation) ? [] : [
          {
            name: subnets[i].delegation
            properties: {
              serviceName: subnets[i].delegation
            }
          }
        ]
        serviceEndpoints: empty(subnets[i].serviceEndpoints) ? [] : [
          { 
            service : subnets[i].serviceEndpoints[0]
          }
        ]
        networkSecurityGroupId: deployNsgs && !contains(invalidNsgSubnets, subnets[i].name) ? nsgsM[i].outputs.id : null
    }
  }
]

var subnetResourceIds = [for i in range(0,  length(subnets)): {
    id : '${virtualNetworkResourceId}/subnets/${subnets[i].name}'
  }
]

output Id string = (!useExistingVNet && deploySubnets) ? virtualNetwork.outputs.resourceId : null
output Name string = (!useExistingVNet && deploySubnets) ? virtualNetwork.outputs.name : null
output Location string = (!useExistingVNet && deploySubnets) ? virtualNetwork.outputs.location : null
output SubnetResourceIds array = (!useExistingVNet && deploySubnets) ? virtualNetwork.outputs.subnetResourceIds : subnetResourceIds
