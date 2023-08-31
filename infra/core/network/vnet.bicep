param location string
param name string
param tags object = {}
param addressPrefix string

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }
}

output id string = vnet.id
output name string = vnet.name
