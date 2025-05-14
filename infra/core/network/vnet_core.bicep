param name string
param location string
param tags object = {}
param subnets array
param vnetReuse bool = false
param addressPrefixes array = []
param resourceGroupName string = resourceGroup().name

// Virtual Network and Subnets
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (vnetReuse) {
  scope: resourceGroup(resourceGroupName)
  name: name
}

resource newVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (!vnetReuse) {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
  }
}

output name string = vnetReuse ? existingVnet.name : newVnet.name
output id string = vnetReuse ? existingVnet.id : newVnet.id
output subnets array = vnetReuse ? existingVnet.properties.subnets : newVnet.properties.subnets
