targetScope = 'resourceGroup'

@description('The IP addresses.')
param ipAddresses array

@description('Private DNS Zone')
param zone string

@description('The record host name without the domain.')
param name string

resource dnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: zone
}

@description('Private DNS A-records.')
resource dnsRecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  name: name
  parent: dnsZone
  properties: {
    ttl: 0
    aRecords: map(ipAddresses, (ip) => {
        ipv4Address: ip
      })
  }
}
