targetScope = 'resourceGroup'

param vnetName string
param subnetNames array
param resourceGroupName string

resource network 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  scope: resourceGroup(resourceGroupName)
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = [for subnetName in subnetNames: {
  name: subnetName
  parent: network
}]

output id string = network.id
output subnets array = [for (subnetName, i) in subnetNames: {
  addressPrefix: subnet[i].properties.addressPrefix
  id: subnet[i].id
  name: subnet[i].name
}]
