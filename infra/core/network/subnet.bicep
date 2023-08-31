param vnetName string 
param addressPrefix string 
param subnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: addressPrefix
  }
}

output id string = subnet.id
output name string = subnet.name
output vnetName string = vnet.name
