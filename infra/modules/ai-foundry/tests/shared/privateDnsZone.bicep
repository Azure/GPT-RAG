@description('Required. Private DNS zone name.')
param name string

@description('Required. The resource ID of the virtual network to link.')
param virtualNetworkResourceId string

@description('Optional. Tags of the resource.')
param tags resourceInput<'Microsoft.Resources/resourceGroups@2025-04-01'>.tags?

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: name
  location: 'global' // Private DNS zones must use 'global' as location
  tags: tags
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: '${name}-vnetlink'
  parent: privateDnsZone
  location: 'global' // Private DNS zones must use 'global' as location
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkResourceId
    }
  }
}

@description('The resource group the private DNS zone was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the private DNS zone.')
output name string = privateDnsZone.name

@description('The resource ID of the private DNS zone.')
output resourceId string = privateDnsZone.id

@description('The location the resource was deployed into.')
output location string = privateDnsZone.location
