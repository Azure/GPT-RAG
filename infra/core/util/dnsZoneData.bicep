/** Inputs **/
param location string

/** Locals **/
@description('Private DNS Zones to read.')
var privateDnsZone = {
  agentsvc: 'privatelink.agentsvc.azure-automation.net'
  aks: 'privatelink.${location}.azmk8s.io'
  blob: 'privatelink.blob.${environment().suffixes.storage}'
  cognitiveservices: 'privatelink.cognitiveservices.azure.com'
  configuration_stores: 'privatelink.azconfig.io'
  cosmosdb: 'privatelink.documents.azure.com'
  cr: 'privatelink.azurecr.io'
  cr_region: '${location}.privatelink.azurecr.io'
  dfs: 'privatelink.dfs.${environment().suffixes.storage}'
  eventgrid: 'privatelink.eventgrid.azure.net'
  file: 'privatelink.file.${environment().suffixes.storage}'
  monitor: 'privatelink.monitor.azure.com'
  ods: 'privatelink.ods.opinsights.azure.com'
  oms: 'privatelink.oms.opinsights.azure.com'
  openai: 'privatelink.openai.azure.com'
  queue: 'privatelink.queue.${environment().suffixes.storage}'
  search: 'privatelink.search.windows.net'
  sites: 'privatelink.azurewebsites.net'
  sql_server: 'privatelink${environment().suffixes.sqlServerHostname}'
  table: 'privatelink.table.${environment().suffixes.storage}'
  vault: 'privatelink.vaultcore.azure.net'
}

var zoneIds = [for (zone, i) in items(privateDnsZone): {
  id: main[i].id
  key: zone.key
  name: main[i].name
}]

/** Outputs **/
@description('Private DNS Zones to use in other modules.')
output ids array = zoneIds

@description('Private DNS Zones for Storage Accounts')
output idsStorage array = filter(
  zoneIds,
  (zone) => contains([ 'blob', 'dfs', 'file', 'queue', 'table', 'web' ], zone.key)
)

/** Nested Modules **/
@description('Read the specified private DNS zones.')
resource main 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [for zone in items(privateDnsZone): {
  name: zone.value
}]
