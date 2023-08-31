param location string
param name string
param tags object = {}
param serviceId string
param subnetId string
param groupIds array = []

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: name
  location: location
  tags: tags  
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'privatelinkServiceonnection'
        properties: {
          privateLinkServiceId: serviceId
          groupIds: groupIds
        }
      }
    ]    
  }
}

output name string = privateEndpoint.name
