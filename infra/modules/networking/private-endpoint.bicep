targetScope = 'resourceGroup'

param name string
param location string
param resourceGroupName string
param tags object
param subnetResourceId string
param privateLinkServiceConnections array = []
param privateDnsZoneGroup object = {}
param prefix string = 'nic-'

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: name
    location: location
    tags: tags
    subnetResourceId: subnetResourceId
    privateLinkServiceConnections: privateLinkServiceConnections
    privateDnsZoneGroup: privateDnsZoneGroup
    customNetworkInterfaceName: '${prefix}${name}'
  }
}

output resourceId string = privateEndpoint.outputs.resourceId
