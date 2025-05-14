targetScope = 'resourceGroup'

param dnsZoneName string
param virtualNetworkName string
param tags object = {}
param aRecords array = []

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  scope: resourceGroup()
  name: virtualNetworkName
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags 
  dependsOn: [
    vnet
  ]
}

resource aRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for record in aRecords: {
  name: '${dnsZoneName}/${record.name}'
  properties: {
    ttl: record.ttl
    aRecords: [
      record.ipv4Address
    ]
  }
}]

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: '${virtualNetworkName}-dnslink'
  parent: dnsZone
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id:vnet.id
    }
    registrationEnabled: false
  }
}


output privateDnsZoneName string = dnsZone.name
output id string = dnsZone.id
