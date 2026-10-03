targetScope = 'resourceGroup'

@description('Private DNS zones to deploy. Each item provides its DNS name and VNet link name.')
type zoneInfo = {
  dnsName: string
  virtualNetworkLinkName: string
}

param zones zoneInfo[] = []
param location string = 'global'
param resourceGroupName string
param tags object
param virtualNetworkResourceId string
param registrationEnabled bool = false

module privateDnsZones 'br/public:avm/res/network/private-dns-zone:0.8.0' = [for zone in zones: {
  scope: resourceGroup(resourceGroupName)
  name: 'dep-pdns-${uniqueString(zone.dnsName)}'
  params: {
    name: zone.dnsName
    location: location
    tags: tags
    virtualNetworkLinks: [
      {
        name: zone.virtualNetworkLinkName
        registrationEnabled: registrationEnabled
        #disable-next-line BCP318
        virtualNetworkResourceId: virtualNetworkResourceId
      }
    ]
  }
}]
