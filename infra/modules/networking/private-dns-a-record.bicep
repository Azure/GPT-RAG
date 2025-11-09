targetScope = 'resourceGroup'

param zoneName string
param zoneResourceId string = ''
param recordName string
param ipv4Addresses array = []
param ttl int = 300
param privateEndpointResourceId string = ''

var resolvedZoneName = !empty(zoneResourceId)
  ? last(split(zoneResourceId, '/'))
  : zoneName

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: resolvedZoneName
}

var privateEndpointDetails = !empty(privateEndpointResourceId)
  ? reference(privateEndpointResourceId, '2024-05-01', 'Full')
  : {
      properties: {
        customDnsConfigs: []
      }
    }

var privateEndpointCustomDnsConfigs = privateEndpointDetails.properties.customDnsConfigs ?? []

var privateEndpointPrimaryIp = length(privateEndpointCustomDnsConfigs) > 0 && length(privateEndpointCustomDnsConfigs[0].ipAddresses) > 0
  ? privateEndpointCustomDnsConfigs[0].ipAddresses[0]
  : ''

var explicitARecordEntries = [
  for address in ipv4Addresses: {
    ipv4Address: address
  }
]

var fallbackARecordEntries = !empty(privateEndpointPrimaryIp)
  ? [
      {
        ipv4Address: privateEndpointPrimaryIp
      }
    ]
  : []

resource aRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: zone
  name: recordName
  properties: {
    ttl: ttl
    aRecords: length(explicitARecordEntries) > 0
      ? explicitARecordEntries
      : (length(fallbackARecordEntries) > 0 ? fallbackARecordEntries : null)
  }
}
