param virtualNetworkName string
param privateEndpointName string
param dnsZoneName string
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: virtualNetworkName
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' existing = {
  name: privateEndpointName  
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags 
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privateEndpointName}-link'
  parent: privateDnsZone
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id:vnet.id
    }
    registrationEnabled: false
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  parent: privateEndpoint
  name: '${privateEndpointName}-group'
  properties:{
    privateDnsZoneConfigs:[
      {
        name:'config1'
        properties:{
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output privateDnsZoneName string = privateDnsZone.name
