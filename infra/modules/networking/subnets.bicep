targetScope = 'resourceGroup'

param vnetName string
param location string
param resourceGroupName string
param tags object = {}
param subnets array = []
param addressPrefixes array

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = {
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

output Id string = virtualNetwork.outputs.resourceId
output Name string = virtualNetwork.outputs.name
output Location string = virtualNetwork.outputs.location
output SubnetResourceIds array = virtualNetwork.outputs.subnetResourceIds
